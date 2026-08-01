# Post-Review Work Plan — Kattan Port Series (2.1 → 16.1)

Date: 2026-08-01
Status: approved by user ("1. et 2." = fix blocker + backlog)

## Review Verdict (from /review-work, 5 lanes)

- Goal & Constraint Verification: PASS (HIGH)
- QA execution: PASS (HIGH)
- Code Quality: **FAIL (HIGH)** — blocking issue below
- Security: PASS (LOW)
- Context Mining: PASS (HIGH)

**Overall: FAILED** — one fixable blocker + backlog.

## 1. Blocker — Tolerance Hygiene (required)

Files: `examples/kattan/problem_9_1.jl`, `examples/kattan/problem_10_1.jl`

| File | Current | Target |
|---|---|---|
| 9.1 `u` asserts | `rtol=5e-2` | `≤1e-3` |
| 10.1 displacement asserts | `rtol=1e-1` | `≤1e-3` |
| 10.1 integration `atol` | `atol=1e-3` | `1e-5` |

Method: re-derive goldens from high-precision Julia solve + Octave reference
(`Doc/Kattan/Solutions-Manual/problem_9_1.m`, `problem_10_1.m`), document the
margin in a comment. Standard set by 15.1/16.1: `1e-4`/`1e-6`.

## 2. Backlog

- [ ] `README.md`: Testing section — line count (~1315 → 2181), list the 13 new
      integration testsets, fix "golden regression for 2.1–8.3" claim
      (test/golden/manifests.toml is function-level)
- [ ] `examples/README.md`: kattan/ coverage "2.1-8.3" → "2.1-16.1"
- [ ] `MEMORY.md`: reconcile conflicting test counts (741/953/1026), fix PR
      numbers, remove "awaiting commit"/"PR OPEN" for merged work
- [ ] `test/runtests.jl`: add displacement goldens to `problem_4_2` testset
      (currently only size/symmetry/finiteness/reaction)
- [ ] `test/runtests.jl`: add 13 integration testsets for Gen-1 problems
      (2.1–8.3 except 4.2) — currently only in-script `@asserts`, no CI coverage
- [ ] Verify: run full test suite green after edits

## 3. Flagged (need explicit approval / external source)

- **CI**: execute `examples/kattan/*.jl` in CI — `.github/workflows/` is
  read-only per AGENTS.md
- **Port problems 3.2 & 4.1**: exist in book manual but no `.m` source in repo —
  needs the book manual file
- **Squash duplicate 16.1 commits** (484ca68 / d7edb53 / 86b41ec): master
  history rewrite — needs explicit approval

## Context

- Review scope diff: `e36b789..HEAD` (34 files, +5697/−68)
- Branch checked out: `fix/ocr-fork-pr-skip`; local default branch `master`
- 26 examples, 26 `.m` mirrors (all present), 13 integration testsets in
  `test/runtests.jl`, 7 port-plan ADRs in `docs/adr/`
- 16.1 port itself: merged, verified (header + goldens OK)
