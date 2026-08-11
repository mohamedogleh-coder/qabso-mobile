CREATE OR REPLACE FUNCTION get_day_name(p_day_of_week SMALLINT)
RETURNS TEXT LANGUAGE plpgsql
IMMUTABLE
AS
$$
BEGIN
RETURN CASE p_day_of_week
           WHEN 1 THEN 'Isniin-ta'
           WHEN 2 THEN 'Salaasa-da'
           WHEN 3 THEN 'Arbaca-da'
           WHEN 4 THEN 'Khamiis-ta'
           WHEN 5 THEN 'Jimcaha'
           WHEN 6 THEN 'Sabtida'
           WHEN 7 THEN 'Axada'
           ELSE 'Unknown day'
    END;
END;
$$;
