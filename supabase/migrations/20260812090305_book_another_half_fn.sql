-- Settles the half a booking was left owing, and records the payment for it.
--
-- The other side of book_event_fn: that one creates a slot as 'pending' with
-- the second team's share sitting in event_bookings.remaining, and this one
-- takes that share off and confirms the booking.
--
-- No booking rule is asked again. The event already exists, so its field, its
-- day and its hour were settled when it was made — whether the stadium still
-- works that weekday, whether the field still takes bookings, whether half
-- bookings are still allowed are all questions about making a booking, not
-- about paying for one that exists. trg_check_before_booking_event skips
-- itself for exactly this reason when the slot has not moved.
--
-- The field is not a parameter either: the event carries it, and the stadium
-- the ledger entry belongs to is read through it.
--
-- The whole remaining half is taken at once — that is what "book another half"
-- is — so the booking always ends confirmed, owing nothing, with its private
-- code released.
CREATE OR REPLACE FUNCTION public.book_another_half_fn(
    p_event_id INT,
    p_event_key VARCHAR(4),
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
    v_event_status    public.event_status;
    v_event_key       VARCHAR(4);
    v_remaining       NUMERIC(12, 2);

    v_discounted      NUMERIC(12, 2);
    v_required_amount NUMERIC(12, 2);

    v_merchants_total NUMERIC(12, 2);
    v_smallest_paid   NUMERIC(12, 2);

    v_transaction_id  INT;
BEGIN

    ------------------------------------------------------------
    -- Validate payer
    ------------------------------------------------------------

    IF (p_paid_user IS NULL) = (p_processed_by IS NULL) THEN
        RAISE EXCEPTION 'Fadlan p_processed_by ama p_paid_user ayaa loo bahan yahay'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Validate event
    ------------------------------------------------------------

    IF p_event_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan event-ka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Validate merchants
    ------------------------------------------------------------

    IF p_merchants IS NULL
        OR jsonb_typeof(p_merchants) <> 'array'
        OR jsonb_array_length(p_merchants) = 0 THEN
        RAISE EXCEPTION 'Fadlan ugu yaraan hal lacag-bixin waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Find and lock the event
    --
    -- FOR UPDATE is what makes two people paying the same remaining half at
    -- the same moment safe. The second call waits here until the first
    -- commits, and Postgres then re-reads the row it was waiting on, so it
    -- sees the half already taken instead of the figure it started with.
    -- OF e keeps the lock on the booking; the field is only read.
    ------------------------------------------------------------

    SELECT f.stadium_id, e.event_status, e.event_key, e.remaining
    INTO v_stadium_id, v_event_status, v_event_key, v_remaining
    FROM event_bookings e
             JOIN fields f ON f.id = e.field_id
    WHERE e.id = p_event_id
        FOR UPDATE OF e;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fadlan event-ka % lama helin', p_event_id
            USING ERRCODE = 'P1001';
    END IF;

    IF v_event_status <> 'pending' OR v_remaining <= 0 THEN
        RAISE EXCEPTION 'Event-kan lacagtiisa oo dhan hore ayaa loo bixiyay'
            USING ERRCODE = 'P1001';
    END IF;

    IF v_event_key IS NOT NULL THEN
        IF p_event_key IS NULL THEN
            RAISE EXCEPTION 'Event-kani waa xidhan yahay, fadlan code-ka gali'
                USING ERRCODE = 'P1001';
        END IF;

        IF p_event_key <> v_event_key THEN
            RAISE EXCEPTION 'Code-ka aad gelisay waa khalad'
                USING ERRCODE = 'P1001';
        END IF;
    END IF;

    ------------------------------------------------------------
    -- Calculate amount
    ------------------------------------------------------------

    v_discounted := ROUND(COALESCE(p_discounted, 0), 2);

    IF v_discounted < 0 THEN
        RAISE EXCEPTION 'Fadlan qiimo-dhimistu ma noqon karto negative'
            USING ERRCODE = 'P1001';
    END IF;

    -- The discount comes off what this payer hands over and cannot swallow it
    -- whole: some money must actually change hands.
    IF v_discounted >= v_remaining THEN
        RAISE EXCEPTION
            'Fadlan qiimo-dhimistu waa inay ka yartahay lacagta la rabo oo ah (%)',
            v_remaining
            USING ERRCODE = 'P1001';
    END IF;

    v_required_amount := v_remaining - v_discounted;

    ------------------------------------------------------------
    -- Calculate merchant payments
    ------------------------------------------------------------

    SELECT COALESCE(SUM(ROUND((m ->> 'amount_paid')::NUMERIC, 2)), 0),
           MIN(COALESCE(ROUND((m ->> 'amount_paid')::NUMERIC, 2), 0))
    INTO v_merchants_total, v_smallest_paid
    FROM jsonb_array_elements(p_merchants) m;

    IF v_smallest_paid <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagaha ku jira merchantsku waa inay ka weyn yihiin 0'
            USING ERRCODE = 'P1001';
    END IF;

    IF v_merchants_total <> v_required_amount THEN
        RAISE EXCEPTION 'Lacagta la rabo %, laakiin waxaa la helay %',
            v_required_amount, v_merchants_total
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Settle the event
    --
    -- Nothing is owed any more, so it is confirmed and gives up its code —
    -- which also releases it from uq_event_bookings_open_event_key, an index
    -- that only covers pending rows.
    ------------------------------------------------------------

    UPDATE event_bookings
    SET remaining    = 0,
        event_status = 'confirmed',
        event_key    = NULL
    WHERE id = p_event_id;

    ------------------------------------------------------------
    -- Create transaction
    --
    -- total_amount is what this payer owed before the discount; the details
    -- below must add up to total_amount - discounted, which is the sum already
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
            v_remaining,
            v_discounted,
            p_event_id,
            p_paid_user,
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

    RETURN p_event_id;

END;
$$;
