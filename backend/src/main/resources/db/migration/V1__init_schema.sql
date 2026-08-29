-- MeowPay ledger schema.
--
-- Money lives in exactly one place: wallets.balance, a bigint counting whole
-- treats. There is no floating point anywhere in this schema by design -- the
-- ledger has no fractional treats and therefore no rounding policy to get wrong.
--
-- Identity (cats) is kept separate from money (wallets) so a cat can later hold
-- more than one wallet without reshaping the identity table.

CREATE TABLE cats (
    id          uuid        PRIMARY KEY,
    name        text        NOT NULL,
    avatar_url  text,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE wallets (
    id          uuid        PRIMARY KEY,
    cat_id      uuid        NOT NULL UNIQUE REFERENCES cats (id),
    balance     bigint      NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT now(),
    updated_at  timestamptz NOT NULL DEFAULT now(),

    -- The invariant the database itself refuses to break. Application code
    -- produces the friendly "insufficient treats" error; this constraint is what
    -- stays true when some other code path gets the balance check wrong.
    CONSTRAINT wallet_balance_non_negative CHECK (balance >= 0)
);

CREATE TABLE transfers (
    id                   uuid        PRIMARY KEY,
    idempotency_key      text        NOT NULL,

    -- SHA-256 over (sender, recipient, amount). Lets the replay path tell a
    -- genuine retry from a client reusing one key for a different transfer,
    -- which would otherwise silently return the wrong transfer.
    request_fingerprint  text        NOT NULL,

    sender_wallet_id     uuid        NOT NULL REFERENCES wallets (id),
    recipient_wallet_id  uuid        NOT NULL REFERENCES wallets (id),
    amount               bigint      NOT NULL,
    status               text        NOT NULL,
    created_at           timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT transfer_amount_positive CHECK (amount > 0),
    CONSTRAINT transfer_not_self        CHECK (sender_wallet_id <> recipient_wallet_id)
);

-- The sole arbiter of idempotency. No application-level check-then-act can be
-- race-free on its own: two concurrent requests carrying the same key both pass
-- a SELECT and both proceed. This index is what actually serialises them -- the
-- loser takes a 23505 and replays the winner's transfer.
CREATE UNIQUE INDEX transfers_idempotency_key_uq
    ON transfers (idempotency_key);

-- Ledger reads are "everything this wallet sent or received, newest first".
-- A transfer matches a wallet in either direction, so both directions get an
-- index; neither query can fall back to a sequential scan as the table grows.
CREATE INDEX transfers_sender_created_idx
    ON transfers (sender_wallet_id, created_at DESC);

CREATE INDEX transfers_recipient_created_idx
    ON transfers (recipient_wallet_id, created_at DESC);
