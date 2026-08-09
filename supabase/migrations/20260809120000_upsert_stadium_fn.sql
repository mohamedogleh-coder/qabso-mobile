DROP FUNCTION IF EXISTS create_stadium(varchar, smallint, double precision, double precision, boolean, uuid);

CREATE OR REPLACE FUNCTION upsert_stadium(
    p_stadium_id uuid,
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
    IF p_stadium_id IS NULL THEN
        INSERT INTO stadiums (stadium_name,
                              location,
                              extra_time,
                              allow_half_booking)
        VALUES (p_stadium_name,
                ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
                p_extra_time,
                p_allow_half_booking)
        RETURNING id INTO v_stadium_id;

        INSERT INTO stadium_managers (stadium_id, user_id)
        VALUES (v_stadium_id, p_manager_id);
    ELSE
        UPDATE stadiums
        SET stadium_name       = p_stadium_name,
            location           = ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography,
            extra_time         = p_extra_time,
            allow_half_booking = p_allow_half_booking,
            updated_at         = now()
        WHERE id = p_stadium_id
          AND EXISTS (
            SELECT 1
            FROM stadium_managers
            WHERE stadium_id = p_stadium_id
              AND user_id = p_manager_id
        )
        RETURNING id INTO v_stadium_id;

        IF v_stadium_id IS NULL THEN
            RAISE EXCEPTION 'Stadium % not found for manager %', p_stadium_id, p_manager_id;
        END IF;
    END IF;

    RETURN v_stadium_id;
END;
$$;
