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
