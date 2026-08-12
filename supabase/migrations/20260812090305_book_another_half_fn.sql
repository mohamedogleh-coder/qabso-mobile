-- Settles the half a booking was left owing.
--
-- The other side of book_event_fn: that one creates a slot as 'pending' with
-- the second team's share sitting in event_bookings.remaining, and this one
-- takes that share off. No new booking is created — the slot, the field and
-- the hour are the ones already on file, so none of the booking rules are
-- asked again here. trg_check_before_booking_event still runs on the UPDATE
-- (remaining and event_status are both in its column list) and re-derives the
-- status from remaining, which is why the status written below can only ever
-- agree with it.
--
-- Money is not recorded here: the payment flow writes the transaction and its
-- details. [p_amount_paid] is what the booking is credited with — the figure
-- before any discount, the same amount book_event_fn credits the first half
-- with.
--
-- Returns the booking as it now stands, so the caller can show whether it is
-- settled or still owes something without re-reading it.
CREATE OR REPLACE FUNCTION public.book_another_half_fn(
    p_event_id INT,
    p_field_id SMALLINT,
    p_amount_paid NUMERIC(12, 2),
    p_event_key VARCHAR(4) DEFAULT NULL
)
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
DECLARE
    v_field_id      SMALLINT;
    v_event_status  public.event_status;
    v_event_key     VARCHAR(4);
    v_remaining     NUMERIC(12, 2);

    v_amount_paid   NUMERIC(12, 2);
    v_new_remaining NUMERIC(12, 2);
    v_new_status    public.event_status;
    v_new_key       VARCHAR(4);
BEGIN

    ------------------------------------------------------------
    -- Validate parameters
    ------------------------------------------------------------

    IF p_event_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan event-ka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_field_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan field-ka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    v_amount_paid := ROUND(COALESCE(p_amount_paid, 0), 2);

    IF v_amount_paid <= 0 THEN
        RAISE EXCEPTION 'Fadlan lacagta la bixinayo waa inay ka weyn tahay 0'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Find and lock the event
    --
    -- FOR UPDATE is what makes two people paying the same remaining half at
    -- the same moment safe. The second call waits here until the first
    -- commits, and Postgres then re-reads the row it was waiting on, so it
    -- carries on against the remaining the first one left behind rather than
    -- the figure it started with. Both cannot take the same half.
    ------------------------------------------------------------

    SELECT field_id, event_status, event_key, remaining
    INTO v_field_id, v_event_status, v_event_key, v_remaining
    FROM event_bookings
    WHERE id = p_event_id
        FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fadlan event-ka % lama helin', p_event_id
            USING ERRCODE = 'P1001';
    END IF;

    -- The half being paid must belong to the booking the caller is looking at.
    IF v_field_id <> p_field_id THEN
        RAISE EXCEPTION 'Event-kani kuma jiro field-ka aad dooratay'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Is there a half left to take?
    ------------------------------------------------------------

    IF v_event_status = 'cancelled' THEN
        RAISE EXCEPTION 'Event-kan waa la joojiyay'
            USING ERRCODE = 'P1001';
    END IF;

    -- chk_event_status_remaining ties 'pending' to remaining > 0, so a booking
    -- that is not pending is one that owes nothing.
    IF v_event_status <> 'pending' OR v_remaining <= 0 THEN
        RAISE EXCEPTION 'Event-kan lacagtiisa oo dhan hore ayaa loo bixiyay'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- The private code
    --
    -- Only a locked half asks for one: the code is what the first team was
    -- handed to give to whoever pays the rest. A booking left open has no
    -- code, and asking for one would lock a slot that was meant for anyone.
    ------------------------------------------------------------

    IF v_event_key IS NOT NULL THEN
        IF p_event_key IS NULL THEN
            RAISE EXCEPTION
                'Event-kani waa xidhan yahay, fadlan code-ka gali'
                USING ERRCODE = 'P1001';
        END IF;

        IF p_event_key <> v_event_key THEN
            RAISE EXCEPTION 'Code-ka aad gelisay waa khalad'
                USING ERRCODE = 'P1001';
        END IF;
    END IF;

    ------------------------------------------------------------
    -- The money
    ------------------------------------------------------------

    IF v_amount_paid > v_remaining THEN
        RAISE EXCEPTION
            'Lacagta la bixinayo (%) way ka badan tahay inta hadhay (%)',
            v_amount_paid, v_remaining
            USING ERRCODE = 'P1001';
    END IF;

    v_new_remaining := v_remaining - v_amount_paid;

    -- Settled in full: the booking becomes confirmed and gives up its code,
    -- which also releases it from uq_event_bookings_open_event_key — that
    -- index only covers pending rows, so a code left behind on a confirmed
    -- booking would keep a value reserved that nothing can use.
    IF v_new_remaining = 0 THEN
        v_new_status := 'confirmed';
        v_new_key := NULL;
    ELSE
        v_new_status := 'pending';
        v_new_key := v_event_key;
    END IF;

    ------------------------------------------------------------
    -- Settle it
    ------------------------------------------------------------

    UPDATE event_bookings
    SET remaining    = v_new_remaining,
        event_status = v_new_status,
        event_key    = v_new_key
    WHERE id = p_event_id;

    RETURN jsonb_build_object(
            'eventId', p_event_id,
            'eventStatus', v_new_status::text,
            'remaining', v_new_remaining,
            'eventKey', v_new_key,
            'amountPaid', v_amount_paid
           );

END;
$$;
