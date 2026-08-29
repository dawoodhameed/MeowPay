---
name: open-pr
description: Branch, commit, push, and open a pull request against main for MeowPay. Use whenever a phase or feature is ready — this repository does not commit to main directly.
---

# Open a Pull Request

`main` is never committed to directly. Every change lands through a reviewable PR, so the history
shows work being proposed and checked rather than pushed.

## Branch naming

```
<type>/<kebab-topic>
```

Types match the commit vocabulary in `/commit-message`: `feat`, `fix`, `test`, `refactor`, `chore`,
`docs`. Name the change, not the phase — `feat/transfer-service` reads correctly in six months,
`feat/phase-4` does not.

## Sequence

**1. Branch from an up-to-date main.**
```bash
git checkout main && git pull --ff-only origin main
git checkout -b feat/<topic>
```

**2. Do the work, then gate it.** Run `/review-gate`. Fix anything under *Must fix* before going on —
opening a PR you already know is broken wastes the reviewer's first pass.

**3. Commit** following `/commit-message`. The pre-commit hook runs ktlint, ESLint, tsc and
`flutter analyze`; do not bypass it with `--no-verify` unless the hook itself is what is broken.

**4. Push and open the PR.**
```bash
git push -u origin feat/<topic>
gh pr create --base main --title "<type>(<scope>): <subject>" --body-file <(...)
```

If `gh` is not authenticated, push the branch and hand the user the compare URL instead:
`https://github.com/dawoodhameed/MeowPay/compare/main...<branch>?expand=1`

## PR body

```markdown
## What

One paragraph. The change, in terms of behaviour rather than files touched.

## Why this approach

The decision and its alternative. For anything on the money path, state the invariant the change
protects and how it is enforced.

## Verification

What was actually run, with real results — test counts, migration output, constraint checks.
Not "tests pass": *which* tests, and what they prove.

## Review gate

Findings from /review-gate, or a note that it came back clean.

## Deliberately not done

Scope decisions a reviewer would otherwise flag as omissions.
```

Never claim a check passed without having run it in this session. If something could not be verified,
say so under **Verification** — an honest gap is recoverable, a false green is not.

## After opening

Report the PR URL to the user. Do not merge; merging is the user's call.
