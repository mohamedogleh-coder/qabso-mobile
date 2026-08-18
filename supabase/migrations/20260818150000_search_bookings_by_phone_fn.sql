-- Finds a stadium's bookings by the customer's phone number.
--
-- The number is in one of two places and the search does not care which: a
-- walk-in's is on the payment itself as payer_phone, and a signed-in
-- customer's is read through paid_user. COALESCE below hands back whichever
-- one matched, so the manager always gets a number they can ring.
--
-- The match is made in a lateral with LIMIT 1 rather than a join. An event
-- paid in two halves has two payment rows, and joining them would return the
-- same booking twice; this way the first payer to match brings the booking
-- back exactly once.
--
-- Cancelled bookings come back too. "That booking you cancelled" is a real
-- thing to look up, and the status says plainly what happened to it.
--
-- Only a manager of the stadium may search it. Customer phone numbers are not
-- something any signed-in user should be able to sweep for.
CREATE OR REPLACE FUNCTION public.search_bookings_by_phone_fn(
    p_stadium_id uuid,
    p_phone varchar,
    p_limit int DEFAULT 50
)
    RETURNS TABLE
            (
                event_id     integer,
                phone_number varchar,
                event_start  timestamp,
                event_end    timestamp,
                event_status text
            )
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
DECLARE
    v_digits text;
BEGIN

    IF p_stadium_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan garoonka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    -- Numbers are written down every which way — with spaces, with a country
    -- code, without — so both sides are reduced to their digits before they
    -- are compared. A search of fewer than four digits would match most of
    -- the stadium, so it is refused rather than answered.
    v_digits := regexp_replace(COALESCE(p_phone, ''), '[^0-9]', '', 'g');

    IF length(v_digits) < 4 THEN
        RAISE EXCEPTION 'Fadlan ugu yaraan 4 nambar geli'
            USING ERRCODE = 'P1001';
    END IF;

    IF NOT EXISTS (SELECT 1
                   FROM public.stadium_managers sm
                   WHERE sm.stadium_id = p_stadium_id
                     AND sm.user_id = auth.uid()) THEN
        RAISE EXCEPTION 'Garoonkan ma maamusho'
            USING ERRCODE = 'P1001';
    END IF;

    -- Every column is written with its table in front of it. The names this
    -- function returns are also variables inside it, so a bare column name
    -- would be read as the variable instead.
    RETURN QUERY
        SELECT e.id,
               payer.phone_number,
               e.event_start,
               e.event_end,

               -- Worked out the way every other read works it out, so a
               -- booking never reads as one thing here and another in the
               -- details sheet.
               CASE
                   WHEN e.event_status = 'cancelled' THEN 'cancelled'
                   WHEN e.event_end < LOCALTIMESTAMP THEN 'completed'
                   ELSE e.event_status::text
                   END

        FROM public.event_bookings e
                 JOIN public.fields f ON f.id = e.field_id

                 CROSS JOIN LATERAL (
            SELECT COALESCE(t.payer_phone, u.phone_number)::varchar
                       AS phone_number
            FROM public.transactions t
                     LEFT JOIN public.app_users u ON u.id = t.paid_user
            WHERE t.event_id = e.id
              AND t.transaction_type = 'payment'
              AND regexp_replace(
                          COALESCE(t.payer_phone, u.phone_number, ''),
                          '[^0-9]', '', 'g') LIKE '%' || v_digits || '%'
            ORDER BY t.transaction_date, t.id
            LIMIT 1
            ) AS payer

        WHERE f.stadium_id = p_stadium_id
        ORDER BY e.event_start DESC
        LIMIT p_limit;

END;
$$;


GRANT EXECUTE ON FUNCTION public.search_bookings_by_phone_fn(uuid, varchar, int)
    TO authenticated;

COMMENT ON FUNCTION public.search_bookings_by_phone_fn IS
    'A stadium''s bookings found by the customer''s phone number, newest '
        'first, one row per booking, readable only by that stadium''s '
        'managers.';
