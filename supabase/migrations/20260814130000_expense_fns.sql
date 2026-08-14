-- Saving an expense is saving money going out, so it is written the same way
-- a booking payment is written coming in: the expense row, one transaction of
-- type 'expense', and one transaction_details row for every number the money
-- left from. No stadium_merchant_id on a portion means it was paid in cash.
--
-- Only processed_by is recorded. paid_user is who money came from, and money
-- the stadium pays out never comes from a customer — chk_transaction_actors
-- says the same thing.
--
-- There is no discount on an expense either. Paying a supplier less is simply
-- a smaller expense_total, and chk_discount_only_on_payment refuses anything
-- else, so the split must add up to the whole expense_total.


-- Records a new expense and the money that paid for it.
CREATE OR REPLACE FUNCTION public.add_expense_fn(
    p_stadium_id UUID,
    p_expense_type VARCHAR(10),
    p_description VARCHAR(100),
    p_expense_date DATE,
    p_expense_total NUMERIC(12, 2),
    p_processed_by UUID,
    p_merchants JSONB
)
    RETURNS INT
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
DECLARE
    v_expense_total   NUMERIC(12, 2);

    v_merchants_total NUMERIC(12, 2);
    v_smallest_paid   NUMERIC(12, 2);

    v_expense_id      INT;
    v_transaction_id  INT;
BEGIN

    ------------------------------------------------------------
    -- Validate the expense
    --
    -- The type is left to the expenses check constraint, which is the one
    -- place the allowed types are listed.
    ------------------------------------------------------------

    IF p_stadium_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan garoonka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_processed_by IS NULL THEN
        RAISE EXCEPTION 'Fadlan qofka lacagta bixiyay waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_expense_date IS NULL THEN
        RAISE EXCEPTION 'Fadlan taariikhda kharashka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    v_expense_total := ROUND(COALESCE(p_expense_total, 0), 2);

    IF v_expense_total <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagta kharashku waa inay ka weyn tahay 0'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Validate the payment split
    --
    -- A missing amount_paid is COALESCEd to 0 rather than skipped, because MIN
    -- ignores NULLs and a portion with no amount would otherwise slip past.
    ------------------------------------------------------------

    IF p_merchants IS NULL
        OR jsonb_typeof(p_merchants) <> 'array'
        OR jsonb_array_length(p_merchants) = 0 THEN
        RAISE EXCEPTION 'Fadlan ugu yaraan hal lacag-bixin waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    SELECT COALESCE(SUM(ROUND((m ->> 'amount_paid')::NUMERIC, 2)), 0),
           MIN(COALESCE(ROUND((m ->> 'amount_paid')::NUMERIC, 2), 0))
    INTO v_merchants_total, v_smallest_paid
    FROM jsonb_array_elements(p_merchants) m;

    IF v_smallest_paid <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagaha ku jira merchantsku waa inay ka weyn yihiin 0'
            USING ERRCODE = 'P1001';
    END IF;

    IF v_merchants_total <> v_expense_total THEN
        RAISE EXCEPTION 'Lacagta la rabo %, laakiin waxaa la helay %',
            v_expense_total, v_merchants_total
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Create the expense
    ------------------------------------------------------------

    INSERT INTO expenses (expense_type,
                          stadium_id,
                          description,
                          expense_date,
                          expense_total)
    VALUES (COALESCE(p_expense_type, 'expense'),
            p_stadium_id,
            p_description,
            p_expense_date,
            v_expense_total)
    RETURNING id INTO v_expense_id;

    ------------------------------------------------------------
    -- Create the transaction and its split
    ------------------------------------------------------------

    INSERT INTO transactions (transaction_type,
                              stadium_id,
                              total_amount,
                              expense_id,
                              processed_by)
    VALUES ('expense',
            p_stadium_id,
            v_expense_total,
            v_expense_id,
            p_processed_by)
    RETURNING id INTO v_transaction_id;

    INSERT INTO transaction_details (transaction_id,
                                     stadium_merchant_id,
                                     merchant_number,
                                     amount_paid)
    SELECT v_transaction_id,
           (m ->> 'stadium_merchant_id')::INT,
           m ->> 'merchant_number',
           ROUND((m ->> 'amount_paid')::NUMERIC, 2)
    FROM jsonb_array_elements(p_merchants) m;

    RETURN v_expense_id;

END;
$$;


-- Corrects an expense that was already recorded.
--
-- The transaction and its split are rewritten with it, so the ledger keeps
-- saying what the expense says.
--
-- processed_by is not touched: it is who paid the money out, not who fixed
-- the record afterwards.
CREATE OR REPLACE FUNCTION public.update_expense_fn(
    p_expense_id INT,
    p_stadium_id UUID,
    p_expense_type VARCHAR(10),
    p_description VARCHAR(100),
    p_expense_date DATE,
    p_expense_total NUMERIC(12, 2),
    p_merchants JSONB
)
    RETURNS INT
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
DECLARE
    v_expense_total   NUMERIC(12, 2);

    v_merchants_total NUMERIC(12, 2);
    v_smallest_paid   NUMERIC(12, 2);

    v_expense_id      INT;
    v_transaction_id  INT;
BEGIN

    ------------------------------------------------------------
    -- Validate the expense
    ------------------------------------------------------------

    IF p_expense_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan kharashka la beddelayo waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_stadium_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan garoonka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_expense_date IS NULL THEN
        RAISE EXCEPTION 'Fadlan taariikhda kharashka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    v_expense_total := ROUND(COALESCE(p_expense_total, 0), 2);

    IF v_expense_total <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagta kharashku waa inay ka weyn tahay 0'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Validate the payment split
    ------------------------------------------------------------

    IF p_merchants IS NULL
        OR jsonb_typeof(p_merchants) <> 'array'
        OR jsonb_array_length(p_merchants) = 0 THEN
        RAISE EXCEPTION 'Fadlan ugu yaraan hal lacag-bixin waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    SELECT COALESCE(SUM(ROUND((m ->> 'amount_paid')::NUMERIC, 2)), 0),
           MIN(COALESCE(ROUND((m ->> 'amount_paid')::NUMERIC, 2), 0))
    INTO v_merchants_total, v_smallest_paid
    FROM jsonb_array_elements(p_merchants) m;

    IF v_smallest_paid <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagaha ku jira merchantsku waa inay ka weyn yihiin 0'
            USING ERRCODE = 'P1001';
    END IF;

    IF v_merchants_total <> v_expense_total THEN
        RAISE EXCEPTION 'Lacagta la rabo %, laakiin waxaa la helay %',
            v_expense_total, v_merchants_total
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Change the expense
    --
    -- Scoped by stadium_id as well as by id, so an id belonging to another
    -- stadium matches nothing and is refused instead of being changed.
    ------------------------------------------------------------

    UPDATE expenses
    SET expense_type  = COALESCE(p_expense_type, expense_type),
        description   = p_description,
        expense_date  = p_expense_date,
        expense_total = v_expense_total
    WHERE id = p_expense_id
      AND stadium_id = p_stadium_id
    RETURNING id INTO v_expense_id;

    IF v_expense_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan kharashka % lama helin', p_expense_id
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Change the transaction
    --
    -- One transaction per expense, which transactions.expense_id already
    -- enforces, so this updates the one it has instead of adding another.
    ------------------------------------------------------------

    UPDATE transactions
    SET total_amount = v_expense_total,
        updated_at   = now()
    WHERE expense_id = v_expense_id
    RETURNING id INTO v_transaction_id;

    IF v_transaction_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan lacag-bixinta kharashka % lama helin', p_expense_id
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Change the payment split
    --
    -- The old portions go and the new ones take their place. The rule that
    -- they must add up to the transaction is judged at COMMIT, so the table
    -- is free to be empty for a moment here.
    ------------------------------------------------------------

    DELETE FROM transaction_details WHERE transaction_id = v_transaction_id;

    INSERT INTO transaction_details (transaction_id,
                                     stadium_merchant_id,
                                     merchant_number,
                                     amount_paid)
    SELECT v_transaction_id,
           (m ->> 'stadium_merchant_id')::INT,
           m ->> 'merchant_number',
           ROUND((m ->> 'amount_paid')::NUMERIC, 2)
    FROM jsonb_array_elements(p_merchants) m;

    RETURN v_expense_id;

END;
$$;
