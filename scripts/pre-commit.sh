#!/bin/sh
# Fast pre-commit gate. Deliberately excludes the test suites — those need Docker
# and take minutes. Run /verify-slice (or CI) for the full gate.
#
# Install with: ./scripts/install-hooks.sh
# Bypass once with: git commit --no-verify

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
FAILED=""

echo "→ backend: ktlint"
if [ -f "$REPO_ROOT/backend/gradlew" ]; then
  (cd "$REPO_ROOT/backend" && ./gradlew ktlintCheck --console=plain -q) || FAILED="$FAILED backend-ktlint"
else
  echo "  skipped (no gradlew)"
fi

echo "→ frontend: eslint + tsc"
if [ -d "$REPO_ROOT/frontend/node_modules" ]; then
  (cd "$REPO_ROOT/frontend" && npm run --silent lint && npm run --silent typecheck) || FAILED="$FAILED frontend"
else
  echo "  skipped (run npm install first)"
fi

echo "→ mobile: flutter analyze"
if command -v flutter >/dev/null 2>&1; then
  (cd "$REPO_ROOT/mobile" && flutter analyze) || FAILED="$FAILED mobile-analyze"
else
  echo "  skipped (flutter not on PATH)"
fi

if [ -n "$FAILED" ]; then
  echo
  echo "pre-commit failed:$FAILED"
  echo "fix the above, or bypass deliberately with: git commit --no-verify"
  exit 1
fi

echo "pre-commit checks passed"
