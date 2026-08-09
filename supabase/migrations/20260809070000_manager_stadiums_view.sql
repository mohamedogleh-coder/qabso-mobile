-- Exposes each stadium alongside the user_id of the manager who owns it,
-- with the PostGIS `location` point flattened into plain latitude/longitude
-- so the client can read them directly without decoding WKB.
--
-- security_invoker = true makes the view enforce RLS as the querying user
-- rather than the view owner, so it stays safe to expose broadly even after
-- row-level security is added to `stadiums` / `stadium_managers` later.
CREATE VIEW public.manager_stadiums_view
WITH (security_invoker = true) AS
SELECT
    s.id,
    s.stadium_name,
    s.extra_time,
    s.allow_half_booking,
    ST_Y(s.location::geometry) AS latitude,
    ST_X(s.location::geometry) AS longitude,
    sm.user_id
FROM public.stadium_managers sm
JOIN public.stadiums s ON s.id = sm.stadium_id;

GRANT SELECT ON public.manager_stadiums_view TO authenticated;
