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