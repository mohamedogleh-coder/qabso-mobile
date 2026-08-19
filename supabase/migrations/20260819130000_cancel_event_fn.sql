------------------------------------------------------------
-- Why a cancellation was made
--
-- It is kept on the booking rather than on the refund, because the reason
-- belongs to the cancellation itself and sits beside cancelled_at, where
-- anyone reading the booking will find it.
--
-- Nothing already recorded is touched: the column is nullable with no
-- default, so every booking written so far stays exactly as it was. What
-- makes it required is cancel_event_fn, the only way a booking is cancelled.
------------------------------------------------------------

ALTER TABLE public.event_bookings
    ADD COLUMN IF NOT EXISTS cancel_reason VARCHAR(255);

COMMENT ON COLUMN public.event_bookings.cancel_reason IS
    'Why the booking was cancelled. Written by cancel_event_fn and null on '
        'every booking that is still standing.';


------------------------------------------------------------
-- Cancels a booking and hands back the money that was taken for it.
--
-- The two happen together on purpose. A cancellation that committed without
-- its refund would leave money with no booking left to act on, and no screen
-- could give it back.
--
-- The whole paid amount goes back, never a part of it: p_refund_amount must
-- equal what actually changed hands, which is every payment less its discount.
-- Nothing already refunded is taken off it, because a refund is only ever
-- written when a booking is cancelled and a cancelled booking cannot be
-- cancelled again.
--
-- No booking rule is asked again. check_before_booking_event_fn returns at its
-- first line for a cancelled row, so the day, the field and the hour are left
-- as they were written. The hour itself is freed the moment the status flips:
-- no_overlapping_events and generate_booking_time_seq_fn both skip cancelled
-- rows, so the slot shows as available again with nothing else to do.
--
-- What is owed is not cleared. chk_event_status_remaining puts no rule on a
-- cancelled row, and remaining is the record of what the booking was, so it
-- stays as it stands.
------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.cancel_event_fn(
    p_event_id INT,
    p_processed_by UUID,
    p_refund_amount NUMERIC(12, 2),
    p_merchants JSONB,
    p_description VARCHAR(100)
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

    v_paid            NUMERIC(12, 2);
    v_refund_amount   NUMERIC(12, 2);

    v_merchants_total NUMERIC(12, 2);
    --Qiimaha ku jiri kara merchantska
    v_smallest_paid   NUMERIC(12, 2);

    v_transaction_id  INT;
BEGIN

    ------------------------------------------------------------
    -- Validate parameters
    --
    -- Money going out records only the staff member who paid it, which is
    -- what chk_transaction_actors asks of a refund.
    ------------------------------------------------------------

    IF p_event_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan event-ka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_processed_by IS NULL THEN
        RAISE EXCEPTION 'Fadlan p_processed_by ayaa loo bahan yahay'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_description IS NULL OR BTRIM(p_description) = '' THEN
        RAISE EXCEPTION 'Fadlan sababta joojinta waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_merchants IS NULL
        OR jsonb_typeof(p_merchants) <> 'array'
        OR jsonb_array_length(p_merchants) = 0 THEN
        RAISE EXCEPTION 'Fadlan ugu yaraan hal lacag-celin waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Find and lock the event
    --
    -- FOR UPDATE is what makes two managers cancelling the same booking at
    -- the same moment safe. The second call waits here until the first
    -- commits, then re-reads the row and finds it already cancelled.
    -- OF e keeps the lock on the booking; the field is only read.
    ------------------------------------------------------------

    SELECT f.stadium_id, e.event_status
    INTO v_stadium_id, v_event_status
    FROM event_bookings e
             JOIN fields f ON f.id = e.field_id
    WHERE e.id = p_event_id
        FOR UPDATE OF e;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fadlan event-ka % lama helin', p_event_id
            USING ERRCODE = 'P1001';
    END IF;

    IF v_event_status = 'cancelled' THEN
        RAISE EXCEPTION 'Event-kan horey ayaa la joojiyay'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- What is there to hand back
    --
    -- The money that actually changed hands: every payment less the discount
    -- it was given. This is the same figure event_paid_amount_fn reads, so the
    -- refund sheet and this check always agree.
    ------------------------------------------------------------

    SELECT COALESCE(SUM(t.total_amount - t.discounted), 0)
    INTO v_paid
    FROM transactions t
    WHERE t.event_id = p_event_id
      AND t.transaction_type = 'payment';

    IF v_paid <= 0 THEN
        RAISE EXCEPTION 'Event-kan lacag lagu celiyo ma leh'
            USING ERRCODE = 'P1001';
    END IF;

    v_refund_amount := ROUND(COALESCE(p_refund_amount, 0), 2);

    -- The whole amount goes back or none of it. A part refund is not a
    -- cancellation.
    IF v_refund_amount <> v_paid THEN
        RAISE EXCEPTION
            'Lacagta la celinayo waa inay le''ekaataa lacagta la bixiyay oo ah (%)',
            v_paid
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Calculate the payout split
    --
    -- A missing amount_paid is COALESCEd to 0 rather than skipped: MIN
    -- ignores NULLs, so without it a portion with no amount would slip past
    -- the check below and fail later as a NOT NULL violation.
    ------------------------------------------------------------

    SELECT COALESCE(SUM(ROUND((m ->> 'amount_paid')::NUMERIC, 2)), 0),
           MIN(COALESCE(ROUND((m ->> 'amount_paid')::NUMERIC, 2), 0))
    INTO v_merchants_total, v_smallest_paid
    FROM jsonb_array_elements(p_merchants) m;

    IF v_smallest_paid <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagaha ku jira merchantsku waa inay ka weyn yihiin 0'
            USING ERRCODE = 'P1001';
    END IF;

    IF v_merchants_total <> v_refund_amount THEN
        RAISE EXCEPTION 'Lacagta la celinayo %, laakiin waxaa la helay %',
            v_refund_amount, v_merchants_total
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Cancel the booking
    --
    -- chk_cancelled_at ties the two columns together, so the time is written
    -- with the status. The code is released with them: a cancelled booking
    -- has no half left for anyone to pay.
    ------------------------------------------------------------

    UPDATE event_bookings
    SET event_status  = 'cancelled',
        cancelled_at  = NOW(),
        cancel_reason = BTRIM(p_description),
        event_key     = NULL
    WHERE id = p_event_id;

    ------------------------------------------------------------
    -- Create the refund
    --
    -- No discount and no payer: chk_discount_only_on_payment and
    -- chk_transaction_actors both refuse them on money going out. The details
    -- below must add up to total_amount, which is the sum already checked.
    ------------------------------------------------------------

    INSERT INTO transactions (transaction_type,
                              stadium_id,
                              total_amount,
                              event_id,
                              processed_by)
    VALUES ('refund',
            v_stadium_id,
            v_refund_amount,
            p_event_id,
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
