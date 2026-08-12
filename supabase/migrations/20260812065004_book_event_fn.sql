-- Books one slot and records the payment taken for it.
--
-- Booking rules are NOT repeated here: trg_check_before_booking_event checks
-- the working day, the field, the half-booking policy, the working hours, the
-- slot grid and availability at INSERT time, and fills in event_end,
-- extra_time and event_status. This function works out the money and writes
-- the rows.
--
-- fields.cost is the price of one player, so a slot costs cost * capacity.
-- A 'pending' booking pays half of that now and leaves the other half in
-- event_bookings.remaining; a 'confirmed' booking pays it all.
CREATE
OR REPLACE FUNCTION book_event_fn(
    p_field_id SMALLINT,
    p_event_start TIMESTAMP,
    p_event_key VARCHAR(4),
    p_payment_status public.event_status,
    p_discounted NUMERIC(12, 2),
    p_paid_user UUID,
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
v_stadium_id      UUID;
    v_cost
NUMERIC(12, 2);
    v_capacity
SMALLINT;

    v_total_amount
NUMERIC(12, 2);
    v_amount_due
NUMERIC(12, 2);
    v_required_amount
NUMERIC(12, 2);
    v_remaining
NUMERIC(12, 2);
    v_discounted
NUMERIC(12, 2);

    v_merchants_total
NUMERIC(12, 2);
    v_smallest_paid
NUMERIC(12, 2);

    v_event_id
INT;
    v_transaction_id
INT;
BEGIN

    ------------------------------------------------------------
    -- Validate payer
    ------------------------------------------------------------

    IF
(p_paid_user IS NULL) = (p_processed_by IS NULL) THEN
        RAISE EXCEPTION 'Fadlan p_processed_by ama p_paid_user ayaa loo bahan yahay'
            USING ERRCODE = 'P1001';
END IF;

    ------------------------------------------------------------
    -- Validate event
    ------------------------------------------------------------

    IF
p_field_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan field-ka waa qasab'
            USING ERRCODE = 'P1001';
END IF;

    IF
p_event_start IS NULL THEN
        RAISE EXCEPTION 'Fadlan waqtiga booking-ka waa qasab'
            USING ERRCODE = 'P1001';
END IF;

    -- A booking is created half-paid or fully paid. Cancelling is an update to
    -- a booking that already exists.
    IF
p_event_status IS NULL
        OR p_event_status NOT IN ('pending', 'confirmed') THEN
        RAISE EXCEPTION 'Fadlan state-ka booking-ku waa pending ama confirmed'
            USING ERRCODE = 'P1001';
END IF;

    ------------------------------------------------------------
    -- Validate merchants
    ------------------------------------------------------------

    IF
p_merchants IS NULL
        OR jsonb_typeof(p_merchants) <> 'array'
        OR jsonb_array_length(p_merchants) = 0 THEN
        RAISE EXCEPTION 'Fadlan ugu yaraan hal lacag-bixin waa qasab'
            USING ERRCODE = 'P1001';
END IF;

    ------------------------------------------------------------
    -- Get field price
    ------------------------------------------------------------

SELECT stadium_id, cost, capacity
INTO v_stadium_id, v_cost, v_capacity
FROM fields
WHERE id = p_field_id;

IF
NOT FOUND THEN
        RAISE EXCEPTION 'Fadlan field-ka % lama helin', p_field_id
            USING ERRCODE = 'P1001';
END IF;

    ------------------------------------------------------------
    -- Calculate amount
    ------------------------------------------------------------

    v_total_amount
:= v_cost * v_capacity;
    v_discounted
:= COALESCE(p_discounted, 0);

    IF
v_discounted < 0 THEN
        RAISE EXCEPTION 'Fadlan qiimo-dhimistu ma noqon karto negative'
            USING ERRCODE = 'P1001';
END IF;

    -- remaining is what the other half still owes, so it is the price minus
    -- the half being paid now: the two always add back up to the full price.
    IF
p_event_status = 'pending' THEN
        v_amount_due := ROUND(v_total_amount / 2, 2);
        v_remaining
:= v_total_amount - v_amount_due;
ELSE
        v_amount_due := v_total_amount;
        v_remaining
:= 0;
END IF;

    -- The discount comes off this payer's share only, and cannot swallow it
    -- whole: some money must actually change hands.
    IF
v_discounted >= v_amount_due THEN
        RAISE EXCEPTION
            'Fadlan qiimo-dhimistu waa inay ka yartahy lacagta la rabo oo ah (%)',
            v_amount_due
            USING ERRCODE = 'P1001';
END IF;

    v_required_amount
:= v_amount_due - v_discounted;

    ------------------------------------------------------------
    -- Calculate merchant payments
    ------------------------------------------------------------

SELECT COALESCE(SUM(ROUND((m ->> 'amount_paid'):: NUMERIC, 2)), 0),
       COALESCE(MIN(ROUND((m ->> 'amount_paid'):: NUMERIC, 2)), 0)
INTO v_merchants_total, v_smallest_paid
FROM jsonb_array_elements(p_merchants) m;

IF
v_smallest_paid <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagaha ku jira merchantsku waa inay ka weyn tahay 0'
            USING ERRCODE = 'P1001';
END IF;

    IF
v_merchants_total <> v_required_amount THEN
        RAISE EXCEPTION 'Lacagta la rabo %, laakiin waxaa la helay %',
            v_required_amount, v_merchants_total
            USING ERRCODE = 'P1001';
END IF;

    ------------------------------------------------------------
    -- Create event
    --
    -- event_end, extra_time and event_status are left to the trigger, which
    -- derives all three; remaining is what tells it which booking this is.
    ------------------------------------------------------------

INSERT INTO event_bookings (field_id,
                            event_start,
                            event_key,
                            event_status,
                            remaining)
VALUES (p_field_id,
        p_event_start,
        p_event_key,
        p_event_status,
        v_remaining) RETURNING id
INTO v_event_id;

------------------------------------------------------------
-- Create transaction
--
-- total_amount is what this payer owed before the discount; the details
-- below must add up to total_amount - discounted, which is exactly the sum
-- checked above.
------------------------------------------------------------

INSERT INTO transactions (transaction_type,
                          stadium_id,
                          total_amount,
                          discounted,
                          event_id,
                          paid_user,
                          processed_by)
VALUES ('payment',
        v_stadium_id,
        v_amount_due,
        v_discounted,
        v_event_id,
        p_paid_user,
        p_processed_by) RETURNING id
INTO v_transaction_id;

------------------------------------------------------------
-- Payment split
--
-- No stadium_merchant_id means the portion was paid in cash.
------------------------------------------------------------

INSERT INTO transaction_details (transaction_id,
                                 stadium_merchant_id,
                                 merchant_number,
                                 amount_paid)
SELECT v_transaction_id,
       (m ->> 'stadium_merchant_id')::INT, m ->> 'merchant_number', ROUND((m ->> 'amount_paid'):: NUMERIC, 2)
FROM jsonb_array_elements(p_merchants) m;

RETURN v_event_id;

END;
$$;
