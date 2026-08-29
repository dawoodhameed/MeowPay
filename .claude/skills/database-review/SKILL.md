---
name: database-review
description: Review MeowPay's schema, indexes, transaction boundaries, and query performance against the migrations and the JPA layer. Use when adding a migration, an entity, or a query.
---

# Database Review

Design-time review of the persistence layer. Distinct from `/ledger-audit`, which scans for financial
safety defects — this one asks whether the schema and its access patterns are sound.

## Schema

Read every file in `backend/src/main/resources/db/migration/` in version order, then the entities.

- **Types carry meaning.** Money is `bigint`. Timestamps are `timestamptz`, never `timestamp` — the
  latter silently drops the offset and will misorder a ledger across a DST boundary.
- **Constraints live in the database.** Every invariant the application enforces should also be a
  constraint, unless there is a stated reason it cannot be. Application checks produce good errors;
  constraints are what remain true when a script bypasses the application.
- **Nullability is deliberate.** A nullable column on the money path is a question the schema is
  refusing to answer.
- **Foreign keys are present**, and their `ON DELETE` behaviour is chosen rather than defaulted.
  A ledger row must never be orphaned by a deleted wallet — and it must never be silently deleted
  with one either.

## Migrations

- Immutable once applied. An edit to an applied migration fails checksum validation for everyone
  whose database already ran it. New change, new file.
- Reversible in principle, or explicitly one-way with a note saying so.
- Destructive statements (`DROP`, `ALTER … TYPE`, `NOT NULL` on a populated table) get called out
  regardless of how safe they look on an empty local database.
- `ddl-auto` must be `validate`, so Flyway owns the schema and a drifted entity fails at boot.

## Indexes

For each query the application actually issues, name the index that serves it. Then check the
converse: every index should have a query justifying it, since each one is write amplification on
every insert.

Specific to this schema — a transfer matches a wallet as **either** sender or recipient, so a ledger
query filtered on one wallet needs both directional indexes, or it degrades to a sequential scan as
the table grows.

## Transaction boundaries

- Is the annotated method the one that actually mutates, and is it reachable through the Spring proxy?
  A `@Transactional` method called via `this.method()` is not transactional at all.
- Does anything that must be atomic span two transactions?
- Is any transaction held open across a network call or a slow computation? Every millisecond a
  transaction is open is a millisecond its row locks block other writers.
- Is `open-in-view` disabled? Leaving it on keeps a session open for the whole request and turns lazy
  loading in a serialiser into queries nobody wrote.

## Query performance

```bash
grep -rn "@Query\|findAll\|findBy" backend/src/main/kotlin
```

- **N+1.** A lazy association touched inside a loop or during serialisation. This is the single most
  common Spring Data performance defect and it is invisible until the data grows.
- **Unbounded reads.** `findAll()` on a table that grows without limit. Ledger endpoints need a cap
  and a cursor — offset pagination degrades linearly and skips rows when data is inserted mid-page.
- **Fetch strategy.** `EAGER` on a collection pulls the whole graph on every read.

## Report

A table of findings — `file:line`, problem, consequence, fix — then one line per verified property,
so what was actually checked is visible rather than inferred.
