#!/bin/sh
# Git hooks are not cloned with a repository, so each developer installs them once.
set -e
REPO_ROOT=$(git rev-parse --show-toplevel)
ln -sf ../../scripts/pre-commit.sh "$REPO_ROOT/.git/hooks/pre-commit"
echo "installed: .git/hooks/pre-commit → scripts/pre-commit.sh"
