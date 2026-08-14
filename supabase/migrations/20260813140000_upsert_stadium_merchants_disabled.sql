DROP FUNCTION IF EXISTS public.upsert_stadium_merchants(uuid, jsonb);

CREATE
OR REPLACE FUNCTION upsert_stadium_merchants(
    p_stadium_id uuid,
    p_merchants jsonb
)
    RETURNS TABLE
            (
                id              integer,
                merchant_number varchar,
                disabled        boolean,
                provider        jsonb
            )
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF
p_merchants IS NULL OR jsonb_array_length(p_merchants) = 0 THEN
        RAISE EXCEPTION 'No merchants supplied for stadium %', p_stadium_id;
END IF;

UPDATE stadium_merchants m
SET merchant_number = d.merchant_number,
    provider_id     = d.provider_id FROM (SELECT (e ->> 'id')::integer              AS id,
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
       (e ->> 'provider_id')::smallint, (e ->> 'merchant_number') ::varchar
FROM jsonb_array_elements(p_merchants) AS e
WHERE e ->> 'id' IS NULL;

RETURN QUERY
SELECT m.id,
       m.merchant_number,
       m.disabled,
       to_jsonb(p) AS provider
FROM stadium_merchants m
         JOIN providers p ON p.id = m.provider_id
WHERE m.stadium_id = p_stadium_id
ORDER BY m.id;
END;
$$;
