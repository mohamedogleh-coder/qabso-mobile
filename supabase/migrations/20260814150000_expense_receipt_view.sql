-- One row per expense carrying everything a receipt has to show: what the
-- expense was, when it was settled, who paid it out, and every portion the
-- money left in — so the client never stitches four tables together itself.
--
-- The joins are LEFT joins on purpose. An expense always has a transaction in
-- practice, but a receipt that shows the expense with an empty split is far
-- better than a receipt that returns nothing at all.
--
-- A portion with no merchant was paid in cash: merchant_number and the
-- provider are both null there, and the client reads that as cash. The
-- provider is reached through the merchant link, while merchant_number comes
-- off the detail row itself, which is the number as it stood when the money
-- moved.
CREATE VIEW public.expense_receipt_view
WITH (security_invoker = true) AS
SELECT e.id,
       e.expense_type,
       e.description,
       e.expense_date,
       e.expense_total,
       t.transaction_date,
       t.updated_at,
       u.full_name    AS processed_by_name,
       u.phone_number AS processed_by_phone,
       COALESCE(
               json_agg(
               json_build_object(
                       'merchant_number', d.merchant_number,
                       'provider_name', p.provider_name,
                       'provider_service', p.provider_service,
                       'amount_paid', d.amount_paid
               ) ORDER BY d.id
                        ) FILTER (WHERE d.id IS NOT NULL),
               '[]'::json
       )              AS payments
FROM public.expenses e
         LEFT JOIN public.transactions t ON t.expense_id = e.id
         LEFT JOIN public.app_users u ON u.id = t.processed_by
         LEFT JOIN public.transaction_details d ON d.transaction_id = t.id
         LEFT JOIN public.stadium_merchants m ON m.id = d.stadium_merchant_id
         LEFT JOIN public.providers p ON p.id = m.provider_id
GROUP BY e.id, t.id, u.full_name, u.phone_number;

GRANT SELECT ON public.expense_receipt_view TO authenticated;
