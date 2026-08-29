---
name: verify-slice
description: Build, lint, and test all three MeowPay targets (Kotlin backend, Next.js web, Flutter mobile) plus the compose file, and report a pass/fail table with real command output. Use before every commit and before opening a PR.
---

# Verify Slice

Runs the full monorepo gate. Every command's real output is evidence — **never report a status you
did not observe**. If a command cannot run (missing toolchain, missing dependency), that is
`BLOCKED`, not `PASS`.

Run all four groups even if an early one fails; a single report of everything broken is more useful
than stopping at the first error.

## 1. Backend — Kotlin / Spring Boot

```bash
cd backend && ./gradlew ktlintCheck test --console=plain
```

Integration tests start a real PostgreSQL container via Testcontainers, so Docker must be running.
If startup fails with a Docker connection error, report `BLOCKED — Docker daemon not running`
rather than a test failure.

The concurrency tests are the point of this suite. If they are skipped, disabled, or absent, say so
explicitly in the report — a green backend line that omits them is misleading.

## 2. Web — Next.js

```bash
cd frontend && npm run lint && npm run typecheck && npm run build
```

`typecheck` is `tsc --noEmit` and catches what the build's incremental type pass can miss.

## 3. Mobile — Flutter

```bash
cd mobile && flutter analyze && flutter test
```

`flutter analyze` must be clean, not merely free of errors — warnings count as a fail here, because
the analyzer's warnings in Dart are usually real defects (unused imports, dead null-aware operators).

## 4. Orchestration

```bash
docker compose config --quiet && echo "compose config valid"
```

Validates the compose file parses and every referenced build context exists. This catches a renamed
directory or a broken `depends_on` before it wastes a full image build.

## Output

```
| Target      | Command              | Result | Notes |
|-------------|----------------------|--------|-------|
| backend     | ktlintCheck test     | PASS   | 14 tests, 0 failures |
| web         | lint typecheck build | FAIL   | 2 type errors in app/page.tsx |
| mobile      | analyze test         | PASS   | 3 tests |
| compose     | config               | PASS   | |
```

Follow the table with the actual failing output for anything that is not `PASS`, trimmed to the
relevant lines. Close with a one-line verdict: **safe to commit** or **do not commit**.
