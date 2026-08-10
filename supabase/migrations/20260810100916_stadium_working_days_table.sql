CREATE TABLE stadium_working_days
(
    id          serial PRIMARY KEY,
    stadium_id  uuid     NOT NULL REFERENCES stadiums (id) ON DELETE CASCADE,
    day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
    open_time   time     NOT NULL,
    close_time  time     NOT NULL,
    is_open     boolean  NOT NULL DEFAULT true,
    CONSTRAINT stadium_working_time_check CHECK (close_time > open_time),
    CONSTRAINT stadium_unique_working_day UNIQUE (stadium_id, day_of_week)
);


CREATE OR REPLACE FUNCTION upsert_stadium_working_days(
    p_stadium_id uuid,
    p_days jsonb
)
    RETURNS SETOF stadium_working_days
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF p_days IS NULL OR jsonb_array_length(p_days) = 0 THEN
        RAISE EXCEPTION 'No working days supplied for stadium %', p_stadium_id;
    END IF;

    INSERT INTO stadium_working_days (stadium_id,
                                      day_of_week,
                                      open_time,
                                      close_time,
                                      is_open)
    SELECT p_stadium_id,
           days.day_of_week,
           days.open_time,
           days.close_time,
           days.is_open
    FROM (SELECT DISTINCT ON ((d.value ->> 'day_of_week')::smallint)
                 (d.value ->> 'day_of_week')::smallint             AS day_of_week,
                 (d.value ->> 'open_time')::time                   AS open_time,
                 (d.value ->> 'close_time')::time                  AS close_time,
                 COALESCE((d.value ->> 'is_open')::boolean, true)  AS is_open
          FROM jsonb_array_elements(p_days) WITH ORDINALITY AS d(value, ord)
          ORDER BY (d.value ->> 'day_of_week')::smallint, d.ord DESC) AS days
    ON CONFLICT (stadium_id, day_of_week)
        DO UPDATE SET open_time  = EXCLUDED.open_time,
                      close_time = EXCLUDED.close_time,
                      is_open    = EXCLUDED.is_open;

    RETURN QUERY
        SELECT *
        FROM stadium_working_days
        WHERE stadium_id = p_stadium_id
        ORDER BY day_of_week;
END;
$$;