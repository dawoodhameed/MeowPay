-- Demo data, so a fresh clone has something to move on the first run.
--
-- The ids are fixed rather than generated. A reviewer following the README gets
-- the same identifiers the documentation and the API examples use, and anything
-- referencing a cat -- a curl example, a client fixture -- keeps working across a
-- rebuild instead of needing the ids looked up again each time.
--
-- Trade-off, stated plainly: seeding from a versioned migration means it runs in
-- every environment this schema is applied to. For a take-home whose primary path
-- is `docker compose up`, that is exactly what makes the demo work from a cold
-- start. In production this would move behind a profile or a repeatable migration
-- so real data is never created by a schema change.

INSERT INTO cats (id, name) VALUES
    ('11111111-1111-4111-8111-111111111111', 'Whiskers'),
    ('22222222-2222-4222-8222-222222222222', 'Mittens'),
    ('33333333-3333-4333-8333-333333333333', 'Luna');

INSERT INTO wallets (id, cat_id, balance) VALUES
    ('aaaaaaaa-1111-4111-8111-111111111111', '11111111-1111-4111-8111-111111111111', 1000),
    ('bbbbbbbb-2222-4222-8222-222222222222', '22222222-2222-4222-8222-222222222222', 500),
    ('cccccccc-3333-4333-8333-333333333333', '33333333-3333-4333-8333-333333333333', 250);
