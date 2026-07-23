---
type: Plan
title: "Wiki Update Plan — LibFEM.jl"
description: "Plan for surgical documentation updates driven by source changes between fd8cd5f9 and HEAD."
tags: ["plan", "internal"]
---

# Documentation Update Plan (Internal)

Wiki is generated under `/openwiki/`. Existing pages: `quickstart.md`, `architecture/overview.md`, `reference/kattan-mapping.md`, `index.md`, plus section `index.md` files.

## Doc Impact Map (source change -> docs affected)

| Source change | Doc impact | Edit |
|--------------|------------|------|
| `src/utils.jl`: new `_direction_cosines`/`_truss_force_component` shared helpers, `validate_positive` docstring | `architecture/overview.md` (Function Pattern / helpers) | Mention new helpers |
| `src/assembly.jl`: `_assemble!` now throws `AssemblyError` on `i == j` (v0.4 / C8 fix) | `architecture/overview.md` (Assembly Helper) | Note the guard |
| `src/plot.jl`: all 9 beam diagram functions refactored to use private `_beamdiagram` helper | `architecture/overview.md` (helpers / diagrams) | Note `_beamdiagram` helper |
| `src/types.jl`: deprecation notice for `AbstractElement` / `@kwdef` structs | `architecture/overview.md` (Module Structure) | Mark types.jl as deprecated/legacy |
| `src/beam.jl`: switched to `validate_positive` + `_direction_cosines`; added local/global frame notes | `architecture/overview.md` (3D Beam section) | Add Frame notes |
| `test/runtests.jl`: new `@test_physical_invariants` / `@test_translational_invariants` macros; ~737 tests | `architecture/overview.md` (Testing section) | Mention test macros + count |
| `Doc/Kattan/Solutions Manual/` → `Doc/Kattan/Solutions-Manual/` rename + new problem scripts | `reference/kattan-mapping.md` (Doc structure) and `quickstart.md` (Repo Map) | Update directory name to `Solutions-Manual`; reference that the directory now contains per-problem MATLAB scripts |
| `.github/workflows/ocr-review.yml` added (OCR review) | `architecture/overview.md` (GitHub Actions note) | Add OCR workflow note |

## Pages to edit

1. `openwiki/quickstart.md` — Repo Map table: fix `Doc/Kattan/Solutions Manual/` → `Doc/Kattan/Solutions-Manual/`; mention Kattan Solutions-Manual now contains Julia/MATLAB problem scripts (problem_2_1.m, ...)
2. `openwiki/architecture/overview.md` — Module Structure: note types.jl deprecation notice. Assembly Helper: note `i == j` guard. Function Pattern: add `_direction_cosines`, `_truss_force_component`, `_beamdiagram`. 3D Beam note: add Frame (local/global) docstrings. Testing: mention invariant macros + approximate test count. GitHub Actions: add `ocr-review.yml`. Known Issues trim: the ToDo_Promethus_inkling.md references are stale (file removed); mark fixes that have landed.
3. `openwiki/reference/kattan-mapping.md` — Doc/ Directory Structure: update directory name; note Julia/MATLAB problem scripts now exist in `Solutions-Manual/`.

## Pages NOT edited

- `openwiki/index.md`, `openwiki/architecture/index.md`, `openwiki/reference/index.md` — index regeneration is deterministic post-run; will leave as-is.
- OKF front matter check: all three content pages already have valid OKF front matter.

## Evidence notes

- `src/utils.jl:22-68` — three new helpers
- `src/assembly.jl:21-22` — i==j guard
- `src/types.jl:168-175` — deprecation notice
- `src/plot.jl:18-25` — `_beamdiagram` helper
- `test/runtests.jl:6-50` — physical/translational invariants macros
- `Doc/Kattan/Solutions-Manual/` — 11 .m files present (problem_2_1..7_1, ocr_m_verify)
- `scripts/pre-commit-ocr.sh` — pre-commit hook for OCR verification
