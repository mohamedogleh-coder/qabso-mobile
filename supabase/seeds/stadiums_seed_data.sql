-- Seed data for the stadium tables. Development only.
--
-- NOT a migration: nothing here runs on its own. Run it by hand against a
-- local database.
--
-- It creates 15 stadiums, their fields, their seven working days, and payment
-- numbers for some of them. No managers are created, so every stadium here is
-- unassigned.
--
-- setseed() fixes the random sequence, so every run of this file writes the
-- same data. Change the seed value at the top to get a different set.
--
-- stadium_name is unique, so a second run fails instead of writing the same
-- stadiums twice. Remove them first — see the cleanup at the bottom.

DO
$$
    DECLARE
        -- More names than stadiums, so the 15 that are used are a random pick.
        v_name_pool      text[]   := ARRAY [
            'Garoonka Sheekh Cali', 'Hargeysa Sports Arena', 'Berbera Beach Field',
            'Burco United Ground', 'Jigjiga Yar Arena', 'Xero Awr Field',
            'Naasa Hablood Arena', 'Maroodijeex Ground', 'Gacan Libaax Field',
            'Daami Sports Park', 'Ahmed Dhagax Arena', 'Ibrahim Koodbuur Field',
            'Sha''ab Sports Ground', 'Koodbuur Green Field', 'Togdheer Arena',
            'Saylici Sports Field', 'New Hargeysa Pitch', 'Golden Goal Arena',
            'Mansoor Sports Field', 'Ceegaag Ground', 'Xamdi Arena',
            'Salaam Sports Park', 'Waaheen Field', 'Barwaaqo Arena'
            ];

        v_names          text[];
        v_name           text;

        v_stadium_id     uuid;

        v_field_count    int;

        v_day            int;
        v_open_hour      int;
        v_close_hour     int;
        v_is_open        boolean;

        v_provider_id    smallint;
        v_number_prefix  text;

        v_stadium_no     int      := 0;
        v_field_total    int      := 0;
        v_merchant_total int      := 0;
    BEGIN

        PERFORM setseed(0.42);

        SELECT array_agg(pool.name)
        INTO v_names
        FROM (SELECT unnest(v_name_pool) AS name
              ORDER BY random()
              LIMIT 15) AS pool;

        FOREACH v_name IN ARRAY v_names
            LOOP
                v_stadium_no := v_stadium_no + 1;

                ------------------------------------------------------------
                -- The stadium
                --
                -- The points are scattered over Hargeysa. ST_MakePoint takes
                -- the longitude first, the same way create_stadium builds it.
                ------------------------------------------------------------

                INSERT INTO stadiums (stadium_name,
                                      location,
                                      extra_time,
                                      allow_half_booking)
                VALUES (v_name,
                        ST_SetSRID(
                                ST_MakePoint(43.90 + random() * 0.40,
                                             9.45 + random() * 0.25),
                                4326)::geography,
                        (ARRAY [0, 5, 10, 15])[(1 + floor(random() * 4))::int]::smallint,
                        random() < 0.5)
                RETURNING id INTO v_stadium_id;

                ------------------------------------------------------------
                -- Its fields
                --
                -- A stadium gets 0, 2 or 3 fields. Drawing from this list
                -- makes a field-less stadium the rarer case.
                --
                -- cost is the price for one player, so a full slot is
                -- capacity * cost.
                ------------------------------------------------------------

                v_field_count := (ARRAY [0, 2, 2, 3, 3])[(1 + floor(random() * 5))::int];
                v_field_total := v_field_total + v_field_count;

                FOR i IN 1..v_field_count
                    LOOP
                        INSERT INTO fields (stadium_id,
                                            capacity,
                                            cost,
                                            allow_booking)
                        VALUES (v_stadium_id,
                                (6 + floor(random() * 9))::smallint,
                                round((2 + random() * 6)::numeric * 2) / 2,
                                random() < 0.85);
                    END LOOP;

                ------------------------------------------------------------
                -- Its working days
                --
                -- All seven days are written, open or not, because the table
                -- keeps hours on a closed day too. Friday is the rest day
                -- here, so it is the day most often closed.
                --
                -- A day opens between 08:00 and 17:00 and closes at least
                -- three hours later, never past 21:00. Closing is drawn from
                -- opening, so close_time is always the later of the two.
                ------------------------------------------------------------

                FOR v_day IN 1..7
                    LOOP
                        v_is_open := CASE
                                         WHEN v_day = 5 THEN random() < 0.40
                                         ELSE random() < 0.85
                            END;

                        v_open_hour := 8 + floor(random() * 10)::int;
                        v_close_hour := v_open_hour + 3
                            + floor(random() * (21 - v_open_hour - 3 + 1))::int;

                        INSERT INTO stadium_working_days (stadium_id,
                                                          day_of_week,
                                                          open_time,
                                                          close_time,
                                                          is_open)
                        VALUES (v_stadium_id,
                                v_day::smallint,
                                make_time(v_open_hour, 0, 0),
                                make_time(v_close_hour, 0, 0),
                                v_is_open);
                    END LOOP;

                ------------------------------------------------------------
                -- Its payment numbers
                --
                -- About a third of the stadiums take no payments yet. The
                -- rest get one number for each of one to three providers,
                -- picked at random. One number per provider, so
                -- (stadium, provider, number) can never repeat.
                ------------------------------------------------------------

                IF random() < 0.65 THEN
                    FOR v_provider_id, v_number_prefix IN
                        SELECT id,
                               CASE provider_name
                                   WHEN 'Telesom' THEN '063'
                                   WHEN 'Somtel' THEN '065'
                                   ELSE '068'
                                   END
                        FROM providers
                        ORDER BY random()
                        LIMIT (1 + floor(random() * 3))::int
                        LOOP
                            INSERT INTO stadium_merchants (stadium_id,
                                                           provider_id,
                                                           merchant_number)
                            VALUES (v_stadium_id,
                                    v_provider_id,
                                    v_number_prefix
                                        || lpad(floor(random() * 10000000)::int::text, 7, '0'));

                            v_merchant_total := v_merchant_total + 1;
                        END LOOP;
                END IF;

            END LOOP;

        RAISE NOTICE 'Seeded % stadiums, % fields, % working days, % payment numbers.',
            v_stadium_no, v_field_total, v_stadium_no * 7, v_merchant_total;

    END
$$;


-- ---------------------------------------------------------------------
-- Check it
-- ---------------------------------------------------------------------

-- What each stadium ended up with:
-- SELECT s.stadium_name,
--        s.extra_time,
--        s.allow_half_booking,
--        ST_Y(s.location::geometry) AS latitude,
--        ST_X(s.location::geometry) AS longitude,
--        (SELECT count(*) FROM fields f WHERE f.stadium_id = s.id)            AS fields,
--        (SELECT count(*) FROM stadium_working_days w
--          WHERE w.stadium_id = s.id AND w.is_open)                           AS open_days,
--        (SELECT count(*) FROM stadium_merchants m WHERE m.stadium_id = s.id) AS merchants
-- FROM stadiums s
-- ORDER BY s.stadium_name;

-- Every stadium should have seven working days, all of them valid:
-- SELECT stadium_id, count(*), bool_and(close_time > open_time) AS times_ok,
--        min(open_time), max(close_time)
-- FROM stadium_working_days
-- GROUP BY stadium_id;

-- ---------------------------------------------------------------------
-- Clean up — development databases only
-- ---------------------------------------------------------------------

-- This drops the stadiums and everything hanging off them, bookings included.
-- Never run it anywhere money has been taken.
--
-- DELETE FROM stadiums
-- WHERE stadium_name IN (
--     'Garoonka Sheekh Cali', 'Hargeysa Sports Arena', 'Berbera Beach Field',
--     'Burco United Ground', 'Jigjiga Yar Arena', 'Xero Awr Field',
--     'Naasa Hablood Arena', 'Maroodijeex Ground', 'Gacan Libaax Field',
--     'Daami Sports Park', 'Ahmed Dhagax Arena', 'Ibrahim Koodbuur Field',
--     'Sha''ab Sports Ground', 'Koodbuur Green Field', 'Togdheer Arena',
--     'Saylici Sports Field', 'New Hargeysa Pitch', 'Golden Goal Arena',
--     'Mansoor Sports Field', 'Ceegaag Ground', 'Xamdi Arena',
--     'Salaam Sports Park', 'Waaheen Field', 'Barwaaqo Arena'
-- );
