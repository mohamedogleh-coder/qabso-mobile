ALTER TABLE stadium_managers
    ADD CONSTRAINT unique_manager_stadium
        UNIQUE (user_id);

CREATE
OR REPLACE FUNCTION create_stadium(
    p_stadium_name varchar(100),
    p_extra_time smallint,
    p_latitude double precision,
    p_longitude double precision,
    p_allow_half_booking boolean,
    p_manager_id uuid
)
    RETURNS uuid
    LANGUAGE plpgsql
AS
$$
DECLARE
v_stadium_id uuid;
BEGIN

INSERT INTO stadiums (stadium_name,
                      location,
                      extra_time,
                      allow_half_booking)
VALUES (p_stadium_name,
        ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
        p_extra_time,
        p_allow_half_booking) RETURNING id
INTO v_stadium_id;

INSERT INTO stadium_managers (stadium_id, user_id)
VALUES (v_stadium_id, p_manager_id);

RETURN v_stadium_id;
END;
$$;