-- Exposes each field alongside its images as a JSON array of image_path
-- strings, so the client never has to stitch fields and field_images
-- together itself. A field with no rows in field_images gets `[]`, not
-- null, thanks to the FILTER + COALESCE below.
CREATE VIEW public.fields_with_images_view
WITH (security_invoker = true) AS
SELECT
    f.id,
    f.stadium_id,
    f.capacity,
    f.cost,
    f.allow_booking,
    f.created_at,
    f.updated_at,
    COALESCE(
        json_agg(fi.image_path ORDER BY fi.id) FILTER (WHERE fi.id IS NOT NULL),
        '[]'::json
    ) AS field_images
FROM public.fields f
LEFT JOIN public.field_images fi ON fi.field_id = f.id
GROUP BY f.id;

GRANT SELECT ON public.fields_with_images_view TO authenticated;
