CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE public.stadiums
(
    id                   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    stadium_name         varchar(100) NOT NULL UNIQUE,
    location             geography(Point, 4326),
    allow_half_booking   boolean NOT NULL DEFAULT false,
    extra_time           smallint NOT NULL DEFAULT 0
        CHECK (extra_time >= 0),
    created_at           timestamptz NOT NULL DEFAULT now(),
    updated_at           timestamptz NOT NULL DEFAULT now()
);


CREATE INDEX idx_stadiums_location
    ON public.stadiums
    USING GIST(location);