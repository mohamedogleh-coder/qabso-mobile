-- Finds the stadiums a customer can play at on a given day, the way the
-- Explore screen shows them: with the matched field's pictures, whether the
-- customer has already saved the stadium, and only stadiums that can actually
-- take the booking.
--
-- Two rules were added here on top of the earlier search:
--
--   * a stadium must have a payment number that is still on. A stadium with
--     no numbers, or whose numbers are all disabled, has no way to be paid
--     and so is left out;
--
--   * a stadium must still have a free slot to come. A field whose day is
--     already over is not offered, even though its past hours are free.
--
-- The matching itself is unchanged. The customer searches with the number of
-- players and a date, and may add a start time, their own position, and how
-- far they are willing to travel. Every stadium comes back once, carrying the
-- one field that fits the group best.
--
-- Which field is "best": the smallest field that still holds the group. A
-- field the group does not fit in is never offered, and a bigger field is only
-- offered when no smaller one is left — so a group of 7 is given the 8-seat
-- field over the 11-seat one, and an exact 7-seat field over both. Fields the
-- manager has closed to booking are left out.
--
-- A slot is one hour of play plus the stadium's extra time, which is the same
-- length generate_booking_time_seq_fn offers and check_before_booking_event_fn
-- accepts. The search measures the requested time against that length, so a
-- stadium is only returned when the whole game — extra time included — still
-- fits before it closes.
--
-- The requested time is read as "around then", not as an exact slot start. A
-- stadium that opens at 08:00 with 15 minutes of extra time is still returned
-- for an 08:30 search: the customer picks the real slot from the booking grid.
--
-- Without a time the search does not look for a particular hour. It answers
-- "this stadium works that day and still has something left for us", and the
-- customer opens the day's slots from there.
--
-- The working hours decide which stadiums come back, but they are not returned
-- with them. The customer opens the stadium to see its hours.

-- The old search functions go first. Postgres will not let a replace change
-- the columns a function returns, and the two search_stadiums_fn migrations
-- left a function behind that nothing calls any more.
DROP FUNCTION IF EXISTS public.search_stadiums_fn(smallint, date, time,
                                                  double precision,
                                                  double precision,
                                                  double precision);

DROP FUNCTION IF EXISTS public.explore_stadiums_fn(smallint, date, time,
                                                   double precision,
                                                   double precision,
                                                   double precision);


CREATE OR REPLACE FUNCTION public.explore_stadiums_fn(
    p_capacity smallint,
    p_date date,
    p_time time DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_longitude double precision DEFAULT NULL,
    p_radius double precision DEFAULT NULL
)
    RETURNS TABLE
            (
                id                 uuid,
                stadium_name       varchar,
                latitude           double precision,
                longitude          double precision,
                extra_time         smallint,
                allow_half_booking boolean,
                distance           double precision,
                field_id           smallint,
                capacity           smallint,
                cost               numeric,
                image_urls         json,
                fav                boolean
            )
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    -- extensions is on the path because postgis may sit there rather than in
    -- public, and the geography type and the ST_ functions are read from it.
    SET search_path = public, extensions, pg_temp
AS
$$
DECLARE
    v_here      geography;
    v_wanted_at timestamp;
BEGIN

    ------------------------------------------------------------
    -- What the search cannot do without
    ------------------------------------------------------------

    IF p_capacity IS NULL OR p_date IS NULL THEN
        RAISE EXCEPTION 'Fadlan tirada ciyaartoyda iyo taariikhda waa qasab.'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Taariikhda % way dhaaftay.', p_date
            USING ERRCODE = 'P1001';
    END IF;

    -- The moment the customer wants to start playing. p_time is optional, and
    -- a null there leaves this null, which switches off every time test below.
    --
    -- Bookings are stored as plain timestamps on the stadium's own clock, so
    -- this is built the same way and compared against LOCALTIMESTAMP. The
    -- database runs on Africa/Mogadishu, so LOCALTIMESTAMP is the stadium's
    -- own wall clock.
    v_wanted_at := p_date + p_time;

    IF v_wanted_at < LOCALTIMESTAMP THEN
        RAISE EXCEPTION 'Waqtiga % wuu dhaafay.', p_time
            USING ERRCODE = 'P1001';
    END IF;

    -- Half a coordinate is no coordinate: unless both come in, nothing is
    -- measured and the radius is ignored.
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_here := ST_SetSRID(
                          ST_MakePoint(p_longitude, p_latitude),
                          4326)::geography;
    END IF;

    ------------------------------------------------------------
    -- The search
    --
    -- The inner query does the matching and the outer one orders it. They are
    -- split because the ordering reads the distance, and a distance that was
    -- worked out once should not be worked out again to sort by it.
    --
    -- Every column is written with its table in front of it. The names the
    -- function returns are also variables inside it, so a bare column name
    -- would be read as the variable instead.
    ------------------------------------------------------------

    RETURN QUERY
        SELECT found.id,
               found.stadium_name,
               found.latitude,
               found.longitude,
               found.extra_time,
               found.allow_half_booking,
               found.distance,
               found.field_id,
               found.capacity,
               found.cost,
               found.image_urls,
               found.fav
        FROM (SELECT s.id                       AS id,
                     s.stadium_name             AS stadium_name,
                     ST_Y(s.location::geometry) AS latitude,
                     ST_X(s.location::geometry) AS longitude,
                     s.extra_time               AS extra_time,
                     s.allow_half_booking       AS allow_half_booking,

                     -- Metres on the spheroid, handed back in kilometres.
                     -- Null when the customer gave no position, and null as
                     -- well for a stadium that has none on file.
                     CASE
                         WHEN v_here IS NULL THEN NULL
                         ELSE round(
                                      (ST_Distance(s.location, v_here) / 1000)::numeric,
                                      2)::double precision
                         END                    AS distance,

                     best.id                    AS field_id,
                     best.capacity              AS capacity,
                     best.cost                  AS cost,

                     -- The pictures of the field that matched, and only that
                     -- field. The stadium's other fields are not asked for,
                     -- because they are not what the customer is being
                     -- offered. A field with no pictures gives [], the same
                     -- way fields_with_images_view answers.
                     (SELECT COALESCE(
                                     json_agg(fi.image_path ORDER BY fi.id),
                                     '[]'::json)
                      FROM field_images fi
                      WHERE fi.field_id = best.id) AS image_urls,

                     -- Whether the customer has saved this stadium already.
                     -- Row level security keeps favourite_stadiums to the
                     -- signed-in user's own rows, so the user is not named
                     -- again here. Nobody signed in sees false everywhere.
                     EXISTS (SELECT 1
                             FROM favourite_stadiums fs
                             WHERE fs.stadium_id = s.id) AS fav

              -- The stadium has to work that weekday. day_of_week is 1..7
              -- Monday-first, which is exactly ISODOW. A day switched off and
              -- a day never written down both mean the same thing here, and
              -- the join drops each of them.
              FROM stadiums s
                       JOIN stadium_working_days w
                            ON w.stadium_id = s.id
                                AND w.day_of_week = EXTRACT(ISODOW FROM p_date)::smallint
                                AND w.is_open

                  -- One field per stadium. The order picks the smallest field
                  -- the group still fits in, so an exact match always wins,
                  -- and the limit is what keeps the stadium from appearing
                  -- twice. A stadium with no such field drops out with it.
                  --
                  -- The two free-time tests sit inside this pick, not after
                  -- it: when the best-sized field is taken, the stadium
                  -- offers the next size up rather than going missing.
                  --
                  -- A cancelled booking holds nothing. It is skipped here the
                  -- same way no_overlapping_events skips it, so a slot someone
                  -- gave back is offered again.
                       CROSS JOIN LATERAL (
                  SELECT f.id,
                         f.capacity,
                         f.cost
                  FROM fields f
                  WHERE f.stadium_id = s.id
                    AND f.allow_booking
                    AND f.capacity >= p_capacity
                    AND (v_wanted_at IS NULL
                      OR NOT EXISTS (SELECT 1
                                     FROM event_bookings e
                                     WHERE e.field_id = f.id
                                       AND e.event_status = 'confirmed'
                                       AND e.occupied_period && tsrange(
                                             v_wanted_at,
                                             v_wanted_at
                                                 + make_interval(mins => 60 + s.extra_time),
                                             '[)')))

                    -- The field must still have a slot to come. The slots are
                    -- read from generate_booking_time_seq_fn, so they are the
                    -- very ones the customer will be shown — a slot is free
                    -- here only if it is free there.
                    --
                    -- startTime is the stadium's own wall clock and so is
                    -- LOCALTIMESTAMP, so a slot earlier today fails this and
                    -- a stadium whose day is over drops out.
                    AND EXISTS (SELECT 1
                                FROM jsonb_array_elements(
                                             generate_booking_time_seq_fn(
                                                     f.id, p_date)) AS slot
                                WHERE slot ->> 'eventStatus' = 'available'
                                  AND (slot ->> 'startTime')::timestamp
                                    > LOCALTIMESTAMP)
                  ORDER BY f.capacity, f.id
                  LIMIT 1
                  ) AS best

              -- The stadium has to be working at the hour that was asked for.
              -- Opening later than the customer wants rules it out, and so
              -- does closing before the game would end. Compared as
              -- timestamps rather than times, because a time plus an interval
              -- wraps around midnight and would let a late slot pass.
              WHERE (v_wanted_at IS NULL
                  OR (p_time >= w.open_time
                      AND v_wanted_at + make_interval(mins => 60 + s.extra_time)
                          <= p_date + w.close_time))

                -- The stadium has to be payable. A number that was turned off
                -- takes no new money, so a stadium whose numbers are all off
                -- counts the same as one that never added any.
                AND EXISTS (SELECT 1
                            FROM stadium_merchants m
                            WHERE m.stadium_id = s.id
                              AND NOT m.disabled)

                -- The radius only applies to a search that carries a
                -- position. A stadium with no location on file cannot be
                -- measured, so ST_DWithin answers null and it stays out of a
                -- radius search.
                AND (v_here IS NULL
                  OR p_radius IS NULL
                  OR ST_DWithin(s.location, v_here, p_radius * 1000))) AS found

        -- Nearest first when there is a position to measure from, by name
        -- otherwise. A stadium with no location on file sorts last rather
        -- than first.
        ORDER BY found.distance NULLS LAST, found.stadium_name;

END;
$$;


-- The pictures are read once per found stadium, always by field. The foreign
-- key alone is not indexed — Postgres does not do it on its own — so without
-- this every search scans the whole field_images table per stadium.
CREATE INDEX IF NOT EXISTS idx_field_images_field
    ON public.field_images (field_id);


-- The payment-number test runs once per stadium and reads only the stadium
-- and whether the number is off, so it is answered from the index alone.
CREATE INDEX IF NOT EXISTS idx_stadium_merchants_stadium_enabled
    ON public.stadium_merchants (stadium_id)
    WHERE NOT disabled;


COMMENT ON FUNCTION public.explore_stadiums_fn IS
    'Stadiums open on a date with the smallest field that holds the group, '
        'one row each, limited to stadiums that can take payment and still '
        'have a slot to come, with that field''s images and whether the '
        'signed-in user saved the stadium.';
