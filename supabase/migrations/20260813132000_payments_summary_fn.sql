-- The money a stadium moved over a date range, and what each of its payment
-- numbers took.
--
-- The totals come from `transactions` alone, so a payment split across two
-- numbers is still one payment. The per-number amounts come from
-- `transaction_details`, which is where a payment is split between the
-- numbers it was paid into.
--
-- The two sides count different things on purpose. `total_amount` is the
-- price charged, discount included, while the details hold what was really
-- paid — the deferred trigger ties them together as total_amount -
-- discounted. So the cash actually taken is totalPayments - totalDiscounts.
CREATE OR REPLACE FUNCTION payments_summary_fn(
    p_stadium_id uuid DEFAULT NULL,
    p_start_date date DEFAULT NULL,
    p_end_date date DEFAULT NULL
)
    RETURNS JSONB
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
AS
$$
DECLARE
    v_start_date date;
    v_end_date   date;
    v_starts_at  timestamptz;
    v_ends_at    timestamptz;
    v_totals     jsonb;
    v_merchants  jsonb;
    v_cash       numeric(12, 2);
BEGIN
    -- No dates at all means today. One date on its own is read as that
    -- single day.
    v_start_date := COALESCE(p_start_date, p_end_date, CURRENT_DATE);
    v_end_date := COALESCE(p_end_date, p_start_date, CURRENT_DATE);

    IF v_start_date > v_end_date THEN
        RAISE EXCEPTION 'Start date % is after end date %.',
            v_start_date, v_end_date
            USING ERRCODE = 'P1001';
    END IF;

    -- From the first day at midnight up to but not including the day after
    -- the last one, so the whole of the last day counts.
    v_starts_at := v_start_date::timestamptz;
    v_ends_at := (v_end_date + 1)::timestamptz;

    -- 1. The totals. One pass over the transactions: every type is summed in
    -- the same scan with FILTER. Only a payment can carry a discount
    -- (chk_discount_only_on_payment), so the discount needs no filter.
    SELECT jsonb_build_object(
                   'totalPayments', COALESCE(SUM(t.total_amount)
                       FILTER (WHERE t.transaction_type = 'payment'), 0),
                   'totalRefunds', COALESCE(SUM(t.total_amount)
                       FILTER (WHERE t.transaction_type = 'refund'), 0),
                   'totalExpenses', COALESCE(SUM(t.total_amount)
                       FILTER (WHERE t.transaction_type = 'expense'), 0),
                   'totalDiscounts', COALESCE(SUM(t.discounted), 0)
           )
    INTO v_totals
    FROM transactions t
    WHERE (p_stadium_id IS NULL OR t.stadium_id = p_stadium_id)
      AND t.transaction_date >= v_starts_at
      AND t.transaction_date < v_ends_at;

    -- 2. One row for every payment number of the stadium. The sum is asked
    -- for each number on its own, so a number that took nothing in the range
    -- still comes back, with zero.
    --
    -- A payment adds to the number. A refund or an expense left the number,
    -- so it is taken away again.
    SELECT COALESCE(
                   jsonb_agg(
                           jsonb_build_object(
                                   'merchantNumber', summary.merchant_number,
                                   'providerName', summary.provider_name,
                                   'providerService', summary.provider_service,
                                   'totalAmount', summary.total_amount
                           )
                           ORDER BY summary.provider_name,
                               summary.merchant_number
                   ),
                   '[]'::jsonb)
    INTO v_merchants
    FROM (SELECT m.merchant_number,
                 p.provider_name,
                 p.provider_service,
                 COALESCE((SELECT SUM(CASE
                                          WHEN t.transaction_type = 'payment'
                                              THEN d.amount_paid
                                          ELSE -d.amount_paid
                                          END)
                           FROM transaction_details d
                                    JOIN transactions t
                                         ON t.id = d.transaction_id
                           WHERE d.stadium_merchant_id = m.id
                             AND t.transaction_date >= v_starts_at
                             AND t.transaction_date < v_ends_at), 0)
                     AS total_amount
          FROM stadium_merchants m
                   JOIN providers p ON p.id = m.provider_id
          WHERE p_stadium_id IS NULL
             OR m.stadium_id = p_stadium_id) AS summary;

    -- 3. A detail with no merchant number was paid in cash, so it belongs to
    -- no number and gets a row of its own at the end of the list.
    SELECT COALESCE(SUM(CASE
                            WHEN t.transaction_type = 'payment'
                                THEN d.amount_paid
                            ELSE -d.amount_paid
                            END), 0)
    INTO v_cash
    FROM transaction_details d
             JOIN transactions t ON t.id = d.transaction_id
    WHERE d.stadium_merchant_id IS NULL
      AND (p_stadium_id IS NULL OR t.stadium_id = p_stadium_id)
      AND t.transaction_date >= v_starts_at
      AND t.transaction_date < v_ends_at;

    v_merchants := v_merchants || jsonb_build_array(
            jsonb_build_object(
                    'merchantNumber', 'Cash',
                    'providerName', 'Cash',
                    'providerService', 'Cash',
                    'totalAmount', v_cash
            ));

    RETURN v_totals || jsonb_build_object('merchants', v_merchants);
END;
$$;
