CREATE OR REPLACE FUNCTION public.check_before_booking_event_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$function$
DECLARE
v_stadium_id    uuid;
    v_day_of_week
smallint;
    v_extra_time
smallint;
    v_half_booking
boolean;
    v_allow_booking
boolean;
    v_is_open
boolean;
    v_open_time
time;
    v_close_time
time;
    v_slot_minutes
int;
    v_slot_span
interval;
    v_day_open
timestamp;
    v_day_close
timestamp;
    v_is_half
boolean;
    v_offset_min
numeric;
BEGIN
    -- A cancelled row occupies nothing: no_overlapping_events skips it and so
    -- does the availability query, so there is nothing left to validate. It
    -- also must not be re-derived, or cancelling a booking would flip
    -- event_status straight back to pending/confirmed.
    IF
NEW.event_status = 'cancelled' THEN
        RETURN NEW;
END IF;

    -- NOT NULL is only enforced after BEFORE triggers run, so guard here.
    -- Otherwise a NULL folds every check below to NULL and the row is
    -- rejected with the wrong reason.
    IF
NEW.field_id IS NULL OR NEW.event_start IS NULL THEN
        RAISE EXCEPTION 'Fadlan field-ka iyo waqtiga bookingka waa qasab'
            USING ERRCODE = 'P1001';
END IF;

SELECT f.stadium_id, f.allow_booking, s.extra_time, s.allow_half_booking
INTO v_stadium_id, v_allow_booking, v_extra_time, v_half_booking
FROM fields f
         JOIN stadiums s ON s.id = f.stadium_id
WHERE f.id = NEW.field_id;

IF
NOT FOUND THEN
        RAISE EXCEPTION 'Fadlan field-ka % lama helin', NEW.field_id
            USING ERRCODE = 'P1001';
END IF;

    -- 1. Does the stadium work on this weekday at all?
    --    day_of_week is 1..7 Monday-first, which is exactly ISODOW.
    v_day_of_week
:= EXTRACT(ISODOW FROM NEW.event_start)::smallint;

SELECT swd.open_time, swd.close_time, swd.is_open
INTO v_open_time, v_close_time, v_is_open
FROM stadium_working_days swd
WHERE swd.stadium_id = v_stadium_id
  AND swd.day_of_week = v_day_of_week;

-- No working day on file and a day switched off are the same answer to the
-- customer, the same way generate_booking_time_seq_fn reports them.
IF
NOT FOUND OR v_is_open IS NOT TRUE THEN
        RAISE EXCEPTION 'Fadlan maalinka % garoonku ma shaqaynayo',
            get_day_name(v_day_of_week)
            USING ERRCODE = 'P1001';
END IF;

    -- 2. Is this particular field still open to bookings?
    IF
v_allow_booking IS NOT TRUE THEN
        RAISE EXCEPTION 'Fadlan field-kan booking-ka waa laga joojiyay'
            USING ERRCODE = 'P1001';
END IF;

    -- 3. If this is a half booking, does the stadium's policy allow it?
    --    A half booking is one that is not settled in full. remaining is the
    --    only record of that on the row, and chk_event_status_remaining
    --    already ties remaining > 0 to 'pending', which is why event_status is
    --    derived from the same value further down rather than trusted from the
    --    caller.
    v_is_half
:= COALESCE(NEW.remaining, 0) > 0;

    IF
v_is_half AND v_half_booking IS NOT TRUE THEN
        RAISE EXCEPTION 'Fadlan policy-ga garoonkan ma ogola half booking'
            USING ERRCODE = 'P1001';
END IF;

    v_slot_minutes
:= 60 + v_extra_time;
    v_slot_span
:= make_interval(mins => v_slot_minutes);

    -- event_end is the hour of play alone. extra_time is added on top of it by
    -- the occupied_period generated column, so adding it here too would make
    -- every booking reserve the buffer twice and swallow part of the next
    -- slot. The seed data and generate_booking_time_seq_fn both treat
    -- event_end as event_start + 1 hour.
    NEW.extra_time
:= v_extra_time;
    NEW.event_end
:= NEW.event_start + INTERVAL '1 hour';

    -- Compared as timestamps rather than ::time, because `time + interval`
    -- wraps around midnight: a 23:30 slot would otherwise end at 00:30 and
    -- quietly pass a closing-time test done on times.
    v_day_open
:= NEW.event_start::date + v_open_time;
    v_day_close
:= NEW.event_start::date + v_close_time;

    IF
NEW.event_start < v_day_open
        OR NEW.event_start + v_slot_span > v_day_close THEN
        RAISE EXCEPTION 'Fadlan maalinka % saacada % garoonku ma shaqeeyo',
            get_day_name(v_day_of_week), NEW.event_start::time
            USING ERRCODE = 'P1001';
END IF;

    v_offset_min
:= EXTRACT(EPOCH FROM (NEW.event_start - v_day_open)) / 60;

    IF
MOD(v_offset_min, v_slot_minutes::numeric) <> 0 THEN
        RAISE EXCEPTION
            'Fadlan saacada % kama mid aha xiliyada la heli karo maalinka %',
            NEW.event_start::time, get_day_name(v_day_of_week)
            USING ERRCODE = 'P1001';
END IF;

    IF
v_is_half THEN
        NEW.event_status := 'pending';
ELSE
        NEW.event_status := 'confirmed';
END IF;

    -- 5. Advisory check only. Under concurrency two racing transactions both
    --    pass it, and no_overlapping_events is what actually rejects the loser
    --    at write time; this test exists so the ordinary case gets a readable
    --    message instead of a raw 23P01. It therefore mirrors the constraint
    --    exactly — same range, same cancelled filter — so it can never refuse a
    --    booking the constraint would have accepted. occupied_period is not
    --    readable from NEW in a BEFORE trigger (generated columns are computed
    --    afterwards), so the range is rebuilt here with the same expression;
    --    the && lets it ride the constraint's GiST index.
    IF
EXISTS (SELECT 1
               FROM event_bookings e
               WHERE e.field_id = NEW.field_id
                 AND e.id IS DISTINCT FROM NEW.id
                 AND e.event_status <> 'cancelled'
                 AND e.occupied_period && tsrange(
                     NEW.event_start,
                     NEW.event_end + make_interval(mins => NEW.extra_time),
                     '[)')) THEN
        RAISE EXCEPTION 'Fadlan maalinka % saacada % waa la qabsaday',
            get_day_name(v_day_of_week), NEW.event_start::time
            USING ERRCODE = 'P1001';
END IF;

RETURN NEW;
END;
$function$;

-- event_end, extra_time and remaining are in the column list because the
-- trigger derives event_end/extra_time and reads remaining: leaving them out
-- would let an UPDATE move a booking's end, drop its buffer, or change what it
-- owes without any of it being re-checked.
--
-- No pg_trigger_depth() guard: this is a BEFORE trigger that only edits NEW,
-- so it cannot recurse, and the guard would have skipped validation entirely
-- for any booking written from inside another trigger or trigger-called
-- function.
CREATE TRIGGER trg_check_before_booking_event
    BEFORE INSERT OR
UPDATE OF event_start, event_end, field_id, event_status,
    extra_time, remaining
ON event_bookings
    FOR EACH ROW
    EXECUTE FUNCTION check_before_booking_event_fn();
