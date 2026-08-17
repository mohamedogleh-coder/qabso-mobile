-- One stadium with everything on it: its own details, and every field it has
-- with that field's pictures.
--
-- Built for the sheet a customer opens from a favourite stadium card, and for
-- anywhere else a whole stadium is needed from nothing but its id.
--
-- The pictures are read per field in a subquery rather than by joining
-- field_images in. A stadium has several fields and each has several pictures,
-- so joining both and grouping would repeat every field once per picture.
--
-- Closed fields come back too. allow_booking rides along on each field, so the
-- screen decides what to do with a field that is not taking bookings, and the
-- manager's own screens can read this same function.
--
-- The location is stored as a PostGIS point and handed back as plain latitude
-- and longitude, the way manager_stadiums_view does it, so the client never
-- decodes WKB.
CREATE OR REPLACE FUNCTION public.stadium_information_fn(p_stadium_id uuid)
    RETURNS TABLE
            (
                id                 uuid,
                stadium_name       varchar,
                latitude           double precision,
                longitude          double precision,
                extra_time         smallint,
                allow_half_booking boolean,
                created_at         timestamptz,
                updated_at         timestamptz,
                fields             json
            )
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    -- extensions is on the path because postgis may sit there rather than in
    -- public, and the geometry type and the ST_ functions are read from it.
    SET search_path = public, extensions, pg_temp
AS
$$
BEGIN

    IF p_stadium_id IS NULL THEN
        RAISE EXCEPTION 'Fadlan garoonka waa qasab'
            USING ERRCODE = 'P1001';
    END IF;

    -- Every column is written with its table in front of it. The names this
    -- function returns are also variables inside it, so a bare column name
    -- would be read as the variable instead.
    RETURN QUERY
        SELECT s.id,
               s.stadium_name,
               ST_Y(s.location::geometry),
               ST_X(s.location::geometry),
               s.extra_time,
               s.allow_half_booking,
               s.created_at,
               s.updated_at,
               picked.fields

        FROM public.stadiums s

                 CROSS JOIN LATERAL (
            SELECT COALESCE(
                           json_agg(
                           json_build_object(
                                   'id', f.id,
                                   'capacity', f.capacity,
                                   'cost', f.cost,
                                   'allow_booking', f.allow_booking,
                                   'created_at', f.created_at,
                                   'updated_at', f.updated_at,

                                   -- The paths as they are stored. The client
                                   -- turns them into links. A field with no
                                   -- pictures gives [], the same way
                                   -- fields_with_images_view answers.
                                   'field_images', (SELECT COALESCE(
                                                                   json_agg(fi.image_path ORDER BY fi.id),
                                                                   '[]'::json)
                                                    FROM public.field_images fi
                                                    WHERE fi.field_id = f.id)
                           ) ORDER BY f.id),
                           '[]'::json) AS fields
            FROM public.fields f
            WHERE f.stadium_id = s.id
            ) AS picked

        WHERE s.id = p_stadium_id;

END;
$$;


-- The fields are looked up by their stadium every time. Postgres does not
-- index the referencing side of a foreign key on its own, so without this
-- every call scans the whole fields table.
CREATE INDEX IF NOT EXISTS idx_fields_stadium
    ON public.fields (stadium_id);


GRANT EXECUTE ON FUNCTION public.stadium_information_fn(uuid) TO authenticated;

COMMENT ON FUNCTION public.stadium_information_fn IS
    'One stadium with its location flattened to latitude and longitude, and '
        'every field it has with that field''s image paths.';
