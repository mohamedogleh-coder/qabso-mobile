CREATE TYPE public.transaction_type AS ENUM (
    'payment',
    'expense',
    'refund'
    );


-- Lets transactions carry stadium_id while still guaranteeing it matches the
-- expense it settles: the composite foreign key below needs this to point at.
ALTER TABLE expenses
    ADD CONSTRAINT expenses_id_stadium_key UNIQUE (id, stadium_id);


CREATE TABLE transactions
(
    id               SERIAL PRIMARY KEY,

    transaction_type public.transaction_type NOT NULL,

    -- The ledger is read per stadium, so it is recorded here rather than
    -- reached through the event's field or the expense on every query.
    stadium_id       UUID                    NOT NULL
        REFERENCES stadiums (id) ON DELETE CASCADE,

    total_amount     NUMERIC(12, 2)          NOT NULL CHECK (total_amount > 0),

    discounted       NUMERIC(12, 2)          NOT NULL DEFAULT 0
        CHECK (discounted >= 0),

    transaction_date TIMESTAMPTZ             NOT NULL DEFAULT now(),

    event_id         INT REFERENCES event_bookings (id) ON DELETE CASCADE,

    -- One transaction per expense: an expense settled in instalments would be
    -- several expenses, not several transactions against one.
    expense_id       INT UNIQUE,

    -- Restricted, not nulled: a financial record must not lose who paid or
    -- who took the money. A user with transactions cannot be deleted.
    paid_user        UUID REFERENCES app_users (id) ON DELETE RESTRICT,
    processed_by     UUID REFERENCES app_users (id) ON DELETE RESTRICT,

    created_at       TIMESTAMPTZ             NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ             NOT NULL DEFAULT now(),

    -- Ties expense_id and stadium_id together, so an expense cannot be
    -- settled on another stadium's ledger. Not enforced when expense_id is
    -- NULL, which is what MATCH SIMPLE gives us for free.
    CONSTRAINT transactions_expense_stadium_fkey
        FOREIGN KEY (expense_id, stadium_id)
            REFERENCES expenses (id, stadium_id) ON DELETE CASCADE,

    -- Every transaction has exactly one source, and which one it is follows
    -- from its type.
    CONSTRAINT chk_transaction_source
        CHECK (
            (transaction_type IN ('payment', 'refund')
                AND event_id IS NOT NULL
                AND expense_id IS NULL)
                OR
            (transaction_type = 'expense'
                AND expense_id IS NOT NULL
                AND event_id IS NULL)
            ),

    -- A customer payment records whoever it came from — the paying customer,
    -- or the staff member who took it at the desk. Money the stadium pays out
    -- is never "from" a customer, so it records only the staff member.
    CONSTRAINT chk_transaction_actors
        CHECK (
            (transaction_type = 'payment'
                AND (paid_user IS NOT NULL OR processed_by IS NOT NULL))
                OR
            (transaction_type IN ('expense', 'refund')
                AND processed_by IS NOT NULL
                AND paid_user IS NULL)
            ),

    CONSTRAINT chk_discount_within_total
        CHECK (discounted <= total_amount),

    -- Only a customer can be given a discount.
    CONSTRAINT chk_discount_only_on_payment
        CHECK (transaction_type = 'payment' OR discounted = 0)
);


CREATE TABLE transaction_details
(
    id                  SERIAL PRIMARY KEY,

    transaction_id      INT            NOT NULL
        REFERENCES transactions (id) ON DELETE CASCADE,

    -- The merchant that took this portion, kept two ways on purpose.
    --
    -- stadium_merchant_id is the live link, used to join back to the provider
    -- (Zaad / eDahab / eCash) and to report per merchant. It is nulled rather
    -- than restricted when a merchant is retired, so managers stay free to
    -- delete numbers they no longer use.
    --
    -- merchant_number is the number as it stood when the money moved. It is
    -- what a receipt must reproduce: editing or deleting the merchant later
    -- must not rewrite where past payments actually went.
    stadium_merchant_id INT REFERENCES stadium_merchants (id) ON DELETE SET NULL,
    merchant_number     VARCHAR(20),

    amount_paid         NUMERIC(12, 2) NOT NULL CHECK (amount_paid > 0),

    -- No merchant number means the portion was paid in cash. A link without
    -- the snapshot is what we must never store, since retiring the merchant
    -- would then erase where the money went.
    CONSTRAINT chk_detail_merchant_snapshot
        CHECK (stadium_merchant_id IS NULL OR merchant_number IS NOT NULL)
);


-- The distribution must account for the transaction exactly: the details
-- together settle what was actually owed, total_amount less any discount.
--
-- A sum across a child table cannot be written as a CHECK, so this is a
-- deferred constraint trigger. Deferred because a transaction and its details
-- arrive together and the total only means anything once all of them have
-- landed — so it is judged at COMMIT, not row by row.
CREATE OR REPLACE FUNCTION assert_transaction_distribution_matches_total(
    p_transaction_id INTEGER
)
    RETURNS void
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_settles numeric(12, 2);
    v_paid    numeric(12, 2);
BEGIN
    SELECT t.total_amount - t.discounted
    INTO v_settles
    FROM transactions t
    WHERE t.id = p_transaction_id;

    -- The transaction went with this statement; its details went with it.
    IF NOT FOUND THEN
        RETURN;
    END IF;

    SELECT COALESCE(SUM(d.amount_paid), 0)
    INTO v_paid
    FROM transaction_details d
    WHERE d.transaction_id = p_transaction_id;

    IF v_paid <> v_settles THEN
        RAISE EXCEPTION
            'Lacagta la qaybiyay (%) kuma egna lacagta la bixinayo (%).',
            v_paid, v_settles
            USING ERRCODE = 'P1001';
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION check_transaction_distribution_on_detail_change()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM assert_transaction_distribution_matches_total(OLD.transaction_id);
    ELSE
        PERFORM assert_transaction_distribution_matches_total(NEW.transaction_id);
    END IF;

    RETURN NULL;
END;
$$;


CREATE OR REPLACE FUNCTION check_transaction_distribution_on_amount_change()
    RETURNS trigger
    LANGUAGE plpgsql
AS
$$
BEGIN
    PERFORM assert_transaction_distribution_matches_total(NEW.id);

    RETURN NULL;
END;
$$;


CREATE CONSTRAINT TRIGGER trg_check_transaction_distribution_on_detail_change
    AFTER INSERT OR UPDATE OR DELETE
    ON transaction_details
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE FUNCTION check_transaction_distribution_on_detail_change();


CREATE CONSTRAINT TRIGGER trg_check_transaction_distribution_on_amount_change
    AFTER INSERT OR UPDATE OF total_amount, discounted
    ON transactions
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
EXECUTE FUNCTION check_transaction_distribution_on_amount_change();


-- The stadium's ledger, newest first.
CREATE INDEX idx_transactions_stadium_date
    ON transactions (stadium_id, transaction_date DESC);

-- What has been paid against one booking. Postgres does not index the
-- referencing side of a foreign key on its own.
CREATE INDEX idx_transactions_event
    ON transactions (event_id);

CREATE INDEX idx_transaction_details_transaction
    ON transaction_details (transaction_id);

CREATE INDEX idx_transaction_details_merchant
    ON transaction_details (stadium_merchant_id);
