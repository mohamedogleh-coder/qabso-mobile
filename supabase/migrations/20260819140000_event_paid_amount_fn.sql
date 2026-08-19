-- What a booking has actually paid.
--
-- Read before a cancellation, so the refund sheet opens on the figure
-- cancel_event_fn will accept: the whole amount that changed hands, which is
-- every payment less the discount it was given.
--
-- A booking with no payments comes back as 0, and so does an id that does not
-- exist. Whether the booking is there at all is cancel_event_fn's question,
-- not this one's.
CREATE OR REPLACE FUNCTION public.event_paid_amount_fn(
    p_event_id INT
)
    RETURNS NUMERIC(12, 2)
    LANGUAGE sql
    STABLE
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
SELECT COALESCE(SUM(t.total_amount - t.discounted), 0)
FROM transactions t
WHERE t.event_id = p_event_id
  AND t.transaction_type = 'payment';
$$;
