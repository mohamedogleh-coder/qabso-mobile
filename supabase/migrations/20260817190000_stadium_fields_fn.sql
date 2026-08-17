-- Every field a stadium has, with its pictures.
--
-- Both kinds come back: the fields that take bookings and the ones the manager
-- has closed. allow_booking rides along on each, so the screen says which is
-- which rather than the query hiding half of them.
--
-- The biggest field comes first, because the size of the field is what a group
-- picks by. Closed fields are not pushed to the bottom — a field is listed
-- where its size puts it, and its own row says it is closed.
--
-- The pictures are read per field in a subquery rather than by joining
-- field_images in. A stadium has several fields and each has several pictures,
-- so one join would repeat every field once per picture.
CREATE OR REPLACE FUNCTION public.stadium_fields_fn(p_stadium_id uuid)
    RETURNS TABLE
            (
                id            smallint,
                capacity      smallint,
                cost          numeric,
                allow_booking boolean,
                created_at    timestamptz,
                updated_at    timestamptz,
                field_images  json
            )
    LANGUAGE plpgsql
    STABLE
    SECURITY INVOKER
    SET search_path = public, pg_temp
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
        SELECT f.id,
               f.capacity,
               f.cost,
               f.allow_booking,
               f.created_at,
               f.updated_at,

               -- The paths as they are stored. The client turns them into
               -- links. A field with no pictures gives [], the same way
               -- fields_with_images_view answers.
               (SELECT COALESCE(
                               json_agg(fi.image_path ORDER BY fi.id),
                               '[]'::json)
                FROM public.field_images fi
                WHERE fi.field_id = f.id)

        FROM public.fields f
        WHERE f.stadium_id = p_stadium_id
        ORDER BY f.capacity DESC, f.id;

END;
$$;


GRANT EXECUTE ON FUNCTION public.stadium_fields_fn(uuid) TO authenticated;

COMMENT ON FUNCTION public.stadium_fields_fn IS
    'Every field of a stadium, open and closed alike, biggest first, with '
        'its image paths.';
