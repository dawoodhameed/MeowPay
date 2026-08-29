---
name: review-gate
description: Run the full MeowPay review pipeline — verify, then code, fintech, security, test, and architecture review — and consolidate every finding into one ranked report. Use before opening a PR and before submission.
---

# Review Gate

The repeatable pre-PR process. Mechanical checks first, then five specialist reviewers, then one
consolidated report. The point is that "done" means *this pipeline came back clean*, not that the
feature appeared to work.

## 1. Mechanical gate

Run `/verify-slice`. **If it fails, stop and report.** There is no value in five agents reasoning
about code that does not compile or whose tests are red — fix that first.

For any change touching money movement, also run `/ledger-audit`. It is a fast deterministic scan and
it catches the mechanical version of what `fintech-reviewer` reasons about; a finding here is almost
always real.

## 2. Specialist review

Launch these as subagents. They are independent — run them **in parallel, in a single message** —
and each reviews `git diff main...HEAD` unless told otherwise.

| Agent | Question it answers |
|---|---|
| `code-reviewer` | Is it correct, and does it fail safely? |
| `fintech-reviewer` | Can money be lost, duplicated, or double-spent? |
| `security-reviewer` | What input is trusted that should not be? |
| `test-engineer` | What breaks in production that no test would catch? |
| `architecture-reviewer` | Is this the right size — neither under- nor over-built? |

Scale the set to the diff. A frontend-only change does not need `fintech-reviewer`; a migration does
not need `code-reviewer`. Say which you skipped and why — silently dropping a reviewer is how a
pipeline becomes theatre.

## 3. Consolidate

The agents will overlap and will occasionally contradict each other. Do not paste five reports.
Produce one:

- **Merge duplicates.** The same defect found by three reviewers is one finding with three
  corroborations, and that corroboration raises confidence — say so.
- **Resolve conflicts yourself.** When `architecture-reviewer` calls something over-built and
  `test-engineer` wants more of it, read the code and take a position. Report the disagreement and
  your call, not the raw conflict.
- **Re-rank globally.** Each agent ranks within its own scope; severity only means something across
  the whole set. A CRITICAL from one reviewer may be a MINOR once you see the wider context.
- **Drop what does not survive.** A finding you cannot reproduce by reading the code is a hunch.
  Say how many you dropped so the filtering is visible.

## Output

```
## Review Gate — <branch>

Verify: PASS | FAIL (details)
Reviewers run: code, fintech, security, test, architecture   (skipped: none)

### Must fix before merge
### Should fix
### Considered and accepted
### Dropped on verification (n)

Verdict: ready to open PR | changes required
```

Every finding keeps `file:line` and the concrete failure it causes. A clean run is a legitimate
result — report it as clean rather than inventing something to justify the process.
