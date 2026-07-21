# LibFEM.jl Enhancement Plan — Executable Playbook

## Dependency DAG

```
Sprint 0 ──────────────────────────────────────┐
  ├── 0.1 assembly.jl:21 (i=j guard)          │
  ├── 0.2 test: AssemblyError regression       │
  └── VERIFY: julia test/runtests.jl           │
                                               │
Sprint 1 ──────────────────────────────────────┤
  ├── 1.1 truss.jl:73-76 (strain → scalar)    │
  ├── 1.2 beam.jl:204 (hypot guard)           │
  ├── 1.3 test: fix wrong assertion @:112      │
  ├── 1.4 test: near-vertical regression       │
  └── VERIFY: julia test/runtests.jl           │
                                               │
Sprint 2 ──────────────────────────────────────┤  ← can parallelize:
  ├── 2.1 utils.jl: add 3 helpers             │  2.1 + 2.5 (no overlap)
  ├── 2.2 truss.jl: replace 6× T·u with helper│
  ├── 2.3 truss.jl: replace L>0 with helper    │
  ├── 2.4 spring.jl: replace deg2rad+cos       │
  ├── 2.5 beam.jl: C3 also use hypot helper    │
  ├── 2.6 truss.jl: C2 validation             │
  ├── 2.7 spring.jl: C2 validation             │
  └── VERIFY: julia test/runtests.jl           │
                                               │
Sprint 3 ──────────────────────────────────────┤
  ├── 3.1 test: symmetry/PSD/rowsumzero         │
  ├── 3.2 test: negative paths (zero L, neg E)  │
  ├── 3.3 test: diagram z-vector values         │
  ├── 3.4 test: assembly edge cases             │
  └── VERIFY: julia test/runtests.jl           │
                                               │
Sprint 4 ──────────────────────────────────────┤
  ├── 4.1 docstrings: tension-positive          │
  ├── 4.2 docstrings: local/global frame C4     │
  ├── 4.3 docstrings: diagram convention C7     │
  ├── 4.4 README.md: fix A>0 claim              │
  ├── 4.5 types.jl: deprecation note            │
  └── VERIFY: julia test/runtests.jl            │
```

## Parallelization Map

| Wave | Tasks | Run Together? | Est Time |
|------|-------|---------------|----------|
| Wave 1 (S0+S1 src changes) | 0.1, 1.1, 1.2 | YES — no overlap | 5 min |
| Wave 2 (S0+S1 tests) | 0.2, 1.3, 1.4 | YES — independent tests | 5 min |
| Wave 3 (S2 helpers + C2) | 2.1, 2.5, 2.6, 2.7 | YES — 2.1 is utils, 2.5 beam, 2.6/2.7 validation | 15 min |
| Wave 4 (S2 replacements) | 2.2, 2.3, 2.4 | After 2.1 (need helpers) | 15 min |
| Wave 5 (S3 tests) | 3.1, 3.2, 3.3, 3.4 | YES — all add-only test sections | 20 min |
| Wave 6 (S4 docs) | 4.1, 4.2, 4.3, 4.4, 4.5 | YES — all independent | 10 min |

**Total wall clock**: ~50 min (vs ~2h sequential)

---

# Sprint 0 — Safety Net (C8: i=j guard)

- [x] Step 0.1 — Add i=j guard to _assemble!

**File**: `src/assembly.jl:21`
**Change**: Insert validation before the `@views` block.

```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, ndofs::Integer)
    i == j && throw(AssemblyError("Assembly requires i ≠ j, got i=j=$i"))
    @views begin
        ...
```

**Exact edit**: After `function _assemble!(..., ndofs::Integer)` line, change to:

```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, ndofs::Integer)
    i == j && throw(AssemblyError("Assembly requires i ≠ j, got i=j=$i"))
    @views begin
```

- [x] Step 0.2 — Add regression test

**File**: `test/runtests.jl`
**Insert** after `@testset "negative/zero parameter behavior"` for d3_beam (line 627), before `end  # @testset "LibFEM"` (line 629):

```julia
        @testset "assembly error paths" begin
            K = zeros(2, 2)
            k = d1_truss_elementstiffness(1, 1, 1)
            @test_throws AssemblyError d1_truss_assemble(K, k, 1, 1)

            K4 = zeros(4, 4)
            k4 = d2_truss_elementstiffness(1, 1, 1, 0)
            @test_throws AssemblyError d2_truss_assemble(K4, k4, 1, 1)

            K6 = zeros(6, 6)
            k6 = d2_beam_elementstiffness(1, 1, 1, 1, 0)
            @test_throws AssemblyError d2_beam_assemble(K6, k6, 1, 1)
        end
```

---

# Sprint 1 — Correctness Fixes (C1, C3)

- [x] Step 1.1 — Fix d1_truss_elementstrain → scalar

**File**: `src/truss.jl:73-76`

**Exact edit**: Change lines 73-76 from:
```julia
function d1_truss_elementstrain(L::Real, u::AbstractVector)
    L > 0 || throw(ElementParameterError("L", "Length L must be positive, got $L"))
    return 1 / L * [1 -1; -1 1] * u
end
```
to:
```julia
function d1_truss_elementstrain(L::Real, u::AbstractVector)
    L > 0 || throw(ElementParameterError("L", "Length L must be positive, got $L"))
    return (u[2] - u[1]) / L
end
```

- [x] Step 1.2 — Fix near-vertical beam `==` to tolerance

**File**: `src/beam.jl` — **two locations**.

Location 1 (`d3_beam_elementstiffness`, ~line 204):
Change `if x1 == x2 && y1 == y2` to `if hypot(Cx, Cy) < 1e-12`

Location 2 (`d3_beam_elementforces`, ~line 301):
Change `if x1 == x2 && y1 == y2` to `if hypot(Cx, Cy) < 1e-12`

**Rationale**: Uses already-computed direction cosines; guards against catastrophic precision loss when beam is near-vertical.

## Step 1.3 — Fix test assertion for C1

**File**: `test/runtests.jl:112`

**Change**: 
```julia
# Old (buggy: 2-vec with wrong sign)
@test eps ≈ [2.5e-4; -2.5e-4]
# New (scalar, negative = compression)
@test eps ≈ -2.5e-4
```

Also check line 114 (zero displacement test):
```julia
# Old
@test d1_truss_elementstrain(L, [0.0; 0.0]) ≈ [0.0; 0.0]
# New
@test d1_truss_elementstrain(L, [0.0; 0.0]) ≈ 0.0
```

## Step 1.4 — Add near-vertical beam regression test

**File**: `test/runtests.jl` — inside `@testset "d3_beam"`, after `@testset "vertical beam"` (after line 610):

```julia
        @testset "near-vertical beam" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            Ke = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 1e-10,1e-10,4)
            @test size(Ke) == (12, 12)
            @test all(!isnan, Ke)
            @test Ke == Ke'
            u = zeros(12); u[7] = 0.001
            f = d3_beam_elementforces(E, G, A, Iy, Iz, J, 0,0,0, 1e-10,1e-10,4, u)
            @test all(!isnan, f)
            @test length(f) == 12
        end
```

---

# Sprint 2 — UX & Shared Helpers

## Step 2.1 — Add shared helpers to utils.jl

**File**: `src/utils.jl` — append after `deg2rad` function (after line 20):

```julia
"""
    _direction_cosines(theta_deg)

Compute direction cosines from a 2D angle theta in degrees.
Returns `(C, S) = (cos, sin)`.
"""
function _direction_cosines(theta_deg::Real)
    x = deg2rad(theta_deg)
    return (cos(x), sin(x))
end

"""
    _direction_cosines(thetax_deg, thetay_deg, thetaz_deg)

Compute direction cosines from three 3D angles in degrees.
Throws `ElementParameterError` if Cx²+Cy²+Cz² deviates from 1 by >1e-12.
"""
function _direction_cosines(thetax_deg::Real, thetay_deg::Real, thetaz_deg::Real)
    x = deg2rad(thetax_deg)
    y = deg2rad(thetay_deg)
    z = deg2rad(thetaz_deg)
    Cx = cos(x)
    Cy = cos(y)
    Cz = cos(z)
    abs(Cx^2 + Cy^2 + Cz^2 - 1) > 1e-12 &&
        throw(ElementParameterError(
            "(thetax, thetay, thetaz)",
            "Direction cosines do not form a unit vector: Cx²+Cy²+Cz² = $(Cx^2+Cy^2+Cz^2) ≠ 1",
        ))
    return (Cx, Cy, Cz)
end

"""
    _truss_force_component(Cx, Cy, u) -> Real

Compute scalar projection `[-Cx -Cy Cx Cy] · u` for 2D trusses (4-element u).
"""
function _truss_force_component(Cx::Real, Cy::Real, u::AbstractVector)
    return -Cx * u[1] - Cy * u[2] + Cx * u[3] + Cy * u[4]
end

"""
    _truss_force_component(Cx, Cy, Cz, u) -> Real

Compute scalar projection `[-Cx -Cy -Cz Cx Cy Cz] · u` for 3D trusses (6-element u).
"""
function _truss_force_component(Cx::Real, Cy::Real, Cz::Real, u::AbstractVector)
    return -Cx * u[1] - Cy * u[2] - Cz * u[3] + Cx * u[4] + Cy * u[5] + Cz * u[6]
end

"""
    validate_positive(x, name)

Throw `ElementParameterError(name, ...)` if `x ≤ 0`. Returns `nothing`.
"""
function validate_positive(x::Real, name::AbstractString)
    x > 0 || throw(ElementParameterError(name, "$name must be positive, got $x"))
    return nothing
end
```

## Step 2.2 — Replace 6× T·u in truss.jl with _truss_force_component

**File**: `src/truss.jl`

**6 exact edits:**

1. `d2_truss_elementforces` (lines 163-167):
```julia
    (C, S) = _direction_cosines(theta)
    return E * A / L * _truss_force_component(C, S, u)
```

2. `d2_truss_elementstrain` (lines 185-189):
```julia
    (C, S) = _direction_cosines(theta)
    return _truss_force_component(C, S, u) / L
```

3. `d2_truss_elementstress` (lines 208-212):
```julia
    (C, S) = _direction_cosines(theta)
    return E / L * _truss_force_component(C, S, u)
```

4. `d3_truss_elementforces` (lines 315-321):
```julia
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return E * A / L * _truss_force_component(Cx, Cy, Cz, u)
```

5. `d3_truss_elementstrain` (lines 341-347):
```julia
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return _truss_force_component(Cx, Cy, Cz, u) / L
```

6. `d3_truss_elementstress` (lines 368-374):
```julia
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return E / L * _truss_force_component(Cx, Cy, Cz, u)
```

## Step 2.3 — Replace 14× L>0 guards with validate_positive

**File**: `src/truss.jl` (10 sites): Replace `L > 0 || throw(ElementParameterError("L", ...))` with `validate_positive(L, "L")`

Locations in truss.jl:
- `d1_truss_elementstiffness` line 24
- `d1_truss_elementstrain` line 74
- `d2_truss_elementstiffness` line 138
- `d2_truss_elementforces` line 162
- `d2_truss_elementstrain` line 184
- `d2_truss_elementstress` line 207
- `d3_truss_elementstiffness` line 281
- `d3_truss_elementforces` line 314
- `d3_truss_elementstrain` line 340
- `d3_truss_elementstress` line 367

**File**: `src/beam.jl` (4 sites):
- `d2_beam_elementstiffness` line 42
- `d2_beam_elementforces` line 79
- `d3_beam_elementstiffness` line 197
- `d3_beam_elementforces` line 294

## Step 2.4 — Replace deg2rad+cos in spring.jl with _direction_cosines

**File**: `src/spring.jl`

**4 edits:**

1. `d2_spring_elementstiffness` (lines 72-74): Replace `x = deg2rad(theta); C = cos(x); S = sin(x)` with:
```julia
    (C, S) = _direction_cosines(theta)
```

2. `d2_spring_elementforce` (lines 97-98): Replace `C = cos(deg2rad(theta)); S = sin(deg2rad(theta)); T = [-C -S C S]; return k * (T * u)` with:
```julia
    (C, S) = _direction_cosines(theta)
    return k * _truss_force_component(C, S, u)
```

3. `d3_spring_elementstiffness` (lines 141-146): Replace `x = deg2rad(thetax); u = deg2rad(thetay); v = deg2rad(thetaz); Cx = cos(x); Cy = cos(u); Cz = cos(v)` with:
```julia
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
```

4. `d3_spring_elementforce` (lines 171-176): Replace the deg2rad/cos block + `T = [...]` + return with:
```julia
    (Cx, Cy, Cz) = _direction_cosines(thetax, thetay, thetaz)
    return k * _truss_force_component(Cx, Cy, Cz, u)
```

## Step 2.5 — Replace 8× diagram functions with _beamdiagram helper

**File**: `src/plot.jl`

Add helper near top (after header, before d2_beam_elementaxialdiagram):
```julia
function _beamdiagram(f::AbstractVector, L::Real, title_::AbstractString, z_fn::Function)
    x = [0, L]
    z = z_fn(f, L)
    p = plot(x, z, title=title_)
    plot!(p, x, [0, 0], color=:black)
    return p
end
```

Replace each of 8 diagram functions:
```julia
d2_beam_elementaxialdiagram(f, L)   = _beamdiagram(f, L, "Axial Force Diagram",     (f,L)->[-f[1], f[4]])
d2_beam_elementsheardiagram(f, L)   = _beamdiagram(f, L, "Shear Force Diagram",      (f,L)->[f[2], -f[5]])
d2_beam_elementmomentdiagram(f, L)  = _beamdiagram(f, L, "Bending Moment Diagram",   (f,L)->[-f[3], f[6]])
d3_beam_elementaxialdiagram(f, L)   = _beamdiagram(f, L, "Axial Force Diagram",     (f,L)->[-f[1], f[7]])
d3_beam_elementshearydiagram(f, L)  = _beamdiagram(f, L, "Shear Force Y Diagram",   (f,L)->[f[2], -f[8]])
d3_beam_elementshearzdiagram(f, L)  = _beamdiagram(f, L, "Shear Force Z Diagram",   (f,L)->[f[3], -f[9]])
d3_beam_elementmomentydiagram(f, L) = _beamdiagram(f, L, "Bending Moment Y Diagram",(f,L)->[f[5], -f[11]])
d3_beam_elementmomentzdiagram(f, L) = _beamdiagram(f, L, "Bending Moment Z Diagram",(f,L)->[f[6], -f[12]])
d3_beam_elementtorsiondiagram(f, L) = _beamdiagram(f, L, "Torsion Diagram",         (f,L)->[f[4], -f[10]])
```

---

# Sprint 3 — Test Infrastructure

## Step 3.1 — Symmetry/row-sum-zero/PSD property tests

**File**: `test/runtests.jl` — add after `@testset "negative/zero parameter behavior"` for d3_beam (line 627), BEFORE the assembly error paths test:

```julia
    @testset "element property tests" begin
        k1 = d1_truss_elementstiffness(1, 1, 1)
        @test k1 == k1'
        @test all(k1 * ones(2) .≈ 0.0 atol=1e-15)

        k2 = d2_truss_elementstiffness(1, 1, 1, 30)
        @test k2 == k2'
        @test all(k2 * ones(4) .≈ 0.0 atol=1e-14)

        k3 = d3_truss_elementstiffness(1, 1, 1, 30, 45, 60)
        @test k3 == k3'
        @test all(k3 * ones(6) .≈ 0.0 atol=1e-14)

        k2s = d2_spring_elementstiffness(100, 30)
        @test k2s == k2s'
        @test all(k2s * ones(4) .≈ 0.0 atol=1e-14)

        k3s = d3_spring_elementstiffness(100, 30, 45, 60)
        @test k3s == k3s'
        @test all(k3s * ones(6) .≈ 0.0 atol=1e-14)

        k2b = d2_beam_elementstiffness(1, 1, 1, 1, 30)
        @test k2b == k2b'
        @test all(k2b * ones(6) .≈ 0.0 atol=1e-13)

        k3b = d3_beam_elementstiffness(1, 1, 1, 1, 1, 1, 0,0,0, 4,0,0)
        @test k3b == k3b'
        @test all(k3b * ones(12) .≈ 0.0 atol=1e-12)
    end
```

## Step 3.2 — Negative path tests

```julia
    @testset "negative path tests" begin
        @test_throws ElementParameterError d1_truss_elementstiffness(1, 1, 0)
        @test_throws ElementParameterError d2_truss_elementstiffness(1, 1, 0, 0)
        @test_throws ElementParameterError d3_truss_elementstiffness(1, 1, 0, 0, 0, 0)
        @test_throws ElementParameterError d2_beam_elementstiffness(1, 1, 1, 0, 0)
        @test_throws ElementParameterError d1_truss_elementstiffness(1, 1, -1)
        # C2: impossible 3D direction cosines
        @test_throws ElementParameterError d3_truss_elementstiffness(1, 1, 1, 90, 90, 90)
        @test_throws ElementParameterError d3_spring_elementstiffness(100, 90, 90, 90)
    end
```

## Step 3.3 — Diagram z-vector value tests

```julia
    @testset "diagram z-vector values" begin
        f2 = [1000, 500, 200, -1000, 500, -200]
        f3 = [1000, 500, 300, 200, 150, 100, -1000, -500, -300, -200, -150, -100]
        L = 5.0
        # Verify via MATLAB reference data functions from comparison.jl
        @test LibFEM.PlaneFrameElementAxialDiagram(f2, L) == [-1000, -1000]
        @test LibFEM.PlaneFrameElementShearDiagram(f2, L) == [500, -500]
        @test LibFEM.PlaneFrameElementMomentDiagram(f2, L) == [-200, -200]
        @test LibFEM.SpaceFrameElementAxialDiagram(f3, L) == [-1000, -1000]
        @test LibFEM.SpaceFrameElementShearYDiagram(f3, L) == [500, 500]
        @test LibFEM.SpaceFrameElementShearZDiagram(f3, L) == [300, 300]
        @test LibFEM.SpaceFrameElementMomentYDiagram(f3, L) == [150, 150]
        @test LibFEM.SpaceFrameElementMomentZDiagram(f3, L) == [100, 100]
        @test LibFEM.SpaceFrameElementTorsionDiagram(f3, L) == [200, 200]
    end
```

## Step 3.4 — Assembly edge-case + cross-identity tests

```julia
    @testset "assembly edge cases" begin
        K6 = zeros(6, 6)
        k = d2_truss_elementstiffness(1, 1, 1, 0)
        K6 = d2_truss_assemble(K6, k, 1, 3)
        @test K6[1:2, 1:2] == k[1:2, 1:2]
        @test K6[1:2, 5:6] == k[1:2, 3:4]
        @test K6[5:6, 1:2] == k[3:4, 1:2]
        @test K6[5:6, 5:6] == k[3:4, 3:4]

        # d1_spring/d1_truss identity
        @test d1_spring_elementstiffness(500) == d1_truss_elementstiffness(500, 1, 1)
        # 2D identity: spring(k=EA/L) = truss(E, A, L)
        @test d2_spring_elementstiffness(100, 30) ≈ d2_truss_elementstiffness(100, 1, 1, 30)
        # 3D identity
        @test d3_spring_elementstiffness(100, 30, 45, 60) ≈ d3_truss_elementstiffness(100, 1, 1, 30, 45, 60)
    end
```

---

# Sprint 4 — Visibility (Docs)

## Step 4.1 — "Positive = tension" docstrings

Append to Returns section of:
- `src/truss.jl`: all force/stress/strain functions (9 functions)
- `src/beam.jl`: `d2_beam_elementforces`, `d3_beam_elementforces`
- `src/spring.jl`: all `elementforce` functions

Add ` (positive = tension)` to Returns lines.

## Step 4.2 — Local/global frame notes (C4)

Append to `src/beam.jl` docstrings for:
- `d2_beam_elementstiffness`: add `# Frame\nStiffness in **global** coordinates via rotation transform.`
- `d2_beam_elementforces`: add `# Frame\nForces in **local** coordinate system (kprime * T * u).`
- `d3_beam_elementstiffness`: add `# Frame\nStiffness in **global** coordinates via R' * kprime * R.`
- `d3_beam_elementforces`: add `# Frame\nForces in **local** coordinate system (kprime * R * u).`

## Step 4.3 — Diagram sign convention (C7)

Append to `src/plot.jl`: add a module-level docstring or each diagram function:
```
# Sign convention follows Kattan: axial positive = tension,
# shear positive = clockwise on left face, moment positive = sagging.
# Positive values plotted above beam axis.
```

## Step 4.4 — Fix README A>0 claim (H8)

**File**: `README.md:162`

Change:
`- **Validation**: Most stiffness/length functions validate positive inputs (\`L > 0\`, \`A > 0\`)`  
to:  
`- **Validation**: Most stiffness/length functions validate positive inputs (\`L > 0\`). Note: \`A ≤ 0\` is intentionally allowed for parametric studies (negative area produces negated matrices).`

## Step 4.5 — Deprecation note on types.jl

**File**: `src/types.jl` — append after last type definition:

```julia
# ═══════════════════════════════════════════════════════════
# Deprecation Notice (2026-07)
# ═══════════════════════════════════════════════════════════
# The abstract type hierarchy and @kwdef structs in this file
# are retained for backward compatibility but are NOT used by
# any element function. All functions operate on plain
# Real/AbstractMatrix/AbstractVector parameters.
# These types may be removed in LibFEM 2.0.
```

---

# Commit Strategy

| # | Message | Files |
|---|---------|-------|
| 1 | `fix: reject i=j in _assemble! (C8)` | `src/assembly.jl`, `test/runtests.jl` |
| 2 | `fix: d1_truss_elementstrain scalar (C1), near-vertical beam hypot (C3)` | `src/truss.jl`, `src/beam.jl`, `test/runtests.jl` |
| 3 | `refactor: extract shared helpers, C2 angle validation, beam diagram helper` | `src/utils.jl`, `src/truss.jl`, `src/spring.jl`, `src/beam.jl`, `src/plot.jl` |
| 4 | `test: property tests, negative paths, diagram values, assembly edge cases` | `test/runtests.jl` |
| 5 | `docs: tension sign, frame notes, diagram convention, README fix, deprecation` | `src/truss.jl`, `src/beam.jl`, `src/spring.jl`, `src/plot.jl`, `src/types.jl`, `README.md` |

Each commit must pass `julia --project=. test/runtests.jl`.

---

# Verification Gates

After full implementation, run:
```
# All unit tests
julia --project=. test/runtests.jl

# Octave MATLAB comparison (if Octave >= 8 available)
julia --project=. scripts/validate_matlab.jl all

# Module loads without error
julia --project=. -e 'using LibFEM; println("OK")'

# C1: strain scalar negative
julia --project=. -e 'using LibFEM; @assert d1_truss_elementstrain(4.0, [0.001,0.0]) ≈ -2.5e-4; println("C1 OK")'

# C3: near-vertical has no NaN
julia --project=. -e '
using LibFEM; E,G,A,Iy,Iz,J=3e10,1.15e8,0.01,1e-4,2e-4,1e-5
k = d3_beam_elementstiffness(E,G,A,Iy,Iz,J,0,0,0,1e-12,1e-12,4)
@assert all(!isnan, k); println("C3 OK")'

# C2: impossible angles rejected
julia --project=. -e '
using LibFEM
try d3_truss_elementstiffness(1,1,1,90,90,90); error("SHOULD HAVE THROWN")
catch e; @assert e isa ElementParameterError; println("C2 OK") end'

# C8: i=j rejected
julia --project=. -e '
using LibFEM; K=zeros(2,2); k=d1_truss_elementstiffness(1,1,1)
try d1_truss_assemble(K,k,1,1); error("SHOULD HAVE THROWN")
catch e; @assert e isa AssemblyError; println("C8 OK") end'
```
