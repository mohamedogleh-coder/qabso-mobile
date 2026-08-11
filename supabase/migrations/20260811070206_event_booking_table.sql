CREATE
EXTENSION IF NOT EXISTS btree_gist;

CREATE TYPE public.event_status AS ENUM (
    'pending',
    'confirmed',
    'cancelled'
    );

CREATE TABLE event_bookings
(
    id              SERIAL PRIMARY KEY,
    field_id        SMALLINT       NOT NULL REFERENCES fields (id) ON DELETE RESTRICT,

    event_start     TIMESTAMP      NOT NULL,
    event_end       TIMESTAMP      NOT NULL,
    event_key       VARCHAR(4),

    extra_time      SMALLINT       NOT NULL DEFAULT 0 CHECK (extra_time >= 0),

    occupied_period TSRANGE GENERATED ALWAYS AS (
        tsrange(event_start,
                event_end + make_interval(mins => extra_time),
                '[)')
        ) STORED,

    event_status public.event_status NOT NULL,

    remaining       NUMERIC(12, 2) NOT NULL DEFAULT 0
        CHECK (remaining >= 0),

    cancelled_at    TIMESTAMPTZ,

    CONSTRAINT chk_event_time
        CHECK (event_start < event_end),

    CONSTRAINT chk_event_status_remaining
        CHECK (
            (event_status = 'pending' AND remaining > 0)
                OR
            (event_status = 'confirmed' AND remaining = 0)
                OR
            (event_status = 'cancelled')
            ),

    CONSTRAINT chk_cancelled_at
        CHECK ((event_status = 'cancelled') = (cancelled_at IS NOT NULL)),


    CONSTRAINT      no_overlapping_events EXCLUDE USING gist
        (
        field_id WITH =,
        occupied_period WITH &&
        ) WHERE (event_status <> 'cancelled')
);

CREATE UNIQUE INDEX uq_event_bookings_open_event_key
    ON event_bookings (event_key) WHERE event_status = 'pending';
