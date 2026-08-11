CREATE TABLE public.providers
(
    id               smallserial PRIMARY KEY,
    provider_name    varchar(20) NOT NULL UNIQUE,
    provider_service varchar(20) NOT NULL UNIQUE
);


INSERT INTO public.providers (provider_name, provider_service)
VALUES ('Telesom', 'Zaad Service'),
       ('Somtel', 'eDahab'),
       ('Somtelco', 'eCash');



CREATE TABLE public.stadium_merchants
(
    id              serial PRIMARY KEY,
    merchant_number varchar(20) NOT NULL,
    stadium_id      uuid        NOT NULL
        REFERENCES public.stadiums (id)
            ON DELETE CASCADE,
    provider_id     smallint    NOT NULL
        REFERENCES public.providers (id)
            ON DELETE RESTRICT,
    CONSTRAINT stadium_merchant_unique
        UNIQUE (
                stadium_id,
                provider_id,
                merchant_number
            )
);


-- Registers and edits a stadium's payment numbers in one call. Each element
-- of p_merchants is
-- {"id": int|null, "provider_id": 1..n, "merchant_number": "..."};
-- an element with an id updates that row, one without inserts a new number,
-- so the client can send a mixed list without splitting it first.
--
-- Updates are scoped to p_stadium_id, so an id belonging to another stadium
-- matches nothing instead of being edited.
--
-- Returns the stadium's full set of merchants with the provider embedded as
-- a json object, matching the shape StadiumMerchantModel.fromJson reads.
CREATE OR REPLACE FUNCTION upsert_stadium_merchants(
    p_stadium_id uuid,
    p_merchants jsonb
)
    RETURNS TABLE
            (
                id              integer,
                merchant_number varchar,
                provider        jsonb
            )
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF p_merchants IS NULL OR jsonb_array_length(p_merchants) = 0 THEN
        RAISE EXCEPTION 'No merchants supplied for stadium %', p_stadium_id;
    END IF;

    UPDATE stadium_merchants m
    SET merchant_number = d.merchant_number,
        provider_id     = d.provider_id
    FROM (SELECT (e ->> 'id')::integer              AS id,
                 (e ->> 'merchant_number')::varchar AS merchant_number,
                 (e ->> 'provider_id')::smallint    AS provider_id
          FROM jsonb_array_elements(p_merchants) AS e
          WHERE e ->> 'id' IS NOT NULL) AS d
    WHERE m.id = d.id
      AND m.stadium_id = p_stadium_id;

    INSERT INTO stadium_merchants (stadium_id,
                                   provider_id,
                                   merchant_number)
    SELECT p_stadium_id,
           (e ->> 'provider_id')::smallint,
           (e ->> 'merchant_number')::varchar
    FROM jsonb_array_elements(p_merchants) AS e
    WHERE e ->> 'id' IS NULL;

    RETURN QUERY
        SELECT m.id,
               m.merchant_number,
               to_jsonb(p) AS provider
        FROM stadium_merchants m
                 JOIN providers p ON p.id = m.provider_id
        WHERE m.stadium_id = p_stadium_id
        ORDER BY m.id;
END;
$$;