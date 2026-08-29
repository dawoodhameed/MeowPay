# MeowPay Engineering Rules

## Stack Architecture
- Backend: Kotlin + Spring Boot 3 + Spring Data JPA
- Database: PostgreSQL + Flyway migrations
- Frontend (Web): Next.js (App Router) + React + Tailwind CSS
- Mobile: Flutter (Dart)
- Orchestration: Docker Compose

## Financial & Core Constraints
- Transfers must be strictly atomic (`@Transactional`).
- Monetary amounts must be integer values (Treats = BIGINT). Never use floating point.
- Balance cannot go below zero (`CHECK (balance >= 0)`).
- Concurrency control: Use PostgreSQL row-level pessimistic write locks (`SELECT FOR UPDATE`) on wallet/cat rows. Lock accounts in deterministic order (e.g., lower UUID first) to prevent deadlocks.
- Idempotency: Enforce at DB level (`idempotency_key UNIQUE`). Application must catch constraint violations and return original transfer payload.

## AI Execution & Code Style
- Read existing files before modifying.
- Propose an architectural plan before generating code.
- Implement incrementally; write clean, idiomatic Kotlin and Dart code.
- Never write mocks for business concurrency—test against real PostgreSQL via Testcontainers/Docker.

## Development Workflow
- **Never commit to `main`.** Every change lands via a pull request — see `/open-pr`.
- Branch naming: `<type>/<kebab-topic>` (`feat`, `fix`, `test`, `refactor`, `chore`, `docs`).
- Before opening a PR, run `/review-gate`. Fix everything under *Must fix* first.
- Commit messages follow `/commit-message`. The pre-commit hook (`scripts/install-hooks.sh`) runs
  ktlint, ESLint, tsc and `flutter analyze` — do not bypass it with `--no-verify`.
- Never report a check as passing without having run it and seen the output.

## Repository Tooling
Skills (`/name`): `verify-slice`, `ledger-audit`, `review-gate`, `open-pr`, `commit-message`,
`database-review`, `api-design`.

Review agents: `code-reviewer`, `fintech-reviewer`, `security-reviewer`, `test-engineer`,
`architecture-reviewer`. All are read-only and report rather than edit.
