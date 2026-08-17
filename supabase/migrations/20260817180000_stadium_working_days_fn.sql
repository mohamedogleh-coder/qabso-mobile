-- The working days a stadium has saved, in week order.
--
-- Only the days the stadium actually wrote down come back. A day that was
-- never saved has no row here, and is not invented.
--
-- day_of_week is 1..7 Monday-first, which is what EXTRACT(ISODOW) gives, so a
-- caller matching a date against these days compares the two directly.
CREATE OR REPLACE FUNCTION public.stadium_working_days_fn(p_stadium_id uuid)
    RETURNS TABLE
            (
                id          integer,
                day_of_week smallint,
                open_time   time,
                close_time  time,
                is_open     boolean
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
        SELECT w.id,
               w.day_of_week,
               w.open_time,
               w.close_time,
               w.is_open
        FROM public.stadium_working_days w
        WHERE w.stadium_id = p_stadium_id
        ORDER BY w.day_of_week;

END;
$$;


GRANT EXECUTE ON FUNCTION public.stadium_working_days_fn(uuid) TO authenticated;

COMMENT ON FUNCTION public.stadium_working_days_fn IS
    'The days a stadium has saved as working days, with its opening hours, '
        'in week order.';
