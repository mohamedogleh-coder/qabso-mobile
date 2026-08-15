-- Stops a weekday from being closed while bookings are still standing on it.
--
-- Closing a day is how a stadium says it no longer works that weekday. New
-- bookings stop landing on it, but the ones already taken stay in the table —
-- customers would arrive to a stadium that no longer expects them. So the day
-- is only allowed to close once nothing is left on it that has not been
-- played.
--
-- A booking is still standing when it was not cancelled and its time has not
-- passed. A cancelled booking was never played and has already given its slot
-- back, and a booking whose time has gone is history — neither can stop a day
-- from closing.
--
-- The check lives here rather than in the app so a second client, a script, or
-- the Supabase dashboard cannot close a day around it.
CREATE OR REPLACE FUNCTION public.check_before_closing_working_day_fn()
    RETURNS trigger
    LANGUAGE plpgsql
    SECURITY INVOKER
    SET search_path = public, pg_temp
AS
$$
DECLARE
    v_upcoming_bookings integer;
BEGIN

    ------------------------------------------------------------
    -- Only a day being closed is of interest
    --
    -- Opening a day, or changing its hours, takes nothing away from anyone.
    ------------------------------------------------------------

    IF NEW.is_open OR NOT OLD.is_open THEN
        RETURN NEW;
    END IF;

    ------------------------------------------------------------
    -- Count what is still standing on that weekday
    --
    -- A booking reaches its stadium through its field. ISODOW numbers the days
    -- 1..7 from Monday, which is how day_of_week is numbered too, so the
    -- weekday is read off event_start rather than stored a second time.
    --
    -- occupied_period already ends at event_end plus any extra time, so its
    -- upper bound is the moment the pitch is free again. event_start is a
    -- plain timestamp, so it is compared against LOCALTIMESTAMP, not now().
    ------------------------------------------------------------

    SELECT COUNT(*)
    INTO v_upcoming_bookings
    FROM event_bookings e
             JOIN fields f ON f.id = e.field_id
    WHERE f.stadium_id = NEW.stadium_id
      AND e.event_status <> 'cancelled'
      AND EXTRACT(ISODOW FROM e.event_start) = NEW.day_of_week
      AND upper(e.occupied_period) > LOCALTIMESTAMP;

    IF v_upcoming_bookings > 0 THEN
        RAISE EXCEPTION '% wuxuu leeyahay % booking oo aan weli la ciyaarin.',
            get_day_name(NEW.day_of_week), v_upcoming_bookings
            USING ERRCODE = 'P1001';
    END IF;

    RETURN NEW;

END;
$$;


-- Listed on is_open alone, so changing a day's hours never pays for the count.
CREATE TRIGGER trg_check_before_closing_working_day
    BEFORE UPDATE OF is_open
    ON stadium_working_days
    FOR EACH ROW
EXECUTE FUNCTION check_before_closing_working_day_fn();


-- The count reads one stadium's bookings through its fields, so the
-- referencing side of that foreign key is indexed. Postgres does not do it on
-- its own.
CREATE INDEX IF NOT EXISTS idx_event_bookings_field_start
    ON event_bookings (field_id, event_start);
