
CREATE TABLE public.favourite_stadiums
(
    user_id    uuid        NOT NULL DEFAULT auth.uid()
        REFERENCES public.app_users (id) ON DELETE CASCADE,

    stadium_id uuid        NOT NULL
        REFERENCES public.stadiums (id) ON DELETE CASCADE,

    created_at timestamptz NOT NULL DEFAULT now(),

    PRIMARY KEY (user_id, stadium_id)
);


ALTER TABLE public.favourite_stadiums
    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read their own favourite stadiums"
    ON public.favourite_stadiums
    FOR SELECT TO authenticated
    USING (user_id = auth.uid());

CREATE POLICY "Users save their own favourite stadiums"
    ON public.favourite_stadiums
    FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users remove their own favourite stadiums"
    ON public.favourite_stadiums
    FOR DELETE TO authenticated
    USING (user_id = auth.uid());


GRANT SELECT, INSERT, DELETE ON public.favourite_stadiums TO authenticated;
