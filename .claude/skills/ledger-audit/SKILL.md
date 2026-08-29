---
name: ledger-audit
description: Audit the MeowPay backend for financial-safety defects — floating-point money, missing transaction boundaries, absent or misordered row locks, and idempotency that breaks under concurrency. Use before any commit that touches money movement, and in adversarial review.
---

# Ledger Audit

A read-only financial safety scan of `backend/`. Report findings; do not fix anything unless
explicitly asked afterwards.

Each check below has a **grep to run first** and a **judgement to make second**. The grep narrows
where to look; it never decides the verdict on its own. Read the surrounding code before ruling.

## The checks

### 1. Money is never floating point
```bash
grep -rnE '\b(Float|Double|BigDecimal)\b' backend/src/main/kotlin
grep -rnE '\b(REAL|DOUBLE PRECISION|NUMERIC|DECIMAL|FLOAT)\b' backend/src/main/resources/db/migration
```
Balances and amounts must be `Long` in Kotlin and `bigint` in Postgres. A `BigDecimal` is not a pass
just because it is exact — this ledger counts whole treats and any non-integer type invites a
rounding policy we deliberately do not have.

### 2. Money movement runs inside a transaction
```bash
grep -rn "@Transactional" backend/src/main/kotlin
```
Every method that mutates a balance must be `@Transactional`. Confirm the annotation is on the method
that actually performs debit **and** credit — not on a caller that delegates the mutation elsewhere,
and not on a `private` method (Spring cannot proxy those).

### 3. Balances are read under a pessimistic write lock
```bash
grep -rn "PESSIMISTIC_WRITE\|@Lock\|FOR UPDATE" backend/src/main/kotlin
```
Every balance read that precedes a write must hold `PESSIMISTIC_WRITE`. A plain `findById` on the
read-modify-write path is a **CRITICAL** double-spend hole even when the surrounding method is
transactional — `READ COMMITTED` will happily hand two transactions the same stale balance.

### 4. Lock acquisition is deterministically ordered
Read the transfer service. Locks on the two accounts must be taken in a **total order independent of
transfer direction** — ascending id, applied identically on every path. Flag as **CRITICAL**:
- locking the sender first and the recipient second (deadlocks the moment `A→B` races `B→A`)
- `findAllById(...)` for the pair (no ordering guarantee whatsoever)
- `WHERE id IN (:a, :b) ORDER BY id ... FOR UPDATE` (correctness resting on the planner's row order)
- more than one comparator deciding "lower id" anywhere in the codebase

### 5. Idempotency is enforced by the database, not by application code
```bash
grep -rn "idempotency" backend/src/main/resources/db/migration backend/src/main/kotlin
```
Require a `UNIQUE` index on the idempotency key in a migration. A service that only does
`findByIdempotencyKey(...)` and branches on the result is **CRITICAL** — check-then-act loses the
race it exists to prevent.

### 6. The unique-violation recovery is not itself broken
This is the subtlest check and the one most often wrong. When the insert hits `23505`:
- the read-back of the winning row **must** happen in a **new transaction**, after the failed one has
  rolled back. Postgres aborts the whole transaction on any statement error; a `SELECT` issued after
  the violation on the same connection fails with `25P02`. Catching the exception and re-reading
  inside the same `@Transactional` method is **CRITICAL**.
- the catching wrapper **must** live in a different bean, or the call must otherwise cross the proxy.
  A plain `this.method()` call to another `@Transactional` method bypasses the interceptor entirely
  and silently reproduces the bug above.

### 7. Database constraints back the application checks
```bash
grep -rn "CHECK\|UNIQUE" backend/src/main/resources/db/migration
```
Require, in the migrations: non-negative balance, positive amount, sender ≠ recipient, unique
idempotency key. Application validation produces the friendly error; the constraint is what stays
true when someone writes a script at 2am. Missing constraints are **IMPORTANT** even when the
service validates correctly.

### 8. Hibernate does not own the schema
```bash
grep -rn "ddl-auto" backend/src/main/resources
```
Must be `validate`. `update` or `create-drop` against a Flyway-managed schema is **IMPORTANT** —
it lets an entity mapping silently mutate the database.

### 9. Concurrency tests can actually observe concurrency
```bash
grep -rn "@Transactional\|maximumPoolSize\|Executors\|CyclicBarrier" backend/src/test
```
Two ways a concurrency test passes while proving nothing, both **IMPORTANT**:
- `@Transactional` on the test class or method — pins one connection and rolls back at the end, so
  spawned threads cannot see the fixture or end up sharing a transaction.
- Hikari `maximumPoolSize` below the test's thread count — threads queue on the connection pool
  instead of on row locks, and the test passes whether or not the locking is correct.

## Output

A single markdown table, most severe first:

| Severity | Check | File:line | Finding |
|---|---|---|---|

Severity is `CRITICAL` (money can be lost, duplicated, or double-spent), `IMPORTANT` (a real defect
that is not yet a money bug), or `NICE TO HAVE`. Then one line per passing check, so the reader can
see what was actually verified rather than inferring it from silence.

Cite `file:line` for every finding. If a check could not be run because the code does not exist yet,
say **not yet implemented** — never report it as passing.
