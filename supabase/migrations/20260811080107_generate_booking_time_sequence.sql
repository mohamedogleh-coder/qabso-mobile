CREATE OR REPLACE FUNCTION generate_booking_time_seq_fn(
    p_field_id SMALLINT,
    p_date DATE
)
    RETURNS JSONB
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
AS
$$
DECLARE
    v_stadium_id    uuid;
    v_allow_booking boolean;
    v_extra_time    smallint;
    v_open_time     time;
    v_close_time    time;
    v_is_open       boolean;
    v_slot_span     interval;
    v_slots         jsonb;
BEGIN
    IF p_field_id IS NULL THEN
        RAISE EXCEPTION 'Field is required.'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_date IS NULL THEN
        RAISE EXCEPTION 'Date is required.'
            USING ERRCODE = 'P1001';
    END IF;

    IF p_date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Cannot generate bookings for a past date: %', p_date
            USING ERRCODE = 'P1001';
    END IF;

    SELECT f.stadium_id, f.allow_booking, s.extra_time
    INTO v_stadium_id, v_allow_booking, v_extra_time
    FROM fields f
             JOIN stadiums s ON s.id = f.stadium_id
    WHERE f.id = p_field_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Field % not found.', p_field_id
            USING ERRCODE = 'P1001';
    END IF;

    -- A field the manager has closed to booking offers nothing, the same as
    -- a day the stadium doesn't open.
    IF NOT v_allow_booking THEN
        RETURN '[]'::jsonb;
    END IF;

    -- day_of_week is 1..7 Monday-first, which is exactly ISODOW.
    SELECT w.open_time, w.close_time, w.is_open
    INTO v_open_time, v_close_time, v_is_open
    FROM stadium_working_days w
    WHERE w.stadium_id = v_stadium_id
      AND w.day_of_week = EXTRACT(ISODOW FROM p_date)::smallint;

    IF NOT FOUND OR NOT v_is_open THEN
        RETURN '[]'::jsonb;
    END IF;

    v_slot_span := make_interval(mins => 60 + v_extra_time);

    -- The series stops at close_time minus a whole slot, so the last offer is
    -- the last one that finishes — extra time included — before closing. A
    -- day too short for even one match yields no rows, hence the COALESCE.
    SELECT COALESCE(
                   jsonb_agg(
                           jsonb_build_object(
                                   'startTime',
                                   to_char(slot.starts_at, 'YYYY-MM-DD HH24:MI'),
                                   'endTime',
                                   to_char(slot.starts_at + INTERVAL '1 hour',
                                           'YYYY-MM-DD HH24:MI'),
                                   'eventId', booked.id,
                                   'eventKey', booked.event_key,
                                   'eventStatus',
                                   COALESCE(booked.event_status::text, 'available')
                           )
                           ORDER BY slot.starts_at
                   ),
                   '[]'::jsonb)
    INTO v_slots
    FROM generate_series(
                 p_date + v_open_time,
                 p_date + v_close_time - v_slot_span,
                 v_slot_span
         ) AS slot(starts_at)
             LEFT JOIN LATERAL (
        SELECT e.id,
               e.event_key,
               e.event_status
        FROM event_bookings e
        WHERE e.field_id = p_field_id
          AND e.event_status <> 'cancelled'
          AND e.occupied_period &&
              tsrange(slot.starts_at, slot.starts_at + v_slot_span, '[)')
        ORDER BY e.event_start
        LIMIT 1
        ) AS booked ON TRUE;

    RETURN v_slots;
END;
$$;
