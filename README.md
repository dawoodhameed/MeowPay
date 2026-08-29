# MeowPay

Monorepo for MeowPay — send treats, view the ledger.

## Layout

| Path | Stack | Purpose |
| --- | --- | --- |
| `backend/` | Kotlin 2.0 / Spring Boot 3.3 / JDK 21 | REST API, JPA against PostgreSQL |
| `frontend/` | Next.js 15 / React 19 / TypeScript | Transaction ledger / viewing |
| `mobile/` | Flutter 3.5+ | Mobile app for sending treats |
| `docker-compose.yml` | Runs the whole stack — Postgres, backend, frontend, mobile-web | Local dev |

## Run everything with Docker

```bash
docker compose up -d --build
```

| Service | URL | What it is |
| --- | --- | --- |
| `frontend` | http://localhost:3000 | Next.js ledger UI |
| `backend` | http://localhost:8080 | Spring Boot API |
| `mobile-web` | http://localhost:8081 | Flutter app compiled to web + served by nginx |
| `postgres` | localhost:5432 | Database (db/user/password all `meowpay`) |

**Checking the mobile UI:** Docker has no display, so it can't render native iOS/Android screens —
that always needs a simulator/emulator (or a real device, and for iOS specifically, a Mac with
Xcode). The `mobile-web` container instead builds the same Flutter widget tree as a **web** target
and serves it over nginx, so `http://localhost:8081` is a real, interactive rendering of the app's
UI in a browser. It's the same code as the mobile app, but exercised through Flutter's web renderer,
not the native iOS/Android runtime.

Rebuild a single service after code changes:

```bash
docker compose up -d --build backend    # or frontend / mobile-web
```

## Running services individually (no Docker)

Requires: JDK 21, Node.js 20+, Flutter SDK 3.5+.

**Database only:**

```bash
docker compose up -d postgres
```

**Backend:**

```bash
cd backend && ./gradlew bootRun
```

Serves on `http://localhost:8080`. Connection settings come from `src/main/resources/application.yml`
and can be overridden with `DATABASE_URL`, `DATABASE_USER`, `DATABASE_PASSWORD`.

**Frontend:**

```bash
cd frontend && npm install && npm run dev
```

Serves on `http://localhost:3000`; talks to the API at `NEXT_PUBLIC_API_URL` (defaults to `http://localhost:8080`).

**Mobile (native, on a simulator/emulator/device):**

```bash
cd mobile && flutter pub get && flutter run
```

Or `flutter run -d chrome` to run the web target directly without Docker.
