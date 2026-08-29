#!/bin/sh
# Fast pre-commit gate. Deliberately excludes the test suites — those need Docker
# and take minutes. Run /verify-slice (or CI) for the full gate.
#
# Install with: ./scripts/install-hooks.sh
# Bypass once with: git commit --no-verify

set -e

REPO_ROOT=$(git rev-parse --show-toplevel)
FAILED=""

# Gradle 8.10 does not support JDKs newer than 23, and a machine may have a newer
# one first on PATH -- or none at all. Find a JDK 21 and verify it really is 21:
# on macOS `java_home -v 21` exits 0 and falls back to whatever it has when no
# matching JDK is registered, so the exit code alone cannot be trusted.
is_jdk21() {
  [ -x "$1/bin/java" ] && "$1/bin/java" -version 2>&1 | head -1 | grep -q 'version "21\.'
}

if ! is_jdk21 "$JAVA_HOME"; then
  JAVA_HOME=""
  for candidate in \
    "$(/usr/libexec/java_home -v 21 2>/dev/null)" \
    /opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home \
    /usr/lib/jvm/temurin-21-jdk-amd64 \
    /usr/lib/jvm/java-21-openjdk-amd64
  do
    if is_jdk21 "$candidate"; then
      JAVA_HOME="$candidate"
      export JAVA_HOME
      break
    fi
  done
fi

echo "→ backend: ktlint"
if [ ! -f "$REPO_ROOT/backend/gradlew" ]; then
  echo "  skipped (no gradlew)"
elif [ -z "$JAVA_HOME" ]; then
  echo "  skipped (no JDK 21 found; set JAVA_HOME to a JDK 21 to enable)"
else
  (cd "$REPO_ROOT/backend" && ./gradlew ktlintCheck --console=plain -q) || FAILED="$FAILED backend-ktlint"
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
