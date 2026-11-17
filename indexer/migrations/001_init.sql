-- OrkoPay indexer schema.
-- `invoices` is owned by the OrkoNet API; the indexer only updates payment
-- columns. It is created here so the indexer can run standalone in dev.

CREATE TABLE IF NOT EXISTS invoices (
    id               UUID PRIMARY KEY,
    order_id         TEXT        NOT NULL UNIQUE,   -- lower-case 0x hex, keccak256(id)
    merchant_address TEXT        NOT NULL,          -- lower-case 0x hex
    asset            TEXT        NOT NULL,          -- 0x000...000 for ETH
    amount           NUMERIC(78) NOT NULL,          -- base units
    status           TEXT        NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'paid', 'underpaid', 'refunded', 'expired')),
    status_reason    TEXT,
    paid_amount      NUMERIC(78),
    fee_amount       NUMERIC(78),
    payer_address    TEXT,
    paid_tx_hash     TEXT,
    paid_block       BIGINT,
    refund_tx_hash   TEXT,
    refund_block     BIGINT,
    expires_at       TIMESTAMPTZ NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS invoices_status_idx ON invoices (status);
CREATE INDEX IF NOT EXISTS invoices_merchant_idx ON invoices (merchant_address);

CREATE TABLE IF NOT EXISTS indexer_cursor (
    contract   TEXT PRIMARY KEY,
    last_block BIGINT      NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
