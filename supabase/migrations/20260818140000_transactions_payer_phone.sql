-- Records the phone number of a customer who paid at the desk, so the manager
-- can find the payment later and call them back.
--
-- Only a walk-in gets one. A customer who paid through the app is already on
-- the transaction as paid_user, and their number is one join away in
-- app_users, kept current by them rather than frozen here — so writing it a
-- second time would only give the manager a number that goes stale. A walk-in
-- has no user row at all and never can: app_users.id references
-- auth.users(id), so a person without an account cannot be given one.
--
-- The first check is what keeps that true. The database refuses the duplicate
-- rather than trusting every caller to avoid it.
--
-- The second keeps the column to payments. An expense and a refund both force
-- paid_user to be null already and neither has a customer to ring.
--
-- Nothing already recorded is touched: the column is nullable with no default,
-- so every transaction written so far stays exactly as it was.
ALTER TABLE public.transactions
    ADD COLUMN IF NOT EXISTS payer_phone varchar(20);

ALTER TABLE public.transactions
    DROP CONSTRAINT IF EXISTS chk_payer_phone_only_without_user;

ALTER TABLE public.transactions
    ADD CONSTRAINT chk_payer_phone_only_without_user
        CHECK (paid_user IS NULL OR payer_phone IS NULL);

ALTER TABLE public.transactions
    DROP CONSTRAINT IF EXISTS chk_payer_phone_only_on_payment;

ALTER TABLE public.transactions
    ADD CONSTRAINT chk_payer_phone_only_on_payment
        CHECK (transaction_type = 'payment' OR payer_phone IS NULL);


COMMENT ON COLUMN public.transactions.payer_phone IS
    'The number a walk-in customer gave at the desk. Null on a payment from '
        'a signed-in customer, whose number is read through paid_user.';


------------------------------------------------------------
-- Finding a payment by phone number
--
-- A search resolves the number against app_users first, then looks for
-- either side: a payment from that user, or a walk-in payment carrying the
-- number itself.
--
--   WHERE t.stadium_id = :stadium
--     AND (t.paid_user = :user_id OR t.payer_phone = :phone)
--
-- app_users.phone_number is already UNIQUE, so the lookup that starts it is
-- free. These two make the rest of it free as well: both are partial, because
-- a row only ever carries one of the two.
------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_transactions_payer_phone
    ON public.transactions (payer_phone)
    WHERE payer_phone IS NOT NULL;

-- Postgres does not index the referencing side of a foreign key on its own.
CREATE INDEX IF NOT EXISTS idx_transactions_paid_user
    ON public.transactions (paid_user)
    WHERE paid_user IS NOT NULL;


------------------------------------------------------------
-- The two functions that take a customer's money
--
-- Both gain p_payer_phone as a last parameter with a default, so a caller
-- that does not collect a number goes on working untouched.
--
-- Dropped rather than replaced: a new parameter makes a new signature, and
-- CREATE OR REPLACE would leave the old function beside the new one for
-- callers to pick between.
------------------------------------------------------------

DROP FUNCTION IF EXISTS public.book_event_fn(
    SMALLINT, TIMESTAMP, VARCHAR, public.event_status,
    NUMERIC, UUID, UUID, JSONB
    );

DROP FUNCTION IF EXISTS public.book_another_half_fn(
    INT, VARCHAR, NUMERIC, UUID, UUID, JSONB
    );


CREATE
OR REPLACE FUNCTION public.book_event_fn(
    p_field_id SMALLINT,
    p_event_start TIMESTAMP,
    p_event_key VARCHAR(4),
    p_event_status public.event_status,
    p_discounted NUMERIC(12, 2),
    p_paid_user UUID,
    p_processed_by UUID,
    p_merchants JSONB,
    p_payer_phone VARCHAR(20) DEFAULT NULL
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

-- A missing amount_paid is COALESCEd to 0 rather than skipped: MIN ignores
-- NULLs, so without it a portion with no amount would slip past the check
-- below and fail later as a NOT NULL violation.
SELECT COALESCE(SUM(ROUND((m ->> 'amount_paid'):: NUMERIC, 2)), 0),
       MIN(COALESCE(ROUND((m ->> 'amount_paid'):: NUMERIC, 2), 0))
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
                          processed_by,
                          payer_phone)
VALUES ('payment',
        v_stadium_id,
        v_amount_due,
        v_discounted,
        v_event_id,
        p_paid_user,
        p_processed_by,
        p_payer_phone) RETURNING id
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


CREATE OR REPLACE FUNCTION public.book_another_half_fn(
    p_event_id INT,
    p_event_key VARCHAR(4),
    p_discounted NUMERIC(12, 2),
    p_paid_user UUID,
    p_processed_by UUID,
    p_merchants JSONB,
    p_payer_phone VARCHAR(20) DEFAULT NULL
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
                              processed_by,
                              payer_phone)
    VALUES ('payment',
            v_stadium_id,
            v_remaining,
            v_discounted,
            p_event_id,
            p_paid_user,
            p_processed_by,
            p_payer_phone)
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
