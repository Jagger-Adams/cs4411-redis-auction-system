-- Long-term storage for the auction system.
-- Redis handles live bidding (concurrency and real-time updates). This database
-- keeps the durable record: users, items, auction definitions, archived bids,
-- and final auction results.

CREATE TABLE users (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username    TEXT        NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE items (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    seller_id   BIGINT      NOT NULL REFERENCES users (id),
    title       TEXT        NOT NULL,
    description TEXT        NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE auctions (
    id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    item_id              BIGINT      NOT NULL REFERENCES items (id),
    starting_price_cents BIGINT      NOT NULL CHECK (starting_price_cents > 0),
    min_increment_cents  BIGINT      NOT NULL CHECK (min_increment_cents > 0),
    starts_at            TIMESTAMPTZ NOT NULL,
    ends_at              TIMESTAMPTZ NOT NULL,
    status               TEXT        NOT NULL DEFAULT 'scheduled'
                         CHECK (status IN ('scheduled', 'open', 'closed')),

    winner_id            BIGINT      REFERENCES users (id),
    final_price_cents    BIGINT      CHECK (final_price_cents > 0),
    closed_at            TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    CHECK (ends_at > starts_at),
    CHECK ((winner_id IS NULL) = (final_price_cents IS NULL)),
    CHECK (winner_id IS NULL OR status = 'closed'),
    CHECK (closed_at IS NULL OR status = 'closed')
);

CREATE TABLE bids (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    auction_id   BIGINT      NOT NULL REFERENCES auctions (id),
    bidder_id    BIGINT      NOT NULL REFERENCES users (id),
    amount_cents BIGINT      NOT NULL CHECK (amount_cents > 0),

    -- Per-auction event sequence number assigned by Redis when the bid was accepted.
    seq          BIGINT      NOT NULL CHECK (seq > 0),

    -- When Redis accepted the bid 
    created_at   TIMESTAMPTZ NOT NULL,

    -- When the worker wrote it here
    archived_at  TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (auction_id, seq)
);
