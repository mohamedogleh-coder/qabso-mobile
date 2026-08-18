-- What a manager needs the moment they open the app: what is on today, what
-- is still free to sell, and whether anything is stopping the stadium from
-- taking bookings at all.
--
-- Money the stadium has taken is deliberately not here. Takings belong to the
-- reports, behind a deliberate tap, not on a screen that anyone standing over
-- the manager's shoulder can read.
--
-- The one figure about money that does come back is what today's bookings are
-- still owed, and only when the stadium lets a slot be taken in halves. A
-- stadium that sells whole slots only has nothing outstanding by definition,
-- so the figure comes back null and the screen leaves the whole part out
-- rather than showing a zero that never moves.
--
-- Each part is counted in a lateral of its own. Today's games, the free slots
-- and the next booking read different tables at different grains, and joining
-- them together would multiply the rows and spoil the counts.
CREATE OR REPLACE FUNCTION public.manager_home_fn(p_stadium_id uuid)
    RETURNS TABLE
            (
                games_today         integer,
                played_today        integer,
                free_slots_today    integer,
                remaining_amount    numeric,
                next_event_id       integer,
                next_event_start    timestamp,
                next_event_end      timestamp,
                next_field_id       smallint,
                next_event_status   text,
                has_working_days    boolean,
                has_active_merchant boolean,
                has_bookable_field  boolean
            )
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
DECLARE
    v_allow_half_booking boolean;
BEGIN

    IF p_stadium_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan garoonka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    SELECT s.allow_half_booking
    INTO v_allow_half_booking
    FROM public.stadiums s
    WHERE s.id = p_stadium_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Garoonka % lama helin', p_stadium_id
            USING ERRCODE = 'P1001';
    END IF;

    -- Every column is written with its table in front of it. The names this
    -- function returns are also variables inside it, so a bare column name
    -- would be read as the variable instead.
    RETURN QUERY
        SELECT today.games_today,
               today.played_today,
               slots.free_slots_today,
               today.remaining_amount,

               next_up.id,
               next_up.event_start,
               next_up.event_end,
               next_up.field_id,
               next_up.event_status::text,

               -- What has to be true before a customer can book and pay. Each
               -- one that is false stops bookings on its own.
               EXISTS (SELECT 1
                       FROM public.stadium_working_days w
                       WHERE w.stadium_id = s.id
                         AND w.is_open),

               EXISTS (SELECT 1
                       FROM public.stadium_merchants m
                       WHERE m.stadium_id = s.id
                         AND NOT m.disabled),

               EXISTS (SELECT 1
                       FROM public.fields f
                       WHERE f.stadium_id = s.id
                         AND f.allow_booking)

        FROM public.stadiums s

            -- Today's games. A cancelled booking was never played and is not
            -- counted anywhere here.
                 CROSS JOIN LATERAL (
            SELECT COUNT(*)::integer AS games_today,

                   COUNT(*) FILTER (
                       WHERE e.event_end < LOCALTIMESTAMP)::integer
                                     AS played_today,

                   -- Null rather than zero when the stadium sells whole slots
                   -- only, so the screen knows to leave the part out.
                   CASE
                       WHEN v_allow_half_booking
                           THEN COALESCE(SUM(e.remaining), 0)
                       END           AS remaining_amount

            FROM public.event_bookings e
                     JOIN public.fields f ON f.id = e.field_id
            WHERE f.stadium_id = s.id
              AND e.event_status <> 'cancelled'
              AND e.event_start >= CURRENT_DATE
              AND e.event_start < CURRENT_DATE + 1
            ) AS today

            -- What is still sellable today. The slots are read from
            -- generate_booking_time_seq_fn, so they are the very ones a
            -- customer will be offered — a slot is free here only if it is
            -- free there. Slots earlier today are past selling.
                 CROSS JOIN LATERAL (
            SELECT COUNT(*)::integer AS free_slots_today
            FROM public.fields f
                     CROSS JOIN LATERAL jsonb_array_elements(
                    generate_booking_time_seq_fn(f.id, CURRENT_DATE)) AS slot
            WHERE f.stadium_id = s.id
              AND f.allow_booking
              AND slot ->> 'eventStatus' = 'available'
              AND (slot ->> 'startTime')::timestamp > LOCALTIMESTAMP
            ) AS slots

            -- The game happening now, or the next one to come. Everything is
            -- null when the day has nothing left in it.
                 LEFT JOIN LATERAL (
            SELECT e.id,
                   e.event_start,
                   e.event_end,
                   e.field_id,
                   e.event_status
            FROM public.event_bookings e
                     JOIN public.fields f ON f.id = e.field_id
            WHERE f.stadium_id = s.id
              AND e.event_status <> 'cancelled'
              AND e.event_end > LOCALTIMESTAMP
              AND e.event_start >= CURRENT_DATE
              AND e.event_start < CURRENT_DATE + 1
            ORDER BY e.event_start
            LIMIT 1
            ) AS next_up ON true

        WHERE s.id = p_stadium_id;

END;
$$;


GRANT EXECUTE ON FUNCTION public.manager_home_fn(uuid) TO authenticated;

COMMENT ON FUNCTION public.manager_home_fn IS
    'Today at one stadium: games on, slots still free, what is owed when '
        'half booking is on, the next game, and whether anything is '
        'stopping bookings.';
