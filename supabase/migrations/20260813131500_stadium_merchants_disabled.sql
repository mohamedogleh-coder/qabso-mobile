-- A payment number that has taken money is part of the ledger, so it must
-- not be deletable any more. It is turned off instead.
--
-- Before this, deleting a merchant nulled the link on every detail it had
-- taken (ON DELETE SET NULL), leaving the money attached to a number with no
-- provider behind it. RESTRICT stops the delete instead, so a number stays
-- reachable for as long as any payment points at it.
ALTER TABLE public.stadium_merchants
    ADD COLUMN disabled boolean NOT NULL DEFAULT false;

ALTER TABLE public.transaction_details
    DROP CONSTRAINT IF EXISTS transaction_details_stadium_merchant_id_fkey;

ALTER TABLE public.transaction_details
    ADD CONSTRAINT transaction_details_stadium_merchant_id_fkey
        FOREIGN KEY (stadium_merchant_id)
            REFERENCES public.stadium_merchants (id)
            ON DELETE RESTRICT;

-- Any detail whose merchant was already deleted kept its merchant_number but
-- lost the link. Nothing can join those back, so they are left as they are —
-- from here on the link is the one that survives.
COMMENT ON COLUMN public.stadium_merchants.disabled IS
    'Turned off for new payments. Kept so past payments still resolve.';
