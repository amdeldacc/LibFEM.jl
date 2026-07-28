# LibFEM.jl — Enhancement Roadmap

**Generated:** 2026-07-26  
**Method:** Adversarial multi-agent hyperplan (4 critics — Pragmatist, Thorough Inspector, Architect, Visionary)  
**Input:** Code reviews `docs/2026-07-25_code_review.md` + `docs/2026-07-26-code-review.md`

---

## Resolution Tracker — Review Findings Status

| # | Finding | Review | Priority | Status | Notes |
|---|---------|--------|----------|--------|-------|
| R1 | `validate_positive(A)` vs README conflict | 2026-07-25 🔴 | Critical | ✅ **Fixed** | README now says `A > 0`; code validates `A > 0`; CONTEXT.md documents the decision |
| R2 | 3D direction cosines normalize or throw | 2026-07-25 🔴 | Critical | ✅ Fixed in PR#110 | Normalized in `_direction_cosines` |
| R3 | Duplicated `_spaceframe_transform` | 2026-07-25 🟡 | Medium | ✅ Fixed | Extracted to helper |
| R4 | Unused type hierarchy | 2026-07-25 🟡 | Medium | 🟡 Open | Deprecation notice exists; no action taken |
| R5 | Plots.jl hard dependency | 2026-07-25 🟡 | Medium | ✅ Fixed | Julia extension in `ext/LibFEMPlotsExt.jl` |
| R6 | Vertical 3D beam edge case untested | 2026-07-25 🟡 | Medium | 🔴 **Still open** | No test for vertical beam branch |
| R7 | No `@inline` on hot helpers | 2026-07-25 🟢 | Low | ✅ Fixed | `@inline` added to `_direction_cosines`, `validate_positive`, `_truss_force_component` |
| R8 | Type instability / `eltype` | 2026-07-25 🟢 | Low | 🔴 **Still open** | All functions return `Matrix{Float64}` regardless of input type |
| R9 | Coincident node edge case | 2026-07-25 🟢 | Low | ✅ Fixed | `validate_positive(L)` in length functions |
| R10 | No property-based tests | 2026-07-25 🟢 | Low | ✅ Fixed | PropCheck.jl tests in `test/property_tests.jl` |
| R11 | Duplicate quadratic bar exports | 2026-07-26 ⚠️ | Major | ✅ Fixed (current tree) | No duplicate exports found in current `src/LibFEM.jl` |
| R12 | Invalid 3D angle triples in property tests | 2026-07-26 ⚠️ | Minor | ✅ Fixed (current tree) | `_rand_3d_angles()` generates physically valid direction cosines |

---

## 🔴 QUICK WINS — High-ROI, <30 minutes each

| # | Task | File(s) | Effort | Impact |
|---|------|---------|--------|--------|
| ~~1~~ | ~~Remove dead `src/plot.jl` + update refs~~ | `src/plot.jl`, `README.md`, `src/beam.jl` | ✅ **Done** | Housekeeping |
| ~~2~~ | ~~Fix README A > 0 validation doc~~ | `README.md` | ✅ **Done** | Already correct |
| ~~3~~ | ~~Update CONTEXT.md + benchmark.jl~~ | `CONTEXT.md`, `test/benchmark.jl` | ✅ **Done** | Documentation accuracy |
| 4 | Vertical 3D beam test | `test/runtests.jl` | 15 min | Covers untested branch in `beam.jl` |
| 5 | `@test_logs` for warning-emitting edge cases | `test/runtests.jl` | 20 min | Asserts warnings fire for coincident nodes, invalid cosines |
| 6 | Remove `CONTEXT.md` note about spring-truss conceptual leak | `CONTEXT.md` | 5 min | Minor cleanup |

---

## 🟡 SHORT-TERM — This Sprint

### S1. Validate `A` in Remaining Element Functions
**Files:** `src/truss.jl`, `src/beam.jl`, `src/quadraticbar.jl`  
**Why:** `validate_positive(A)` exists in most functions but audit may reveal gaps  
**Effort:** 30 min  
**Dependencies:** None

### S2. Add Missing `d1_quadraticbar_elementlength`
**Files:** `src/quadraticbar.jl`  
**Why:** Currently no dedicated length function; `d1_truss_elementlength` used instead  
**Effort:** 15 min  
**Dependencies:** None

### S3. Functional Type Hierarchy with Traits
**Files:** `src/types.jl` (+ new `src/traits.jl`)  
**What:** Make `AbstractElement{NDIM}` dispatchable with traits like `ndofs(::Type{T})`, `eltype(::Type{T})`, `element_family(::Type{T})` instead of relying on docstring conventions  
**Effort:** 2-3 days  
**Impact:** Enables generic solvers, generic assembly, generic tests  
**Risks:** Breaking change if user code dispatches on concrete structs

### S4. `eltype` Propagation
**Files:** All `src/*.jl` element files  
**What:** `d1_spring_elementstiffness(k::T)` currently returns `Matrix{Float64}` even when `k` is `Float32` or `BigFloat`. Use `similar` or `promote_type` to propagate input type.  
**Effort:** 1-2 days  
**Impact:** Type stability, interop with measurement/autodiff  
**Risks:** Golden regression snapshots store `Float64` — need regeneration on `Float64` path

### S5. Clean up Stale Docs References
**Files:** `CLAUDE.md`, `AGENTS.md`, `openwiki/`, planning docs  
**What:** Audit for remaining `src/plot.jl` references, old element counts, stale dependency info  
**Effort:** 30 min  
**Dependencies:** None

---

## 🟠 MEDIUM-TERM — Next Sprint

### M1. StaticArrays Migration
**Files:** All element files + `src/assembly.jl`  
**What:** All fixed-size matrices (2×2, 3×3, 4×4, 6×6, 12×12) return `SMatrix` instead of `Matrix`  
**Effort:** 3-4 days  
**Impact:** ~10-50× faster for small matrices, allocation-free  
**Risks:** API change — users indexing into `SMatrix` get `StaticArrays` return types; benchmarks shift dramatically

### M2. Trait-Based Element Interface
**Files:** New `src/interface.jl`  
**What:** Functions like `element_type(::typeof(d1_spring_elementstiffness)) → Spring1D`, `ndofs_per_node(Spring1D) → 1` — enables generic `solve`, `recover`, `visualize`  
**Effort:** 3-5 days  
**Impact:** Extensibility without base class coupling  
**Risks:** Over-engineering for an educational library

### M3. Solver / BC Abstraction Layer
**Files:** New `src/solver.jl`  
**What:** Replace manual `K[3:4, 3:4] \ F[3:4]` with `solve(K, constraints, loads)` that handles partitioning internally  
**Effort:** 4-5 days  
**Impact:** Eliminates boilerplate in problem scripts  
**Dependencies:** S3 (type hierarchy) for generic implementation

### M4. Benchmark Expansion
**Files:** `test/benchmark.jl`  
**What:** Add assembly and sparse-solve benchmarks for quadratic bar and remaining element types  
**Effort:** 1 day  
**Dependencies:** None

---

## 🔵 LONG-TERM — v2.0 Planning

### L1. StaticArrays + eltype Combined Release
**Why:** Both touch the same return-type contracts. Should be released together as a breaking change → v2.0.

### L2. Remove Deprecated Type Hierarchy (or Make It Dispatchable)
**Files:** `src/types.jl`  
**Decision needed:** Either remove `AbstractElement{NDIM}` and friends, or refactor functions to actually dispatch on them

### L3. Pluto.jl Interactive FEM Lab
**What:** Curated Pluto.jl reactive notebooks — live sliders for stiffness, deformed shape, stress plots
- `notebooks/01_springs.jl` — 1D spring systems, assembly visualization
- `notebooks/02_trusses.jl` — 2D truss bridge, load → deform
- `notebooks/03_beams.jl` — 2D beam bending, shear/moment diagrams
- `notebooks/04_convergence.jl` — linear vs quadratic bar elements
- `notebooks/05_spaceframe.jl` — 3D frame, rotate & inspect

**Effort:** ~2 weeks  
**Impact:** **Transformative** for educational mission

### L4. `@fem` DSL Macro
**Files:** New `src/dsl.jl`  
**What:** Declarative FEM problem definition:
```julia
@fem truss_bridge begin
    material E = 210e9
    node 1 = (0, 0)
    node 2 = (4, 0)
    node 3 = (2, 3)
    truss(1→2, A=0.01)
    fix 1 = (0, 0)
    load 3 = (0, -10000)
end
```
**Effort:** ~1 week  
**Why:** `@macroexpand` reveals the expanded LibFEM calls — teaches API while enabling rapid prototyping

### L5. `@explain` Equation Trace
**Files:** New `src/explain.jl` (+ optional `Latexify.jl` weak dep)  
**What:** Every element function prints symbolic formula with values substituted:
```julia
julia> @explain d1_truss_elementstiffness(210e9, 0.01, 5.0)
┃  K = (E·A / L) · [1 -1; -1 1]
┃    = (2.1e11 · 0.01 / 5.0) · [1 -1; -1 1]
┃    = 4.2e8 · [1 -1; -1 1]
```
**Effort:** ~3 days  
**Impact:** Bridges textbook equation ↔ code

### L6. WebGL Deformed Shape Viewer
**Files:** New `src/export.jl`  
**What:** `export_html_scene(K, u, nodes, elements, filename)` → self-contained HTML with Three.js for interactive 3D viewing (deformation scale slider, color map, orbit controls)  
**Effort:** ~4 days  
**Dependencies:** `JSON` stdlib only

### L7. FEM Puzzle Game (Pluto-Based)
**What:** Gamified FEM challenges — design a spring system with target displacement, find lightest truss, convergence puzzles  
**Effort:** ~2 weeks  
**Risk:** Content work > code work; may feel gimmicky

---

## 🎯 RECOMMENDED EXECUTION ORDER

```
Week 1     Week 2-3          Week 4-6              v2.0
┌─────────┐ ┌──────────────┐ ┌──────────────────┐ ┌──────────┐
│ Quick    │ │ Type traits  │ │ StaticArrays     │ │ Pluto    │
│ Wins     │ │ + eltype     │ │ + Trait interface│ │ Lab      │
│ (S1-S5)  │ │ propagation  │ │ + Solver layer   │ │ + DSL    │
│          │ │              │ │                  │ │ + Viewer │
└─────────┘ └──────────────┘ └──────────────────┘ └──────────┘
     🔴            🟡                 🟠                🔵
```

**Legend:** 🔴 Current → 🟡 Short → 🟠 Medium → 🔵 Long

---

*Generated by Atlas (OhMyOpenAGent) via adversarial hyperplan with 4 critics: Pragmatist (unspecified-low), Thorough Inspector (unspecified-high), Architect (ultrabrain), Visionary (artistry).*
