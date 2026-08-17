-- A stadium's profile: everything about the stadium itself, how many of its
-- fields are open to booking, and every picture its fields have.
--
-- Built for the Profile tab of the stadium screen, which is opened with
-- nothing but a stadium id.
--
-- The count and the pictures are worked out in laterals of their own rather
-- than by joining fields and field_images in together. A stadium has several
-- fields and each has several pictures, so one join would multiply the rows
-- and the count would come back wrong.
--
-- Each picture carries the field it belongs to and how many players that field
-- holds, so the grid can label a picture without a second read.
CREATE OR REPLACE FUNCTION public.stadium_profile_fn(p_stadium_id uuid)
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
                working_fields     integer,
                field_images       json
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

    RETURN QUERY
        SELECT s.id,
               s.stadium_name,
               ST_Y(s.location::geometry),
               ST_X(s.location::geometry),
               s.extra_time,
               s.allow_half_booking,
               s.created_at,
               s.updated_at,
               counted.working_fields,
               pictures.field_images

        FROM public.stadiums s

            -- Only the fields that still take bookings. A field the manager
            -- closed is not one the stadium is working with.
                 CROSS JOIN LATERAL (
            SELECT COUNT(*)::integer AS working_fields
            FROM public.fields f
            WHERE f.stadium_id = s.id
              AND f.allow_booking
            ) AS counted

            -- The pictures of every field, closed ones included, each with the
            -- field it came from. A plain join is right here: a field with no
            -- pictures has nothing to show and simply drops out.
                 CROSS JOIN LATERAL (
            SELECT COALESCE(
                           json_agg(
                           json_build_object(
                                   'field_id', f.id,
                                   'capacity', f.capacity,
                                   'image_path', fi.image_path
                           ) ORDER BY f.id, fi.id),
                           '[]'::json) AS field_images
            FROM public.fields f
                     JOIN public.field_images fi ON fi.field_id = f.id
            WHERE f.stadium_id = s.id
            ) AS pictures

        WHERE s.id = p_stadium_id;

END;
$$;


GRANT EXECUTE ON FUNCTION public.stadium_profile_fn(uuid) TO authenticated;

COMMENT ON FUNCTION public.stadium_profile_fn IS
    'A stadium with its location flattened to latitude and longitude, how '
        'many fields are open to booking, and every field picture with the '
        'field and capacity it belongs to.';
