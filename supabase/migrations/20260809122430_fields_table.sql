CREATE TABLE public.fields
(
    id            smallserial PRIMARY KEY,
    stadium_id    uuid           NOT NULL REFERENCES public.stadiums (id) ON DELETE CASCADE,

    capacity      smallint       NOT NULL CHECK (capacity BETWEEN 6 AND 14),

    cost          numeric(12, 2) NOT NULL CHECK (cost > 0),

    allow_booking boolean        NOT NULL DEFAULT true,

    created_at    timestamptz    NOT NULL DEFAULT now(),

    updated_at    timestamptz    NOT NULL DEFAULT now()
);



CREATE TABLE field_images
(
    id         smallserial primary key,
    image_path text     not null,
    field_id   smallint not null references fields (id) on delete cascade
);


CREATE OR REPLACE FUNCTION create_field(
    p_stadium_id uuid,
    p_capacity smallint,
    p_cost numeric(12,2),
    p_allow_booking boolean,
    p_image_paths text[]
)
RETURNS smallint LANGUAGE plpgsql AS $$
DECLARE
v_field_id smallint;
v_image_path text;
BEGIN

INSERT INTO fields (
    stadium_id,
    capacity,
    cost,
    allow_booking
)
VALUES (
           p_stadium_id,
           p_capacity,
           p_cost,
           p_allow_booking
       )
    RETURNING id
INTO v_field_id;

IF p_image_paths IS NOT NULL
       AND array_length(p_image_paths, 1) > 0 THEN

        FOREACH v_image_path IN ARRAY p_image_paths
        LOOP
            INSERT INTO field_images (
                image_path,
                field_id
            )
            VALUES (
                v_image_path,
                v_field_id
            );
END LOOP;

END IF;

RETURN v_field_id;
END;
$$;