CREATE
OR REPLACE VIEW public.manager_stadiums_view
WITH (security_invoker = true) AS
SELECT s.id,
       s.stadium_name,
       s.extra_time,
       s.allow_half_booking,
       ST_Y(s.location::geometry) AS latitude,
       ST_X(s.location::geometry) AS longitude,
       sm.user_id,
       s.created_at,
       s.updated_at
FROM public.stadium_managers sm
         JOIN public.stadiums s ON s.id = sm.stadium_id;

GRANT SELECT ON public.manager_stadiums_view TO authenticated;
