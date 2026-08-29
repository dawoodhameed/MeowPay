---
name: api-design
description: Review MeowPay's HTTP contract — resource shape, status codes, validation, idempotency semantics, and error format — against what the Next.js and Flutter clients need. Use when adding or changing an endpoint.
---

# API Design Review

One API serves both clients. Review the contract as each of them would consume it.

## Resources and status codes

- Nouns, plural, no verbs in paths. `POST /api/transfers` creates a transfer; `POST /api/send-treats`
  is an RPC call wearing a REST costume.
- `201` with the created resource on creation. `200` on an idempotent replay — a replay did not
  create anything, and returning `201` twice for one logical transfer misreports what happened.
- **`400` versus `422` is a real distinction.** `400` means the request was malformed and the client
  has a bug. `422` means it was well-formed and the ledger refused it — insufficient funds,
  self-transfer. Clients render `422` as user-facing copy and `400` as a defect. Conflating them
  forces the client to parse messages.
- `404` for an unknown wallet. `409` for a conflict with existing state, including an idempotency key
  reused with a different payload.
- `5xx` only for genuine server faults. A refused transfer is not a server error.

## Errors

RFC 9457 `application/problem+json`, which Spring Boot 3 emits natively via `ProblemDetail`. Every
error carries a stable machine-readable `type` slug. Clients must never branch on message text —
if a client would have to string-match to behave correctly, the contract is underspecified.

Error bodies should carry what the client needs to render a useful message: an insufficient-funds
response that omits the current balance forces a second request to say anything specific.

## Validation

Every request field is validated at the boundary, and the validation is actually enforced —
a `@Valid` missing from the controller parameter makes every annotation on the DTO decorative.

```bash
grep -rn "@Valid\|@NotNull\|@Positive\|@RequestBody" backend/src/main/kotlin
```

Check the boundaries specifically: zero, negative, absent, malformed UUID, amount beyond `Long`.

## Idempotency semantics

- The key arrives in a header (`X-Idempotency-Key`), consistent across every state-changing endpoint.
- A replay returns the original response, not a fresh computation of it.
- The response distinguishes a replay from a first execution — a header the client can observe.
- The documented semantics match the implementation, including the honest edges: if a failed attempt
  releases the key for reuse, the contract must say the endpoint is idempotent for *successful*
  requests only, rather than implying more than it delivers.

## Client fit

Walk both clients' flows against the contract:

- **Flutter (sender)** — list cats, submit a transfer, show the new balance. If it needs a second
  request to display the balance after a transfer, the response is missing a field.
- **Next.js (ledger)** — list transfers with both parties resolved, newest first, paginated. If it
  must fetch each cat separately to render a row, that is an N+1 built into the contract.

Serialisation deserves one check: a `bigint` amount exceeding JavaScript's safe integer range would
need to be a string. Confirm the chosen representation is a decision with a stated bound, not an
accident.

## Report

Findings as `endpoint · problem · client impact · fix`, then the contract as it stands, so any drift
between the documented and the implemented shape is visible.
