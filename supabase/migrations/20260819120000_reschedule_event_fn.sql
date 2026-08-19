-- Moves a booking to another hour on the same field.
--
-- No booking rule is repeated here. Changing event_start makes
-- trg_check_before_booking_event validate the new hour the same way it
-- validates a new booking: the stadium's working day, whether the field still
-- takes bookings, the opening hours, the slot alignment and the overlap. It
-- also works out the new event_end and extra_time, so neither is a parameter.
--
-- The money is not touched. A rescheduled booking is the same booking at a
-- different hour, so its payments, what it still owes and its private code all
-- stay as they are.
CREATE OR REPLACE FUNCTION public.reschedule_event_fn(
    p_event_id INT,
    p_start_time TIMESTAMP
)
    RETURNS INT
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
DECLARE
    v_event_status public.event_status;
    v_event_start  TIMESTAMP;
BEGIN

    ------------------------------------------------------------
    -- Validate parameters
    ------------------------------------------------------------

    IF p_event_id IS NULL OR p_start_time IS NULL THEN
        RAISE EXCEPTION 'Fadlan event-ka iyo waqtiga cusub waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    -- Nothing else in the database stops a booking landing in the past, so it
    -- is stopped here.
    IF p_start_time < NOW()::TIMESTAMP THEN
        RAISE EXCEPTION 'Fadlan waqtiga cusub waa inuu mustaqbalka ahaado'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Find and lock the event
    --
    -- FOR UPDATE holds the row while it moves, so two managers moving the
    -- same booking at the same moment take turns instead of both writing.
    ------------------------------------------------------------

    SELECT e.event_status, e.event_start
    INTO v_event_status, v_event_start
    FROM event_bookings e
    WHERE e.id = p_event_id
        FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Fadlan event-ka % lama helin', p_event_id
            USING ERRCODE = 'P1001';
    END IF;

    -- A cancelled booking holds no hour, so there is no hour to move. It also
    -- must not come back to life through a reschedule.
    IF v_event_status = 'cancelled' THEN
        RAISE EXCEPTION 'Event-kan waa la joojiyay, waqtigiisa lama beddeli karo'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_start_time = v_event_start THEN
        RAISE EXCEPTION 'Waqtiga cusub waa isku mid waqtiga hore'
            USING ERRCODE = 'P1001';
    END IF;

    ------------------------------------------------------------
    -- Move the booking
    --
    -- A half paid booking moves too. It keeps what it owes and its code, and
    -- the trigger reads that same remaining to give the row back its pending
    -- status.
    ------------------------------------------------------------

    UPDATE event_bookings
    SET event_start = p_start_time
    WHERE id = p_event_id;

    RETURN p_event_id;

END;
$$;
