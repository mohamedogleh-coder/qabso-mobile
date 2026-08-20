-- Alters generate_booking_time_seq_fn so every booked slot also says who paid
-- for it.
--
-- Two fields are added. isMine tells the signed-in customer that this booking
-- is theirs, so the grid can badge it and open their own booking on tap
-- instead of saying the hour is taken. reference_number is the payer's phone
-- number, which the manager uses to find the customer again.
--
-- The number lives in two places. A customer who paid in the app is on the
-- payment as paid_user and their number is read through app_users. A walk-in
-- has no account, so the desk kept the number on the payment itself as
-- payer_phone. Only one of the two is ever filled.
--
-- Everything else is carried over unchanged from 20260811090616.
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
    v_day_of_week   smallint;
    v_open_time     time;
    v_close_time    time;
    v_is_open       boolean;
    v_slot_span     interval;
    v_my_phone      varchar(20);
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

    -- A field the manager has closed to booking still returns []: it is not
    -- a closed day, and the stadium may well be open for its other fields.
    IF NOT v_allow_booking THEN
        RETURN '[]'::jsonb;
    END IF;

    -- day_of_week is 1..7 Monday-first, which is exactly ISODOW.
    v_day_of_week := EXTRACT(ISODOW FROM p_date)::smallint;

    SELECT w.open_time, w.close_time, w.is_open
    INTO v_open_time, v_close_time, v_is_open
    FROM stadium_working_days w
    WHERE w.stadium_id = v_stadium_id
      AND w.day_of_week = v_day_of_week;

    -- No working day on file and a day switched off are the same answer to
    -- the customer: the stadium does not work then.
    IF NOT FOUND OR NOT v_is_open THEN
        RAISE EXCEPTION 'Garoonku ma furna maalinta % (%).',
            get_day_name(v_day_of_week), p_date
            USING ERRCODE = 'P1001';
    END IF;

    v_slot_span := make_interval(mins => 60 + v_extra_time);

    -- Read once here rather than for every slot. It is the number this
    -- customer keeps on their account, and it is what matches a booking they
    -- paid for at the desk before they had the app.
    SELECT phone_number
    INTO v_my_phone
    FROM app_users
    WHERE id = auth.uid();

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
                                   COALESCE(booked.event_status::text, 'available'),
                                   'isMine', COALESCE(booked.is_mine, FALSE),
                                   'reference_number', booked.phone_number
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
               e.event_status,
               payer.phone_number,

               -- A booking paid in two halves has two payments, and either
               -- one of them may be this customer's. A signed-out caller has
               -- no id and no number, so both sides read null and the answer
               -- is false.
               EXISTS (SELECT 1
                       FROM transactions t
                       WHERE t.event_id = e.id
                         AND t.transaction_type = 'payment'
                         AND (t.paid_user = auth.uid()
                           OR t.payer_phone = v_my_phone)) AS is_mine

        FROM event_bookings e

                 -- The number to call back. The first payment is the one that
                 -- opened the booking, which is the same one
                 -- search_bookings_by_phone_fn hands back.
                 LEFT JOIN LATERAL (
            SELECT COALESCE(u.phone_number, t.payer_phone)::varchar
                       AS phone_number
            FROM transactions t
                     LEFT JOIN app_users u ON u.id = t.paid_user
            WHERE t.event_id = e.id
              AND t.transaction_type = 'payment'
            ORDER BY t.transaction_date, t.id
            LIMIT 1
            ) AS payer ON TRUE

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
