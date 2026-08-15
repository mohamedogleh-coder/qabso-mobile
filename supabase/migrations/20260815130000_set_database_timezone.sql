-- Puts the database on the stadium's clock.
--
-- event_start and event_end are `timestamp` without a time zone, and the app
-- writes them as Somalia wall-clock time: a booking at 10:00 is stored as
-- 10:00. The server, however, ran in UTC — three hours behind — so every
-- function that asked the server what time it is got an answer three hours
-- earlier than the stadium's.
--
-- What that broke:
--   * check_before_closing_working_day_fn counted bookings that had already
--     been played as still to come, so a day could not be closed after its
--     games were over;
--   * events_summary_fn counted a played event as not yet completed for three
--     hours after it ended;
--   * generate_booking_time_seq_fn judged "is this date in the past" against
--     the wrong day between midnight and 03:00.
--
-- Setting the database's own time zone makes LOCALTIMESTAMP and CURRENT_DATE
-- read the same clock the bookings are stored in, so all three read correctly
-- without a line of their code changing. timestamptz columns — created_at,
-- transaction_date and the rest — are unaffected in what they store; they
-- simply display in local time now.
--
-- The name is taken from current_database() so this runs the same on a local
-- database as on the hosted one.
--
-- The setting is read when a connection starts, so existing pooled
-- connections keep the old zone until they are recycled.
DO
$$
    BEGIN
        EXECUTE format(
                'ALTER DATABASE %I SET timezone TO %L',
                current_database(),
                'Africa/Mogadishu'
                );
    END;
$$;
