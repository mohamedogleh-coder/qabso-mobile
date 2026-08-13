-- Counts the events of every field, for one stadium or for all of them.
--
-- The count starts from `fields` and joins the bookings onto it, so a field
-- with no events in the range still comes back with zeros instead of going
-- missing.
--
-- `completed` is not a status. The database only knows pending, confirmed
-- and cancelled, so an event counts as completed once its end time — extra
-- time included — has already passed. A cancelled event was never played,
-- so it is left out of that count.
CREATE OR REPLACE FUNCTION events_summary_fn(
    p_stadium_id uuid DEFAULT NULL,
    p_start_date date DEFAULT NULL,
    p_end_date date DEFAULT NULL
)
    RETURNS JSONB
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
AS
$$
DECLARE
    v_start_date date;
    v_end_date   date;
    v_summary    jsonb;
BEGIN
    -- No dates at all means today. One date on its own is read as that
    -- single day.
    v_start_date := COALESCE(p_start_date, p_end_date, CURRENT_DATE);
    v_end_date := COALESCE(p_end_date, p_start_date, CURRENT_DATE);

    IF v_start_date > v_end_date THEN
        RAISE EXCEPTION 'Start date % is after end date %.',
            v_start_date, v_end_date
            USING ERRCODE = 'P1001';
    END IF;

    -- One pass over the bookings. Every status is counted in the same scan
    -- with FILTER, so the statuses cost no extra queries.
    --
    -- The range is taken on event_start, from the first day at midnight up
    -- to but not including the day after the last one, so the whole of the
    -- last day is included.
    SELECT COALESCE(
                   jsonb_agg(
                           jsonb_build_object(
                                   'fieldId', summary.field_id,
                                   'capacity', summary.capacity,
                                   'totalEvents', summary.total_events,
                                   'pendingEvents', summary.pending_events,
                                   'confirmedEvents', summary.confirmed_events,
                                   'canceledEvents', summary.canceled_events,
                                   'completedEvents', summary.completed_events
                           )
                           ORDER BY summary.field_id
                   ),
                   '[]'::jsonb)
    INTO v_summary
    FROM (SELECT f.id                            AS field_id,
                 f.capacity,
                 COUNT(e.id)                     AS total_events,

                 COUNT(e.id) FILTER (
                     WHERE e.event_status = 'pending'
                     )                           AS pending_events,

                 COUNT(e.id) FILTER (
                     WHERE e.event_status = 'confirmed'
                     )                           AS confirmed_events,

                 COUNT(e.id) FILTER (
                     WHERE e.event_status = 'cancelled'
                     )                           AS canceled_events,

                 COUNT(e.id) FILTER (
                     WHERE e.event_status <> 'cancelled'
                       AND e.event_end + make_interval(mins => e.extra_time)
                         <= LOCALTIMESTAMP
                     )                           AS completed_events

          FROM fields f
                   LEFT JOIN event_bookings e
                             ON e.field_id = f.id
                                 AND e.event_start >= v_start_date::timestamp
                                 AND e.event_start < (v_end_date + 1)::timestamp
          -- A null stadium asks for every stadium.
          WHERE p_stadium_id IS NULL
             OR f.stadium_id = p_stadium_id
          GROUP BY f.id, f.capacity) AS summary;

    RETURN v_summary;
END;
$$;
