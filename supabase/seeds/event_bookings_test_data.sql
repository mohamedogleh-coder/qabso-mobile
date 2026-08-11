-- Test data for generate_booking_time_seq_fn.
--
-- NOT a migration: nothing here runs automatically. Run it by hand, then
-- call the function and compare against the "expect" notes on each row.
--
-- Every event is placed on a real slot boundary computed the same way the
-- function computes them (open_time + n * (60 + extra_time)), so the seed
-- stays correct whatever the stadium's hours and extra time are.
--
-- occupied_period is a generated column — never insert it.

DO
$$
    DECLARE
        v_field_id   smallint := 1;            -- <<< the field to seed
        v_date       date     := CURRENT_DATE; -- <<< the date to seed

        v_extra_time smallint;
        v_open_time  time;
        v_close_time time;
        v_span       interval;
        v_slot_count int;
        v_start      timestamp;
    BEGIN
        SELECT s.extra_time, w.open_time, w.close_time
        INTO v_extra_time, v_open_time, v_close_time
        FROM fields f
                 JOIN stadiums s ON s.id = f.stadium_id
                 JOIN stadium_working_days w
                      ON w.stadium_id = s.id
                          AND w.day_of_week = EXTRACT(ISODOW FROM v_date)::smallint
        WHERE f.id = v_field_id
          AND w.is_open;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Field % is not open on % — set its working day first.',
                v_field_id, v_date;
        END IF;

        v_span := make_interval(mins => 60 + v_extra_time);

        v_slot_count := floor(
                                EXTRACT(EPOCH FROM ((v_date + v_close_time - v_span)
                                    - (v_date + v_open_time)))
                                    / EXTRACT(EPOCH FROM v_span)
                        )::int + 1;

        IF v_slot_count < 8 THEN
            RAISE EXCEPTION
                'Day % fits only % slot(s) (open %, close %, slot %); this seed needs 8.',
                v_date, v_slot_count, v_open_time, v_close_time, v_span;
        END IF;

        RAISE NOTICE 'Seeding field % on % — open %, extra % min, slot %, % slots available.',
            v_field_id, v_date, v_open_time, v_extra_time, v_span, v_slot_count;

        v_start := v_date + v_open_time + 0 * v_span;
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining, event_key)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour', v_extra_time,
                'pending', 50.00, '4821');

        v_start := v_date + v_open_time + 1 * v_span;
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining, event_key)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour', v_extra_time,
                'pending', 75.00, NULL);

        -- slot 2 — CONFIRMED: fully paid, so remaining must be 0.
        -- expect: eventStatus "confirmed", eventKey null
        v_start := v_date + v_open_time + 2 * v_span;
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour', v_extra_time,
                'confirmed', 0);

        -- slot 3 — CANCELLED only. The regression test: a cancelled event keeps
        -- its row but must not hold the slot.
        -- expect: eventStatus "available", eventId null
        v_start := v_date + v_open_time + 3 * v_span;
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining, cancelled_at)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour', v_extra_time,
                'cancelled', 50.00, now());

        -- slot 4 — CANCELLED then rebooked. Both rows occupy the same period,
        -- which only inserts at all because the exclusion constraint ignores
        -- cancelled rows.
        -- expect: eventStatus "confirmed" (the live row, not the cancelled one)
        v_start := v_date + v_open_time + 4 * v_span;
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining, cancelled_at)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour', v_extra_time,
                'cancelled', 100.00, now());
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour', v_extra_time,
                'confirmed', 0);

        -- slot 5 — deliberately left empty.
        -- expect: eventStatus "available"

        -- slot 6 — booked under an OLDER extra-time policy (10 min longer than
        -- the stadium's current setting). Its occupied_period therefore runs
        -- 10 minutes past where slot 7 begins.
        -- expect: slot 6 "pending", AND slot 7 also reports this same eventId,
        --         even though nothing starts at slot 7 — per-row extra_time.
        v_start := v_date + v_open_time + 6 * v_span;
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining, event_key)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour',
                v_extra_time + 10, 'pending', 60.00, '9137');

        -- Another date, same field — isolation check.
        -- expect: absent from v_date's sequence entirely
        v_start := (v_date + 1) + v_open_time;
        INSERT INTO event_bookings (field_id, event_start, event_end, extra_time,
                                    event_status, remaining, event_key)
        VALUES (v_field_id, v_start, v_start + INTERVAL '1 hour', v_extra_time,
                'pending', 40.00, '7788');
    END
$$;


-- ---------------------------------------------------------------------
-- Check it
-- ---------------------------------------------------------------------

-- The sequence itself:
-- SELECT jsonb_pretty(generate_booking_time_seq_fn(1::smallint, CURRENT_DATE));

-- What was actually stored, occupied_period included:
-- SELECT id, event_start, event_end, extra_time, event_status, remaining,
--        event_key, occupied_period
-- FROM event_bookings
-- WHERE field_id = 1
-- ORDER BY event_start, id;

-- Expected failures — each should raise, none should insert:
--   past date            SELECT generate_booking_time_seq_fn(1::smallint, CURRENT_DATE - 1);
--   null field           SELECT generate_booking_time_seq_fn(NULL, CURRENT_DATE);
--   unknown field        SELECT generate_booking_time_seq_fn(32000::smallint, CURRENT_DATE);
--   double booking       INSERT INTO event_bookings (field_id, event_start, event_end,
--                            extra_time, event_status, remaining)
--                        SELECT field_id, event_start, event_end, extra_time, 'pending', 10
--                        FROM event_bookings WHERE event_status = 'confirmed' LIMIT 1;
--   paid but pending     ... event_status 'confirmed' with remaining > 0
--   cancelled, no stamp  ... event_status 'cancelled' with cancelled_at NULL

-- Clean up:
-- DELETE FROM event_bookings WHERE field_id = 1;
