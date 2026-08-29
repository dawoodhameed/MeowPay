---
name: commit-message
description: Write MeowPay commit messages — Conventional Commits with this repo's type and scope vocabulary, a body that explains why, and honest AI co-authorship. Use whenever staging or committing in this repository.
---

# Commit Messages

This repository's history is a graded artifact: it is read to understand how the solution was
reasoned about, not just what shipped. Commits should read as a narrative of decisions.

## Format

```
<type>(<scope>): <subject>

<body — why, not what>

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Type

| Type | Use for |
|---|---|
| `feat` | New user-visible capability |
| `fix` | Corrects broken behaviour |
| `test` | Adds or changes tests only |
| `refactor` | Restructuring with no behaviour change |
| `perf` | Measurable performance change |
| `chore` | Build config, dependencies, tooling |
| `docs` | Documentation only |

## Scope

Use the part of the system that changed, not the directory path:

`db` · `ledger` · `api` · `web` · `mobile` · `docker` · `tooling` · `backend`

`ledger` is reserved for the money-movement core — the transfer service, locking, idempotency.
Reach for it deliberately: a `feat(ledger)` commit is one a reviewer will read line by line.

## Subject

- Imperative mood: "add", not "added" or "adds"
- No trailing period, lower case after the colon
- Under ~70 characters
- Name the actual change: `enforce ascending lock order on transfer` beats `update service`

## Body

Include one whenever the change involves a decision, a trade-off, or a non-obvious mechanism —
which is most commits in the ledger core. Explain **why this approach**, and what the alternative
would have cost. Skip the body for genuinely mechanical changes.

For financial-correctness commits, state the invariant the change protects:

```
feat(ledger): acquire wallet locks in ascending id order

Locking sender-then-recipient deadlocks as soon as A→B races B→A: each
transaction holds the row the other needs. Sorting the two ids and always
taking the lower one first makes a wait-for cycle impossible to construct.

Postgres would detect and abort one side of the deadlock anyway, but that
surfaces as a failed transfer the user has to retry, for a hazard we can
remove entirely with a sort.

Co-Authored-By: Claude <noreply@anthropic.com>
```

## One commit, one logical change

Do not batch unrelated work. Tests land in their own commit **before** the implementation that
satisfies them, so the history shows the ledger being driven by its failure cases rather than
retrofitted with tests afterwards.

## Co-authorship

Keep the `Co-Authored-By` trailer. This exercise asks for the real AI workflow to be visible, and an
accurate history is part of that — the trailer marks where an agent contributed while the commit
message itself carries the human reasoning behind the change.

## Before committing

Run `/verify-slice`. For anything touching money movement, run `/ledger-audit` as well. Never commit
on the assumption a check would have passed.
