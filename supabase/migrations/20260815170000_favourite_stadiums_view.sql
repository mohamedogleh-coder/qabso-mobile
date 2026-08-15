-- The signed-in user's saved stadiums, with the location flattened into
-- plain latitude/longitude so the client reads them without decoding WKB.
--
-- security_invoker = true keeps the row level security on favourite_stadiums
-- in force, so the view returns the caller's own saved list and nothing else.
CREATE VIEW public.favourite_stadiums_view
WITH (security_invoker = true) AS
SELECT s.id,
       s.stadium_name,
       s.extra_time,
       s.allow_half_booking,
       ST_Y(s.location::geometry) AS latitude,
       ST_X(s.location::geometry) AS longitude,
       s.created_at,
       s.updated_at,
       f.created_at               AS favourited_at
FROM public.favourite_stadiums f
         JOIN public.stadiums s ON s.id = f.stadium_id;

GRANT SELECT ON public.favourite_stadiums_view TO authenticated;
