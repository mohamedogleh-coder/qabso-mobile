-- Everything one booking is made of, in a single row: the slot, the field and
-- stadium it is on, what the booking came to, and every payment taken for it.
--
-- Built for a details sheet that is opened with nothing but an event id.
--
-- The money is counted in a lateral rather than by joining the transactions
-- in. An event has one transaction per half paid, and each of those has one
-- transaction_details row per merchant the money came from. Joining both and
-- grouping would repeat every transaction once per detail and count the
-- amounts several times over, so each level is aggregated on its own.
--
-- Two kinds of people may read a booking, and they are allowed different
-- amounts of it:
--
--   * a customer sees a booking their own money is on, and nothing else;
--   * a manager sees every booking on their stadium, whoever made it — their
--     own desk bookings, their staff's, and outside customers' alike.
--
-- The caller is taken from the session, so neither of them passes a user id.
CREATE OR REPLACE FUNCTION public.event_details_fn(p_event_id INT)
    RETURNS TABLE
            (
                event_id           int,
                event_start        timestamp,
                event_end          timestamp,
                extra_time         smallint,
                event_key          varchar,
                remaining          numeric,
                cancelled_at       timestamptz,
                event_status       text,
                field_id           smallint,
                capacity           smallint,
                cost               numeric,
                slot_price         numeric,
                stadium_id         uuid,
                stadium_name       varchar,
                allow_half_booking boolean,
                billed_amount      numeric,
                paid_amount        numeric,
                discounted         numeric,
                refunded           numeric,
                transactions       json
            )
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
BEGIN

    IF p_event_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan booking-ka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    -- Every column is written with its table in front of it. The names this
    -- function returns are also variables inside it, so a bare column name
    -- would be read as the variable instead.
    RETURN QUERY
        SELECT e.id,
               e.event_start,
               e.event_end,
               e.extra_time,
               e.event_key,
               e.remaining,
               e.cancelled_at,

               -- Worked out the same way user_bookings_history_view works it
               -- out, so a booking never reads as one thing in the list and
               -- another in the sheet.
               CASE
                   WHEN e.event_status = 'cancelled' THEN 'cancelled'
                   WHEN e.event_end < LOCALTIMESTAMP THEN 'completed'
                   ELSE e.event_status::text
                   END,

               f.id,
               f.capacity,
               f.cost,

               -- fields.cost is the price of one player, so the slot costs the
               -- whole team. This is what the payments have to add up to.
               f.capacity * f.cost,

               s.id,
               s.stadium_name,
               s.allow_half_booking,

               money.billed_amount,
               money.paid_amount,
               money.discounted,
               money.refunded,

               ledger.transactions

        FROM public.event_bookings e
                 JOIN public.fields f ON f.id = e.field_id
                 JOIN public.stadiums s ON s.id = f.stadium_id

            -- What the booking came to and what actually changed hands.
            -- billed is before discounts, paid is after them, and refunded is
            -- money handed back.
                 CROSS JOIN LATERAL (
            SELECT COALESCE(SUM(t.total_amount)
                            FILTER (WHERE t.transaction_type = 'payment'), 0)
                       AS billed_amount,
                   COALESCE(SUM(t.total_amount - t.discounted)
                            FILTER (WHERE t.transaction_type = 'payment'), 0)
                       AS paid_amount,
                   COALESCE(SUM(t.discounted)
                            FILTER (WHERE t.transaction_type = 'payment'), 0)
                       AS discounted,
                   COALESCE(SUM(t.total_amount)
                            FILTER (WHERE t.transaction_type = 'refund'), 0)
                       AS refunded
            FROM public.transactions t
            WHERE t.event_id = e.id
            ) AS money

            -- Every payment and refund on the booking, oldest first, each
            -- carrying the portions it was split into. A portion with no
            -- merchant number was paid in cash.
                 CROSS JOIN LATERAL (
            SELECT COALESCE(
                           json_agg(
                           json_build_object(
                                   'transaction_id', t.id,
                                   'transaction_type', t.transaction_type,
                                   'transaction_date', t.transaction_date,
                                   'total_amount', t.total_amount,
                                   'discounted', t.discounted,
                                   'paid_user_name', payer.full_name,
                                   'paid_user_phone', payer.phone_number,
                                   'processed_by_name', staff.full_name,
                                   'details', (SELECT COALESCE(
                                                              json_agg(
                                                              json_build_object(
                                                                      'merchant_number', d.merchant_number,
                                                                      'provider_name', p.provider_name,
                                                                      'provider_service', p.provider_service,
                                                                      'amount_paid', d.amount_paid
                                                              ) ORDER BY d.id),
                                                              '[]'::json)
                                               FROM public.transaction_details d
                                                        LEFT JOIN public.stadium_merchants m
                                                                  ON m.id = d.stadium_merchant_id
                                                        LEFT JOIN public.providers p
                                                                  ON p.id = m.provider_id
                                               WHERE d.transaction_id = t.id)
                           ) ORDER BY t.transaction_date, t.id),
                           '[]'::json)
            FROM public.transactions t
                     LEFT JOIN public.app_users payer ON payer.id = t.paid_user
                     LEFT JOIN public.app_users staff ON staff.id = t.processed_by
            WHERE t.event_id = e.id
            ) AS ledger

        WHERE e.id = p_event_id

          -- The customer branch matches the money, so it only ever lets
          -- through a booking this user paid on. The manager branch matches
          -- the stadium and says nothing about who paid, so it lets through
          -- every booking on a stadium this user runs.
          AND (EXISTS (SELECT 1
                       FROM public.transactions t
                       WHERE t.event_id = e.id
                         AND t.paid_user = auth.uid())
            OR EXISTS (SELECT 1
                       FROM public.stadium_managers sm
                       WHERE sm.stadium_id = s.id
                         AND sm.user_id = auth.uid()));

END;
$$;


-- The customer branch above looks a booking up by its payer every time the
-- sheet is opened. The same index serves user_bookings_history_view.
CREATE INDEX IF NOT EXISTS idx_transactions_paid_user_payment
    ON public.transactions (paid_user, event_id)
    WHERE transaction_type = 'payment';


GRANT EXECUTE ON FUNCTION public.event_details_fn(INT) TO authenticated;

COMMENT ON FUNCTION public.event_details_fn IS
    'One booking with its field, stadium, money summary and every payment '
        'taken for it, readable by whoever paid on it or manages the stadium.';
