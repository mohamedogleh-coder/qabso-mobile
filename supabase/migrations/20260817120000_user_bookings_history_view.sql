CREATE VIEW public.user_bookings_history_view
    WITH (security_invoker = true) AS
SELECT e.id    AS event_id,
       s.stadium_name,
       e.event_start,
       e.event_end,

       -- The status to show. The database has no 'completed' status: a
       -- booking that was played is still 'confirmed', so a booking whose
       -- time has passed is named completed here. A cancelled booking stays
       -- cancelled whether its time has passed or not.
       CASE
           WHEN e.event_status = 'cancelled' THEN 'cancelled'
           WHEN e.event_end < LOCALTIMESTAMP THEN 'completed'
           ELSE e.event_status::text
           END AS event_status,

       -- What this user actually handed over, after their discount. Other
       -- people's payments on the same booking are not counted.
       mine.amount_paid,

       -- What the booking still owes, which belongs to the slot rather than
       -- to this user. A half booking waiting for the second team shows the
       -- other half here.
       e.remaining

FROM (SELECT t.event_id,
             SUM(t.total_amount - t.discounted) AS amount_paid
      FROM public.transactions t
      WHERE t.transaction_type = 'payment'
        AND t.paid_user = auth.uid()
      GROUP BY t.event_id) AS mine

         JOIN public.event_bookings e ON e.id = mine.event_id
         JOIN public.fields f ON f.id = e.field_id
         JOIN public.stadiums s ON s.id = f.stadium_id;


-- The view reads the payments by user every time. Without this the whole
-- transactions table is scanned to find one customer's payments.
CREATE INDEX IF NOT EXISTS idx_transactions_paid_user_payment
    ON public.transactions (paid_user, event_id)
    WHERE transaction_type = 'payment';


GRANT SELECT ON public.user_bookings_history_view TO authenticated;

COMMENT
ON VIEW public.user_bookings_history_view IS
    'Bookings the signed-in user paid on, one row each, with the stadium '
        'name, what they paid, and what the booking still owes.';
