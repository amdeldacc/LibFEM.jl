# Architecture Review — LibFEM.jl

**Date:** 2026-07-28
**Method:** `/improve-codebase-architecture` scan
**Codebase scope:** `src/` (types.jl, assembly.jl, utils.jl, truss.jl, spring.jl, beam.jl, quadraticbar.jl, solver.jl, LibFEM.jl)
**Inputs:** CONTEXT.md, docs/adr/, all source files, recent git history

---

## Legend

| Term | Meaning |
|------|---------|
| **module** | A file or coherent group of functions |
| **interface** | The public surface area of a module |
| **depth** | (interface complexity) / (implementation complexity) — deeper = less interface for more implementation |
| **shallow** | Interface nearly as wide as implementation |
| **seam** | A place where you can swap implementation without changing callers |
| **adapter** | A module on one side of a seam |
| **leverage** | Effort invested in one place that pays off at N call sites |
| **locality** | The degree to which understanding one concept lives in one place |

---

## Candidate 1: Remove the unused type hierarchy

**Recommendation strength:** ✦ **Strong** (emerald)
**Category:** in-process

**Files:** `src/types.jl`, `src/LibFEM.jl` (include + 15 export lines), `CONTEXT.md`

### Problem

`types.jl` exports 15 symbols:
- 4 abstract types (`AbstractElement{NDIM}`, `AbstractSpring{NDIM}`, `AbstractTruss{NDIM}`, `AbstractBeam{NDIM}`)
- 3 concrete `@kwdef` structs (`Spring{NDIM}`, `Truss{NDIM}`, `Beam{NDIM}`)
- 8 type aliases (`Spring1D` … `Beam3D`)
- 6 `Base.show` methods

No function in the codebase dispatches on any of these types. `CONTEXT.md` (2026-07) explicitly confirms:

> "The abstract type hierarchy … and @kwdef concrete structs … are **documentation-only scaffolding**. They are NOT used by any element function, and there are no active plans to refactor functions to dispatch on them."

**The module is perfectly shallow.** Its interface (15 exported names + 167 lines of documentation) is nearly as wide as its implementation. The deletion test: deleting `types.jl` concentrates zero complexity elsewhere — the only changes are removing the `include("types.jl")` and the 15 `export` lines in `LibFEM.jl`.

### Before / After

**Before:** A reader sees `AbstractElement{NDIM}`, constructs a mental model of OO dispatch, then finds that no function uses it. Cognitive waste.

**After:** No type hierarchy. The `d{N}_{domain}_{operation}` naming convention is the system of record — which it already is. The language of the code matches the language of the code.

### Solution

1. Delete `src/types.jl`
2. Remove `include("types.jl")` from `src/LibFEM.jl` (line 7)
3. Remove all type/struct exports from `src/LibFEM.jl` (lines 39-43)
4. Remove `using Base: @kwdef` (no longer needed)
5. Update `CONTEXT.md` to remove the type hierarchy section
6. **No test changes** — no test dispatches on these types either

### Wins

- **Locality:** one fewer file; the naming convention tells the story
- **Interface shrinks:** 15 exported symbols eliminated
- **Leverage:** deletion is one change; every future reader has less noise
- **Honest code:** what-you-see matches what-you-get

### ADR conflict

`CONTEXT.md` (2026-07) explicitly decided to keep the type hierarchy as "documentation scaffolding." That decision was a tradeoff: ~120 lines for documentation value. The cost is now ~167 lines (types.jl + CONTEXT.md section + exports in LibFEM.jl). The *misleading* cost — developers reading types.jl and assuming dispatch exists — outweighs the documentation value. **Worth reopening the ADR.**

---

## Candidate 2: Deepen the 2D coordinate-based API

**Recommendation strength:** ✦ **Strong** (emerald)
**Category:** in-process

**Files:** `src/truss.jl`, `src/spring.jl`, `src/beam.jl`, `src/utils.jl`

### Problem

All 2D element stiffness functions take **angles in degrees** (θ), but `CONTEXT.md` recommends:

> "For most practical purposes, users should derive direction cosines from node coordinates via `d2_truss_elementlength` or `d3_truss_elementlength` rather than specifying angles manually."

This means every user's workflow for a real problem involves:

```julia
# Current — user must compute L and θ from coordinates
L = d2_truss_elementlength(x1, y1, x2, y2)
θ = atan2d(y2 - y1, x2 - x1)
k = d2_truss_elementstiffness(E, A, L, θ)
```

The module is **shallow**: it pushes coordinate→angle transformation to every call site instead of absorbing it. Meanwhile, `d3_spaceframe_elementstiffness` already takes coordinates directly:

```julia
# d3_spaceframe — coordinates directly
k = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)
```

This split creates an **inconsistent seam**: the 3D API is coordinate-based (deep), the 2D API is angle-based (shallow).

### Solution

Add coordinate-based overloads. No existing angle-based functions change.

**For truss (truss.jl):**
```julia
function d2_truss_elementstiffness(E::Real, A::Real, x1::Real, y1::Real, x2::Real, y2::Real)
    L = d2_truss_elementlength(x1, y1, x2, y2)
    θ = rad2deg(atan(y2 - y1, x2 - x1))  # or just pass C,S from coordinates directly
    return d2_truss_elementstiffness(E, A, L, θ)
end
```

Better approach — compute direction cosines from coordinates directly instead of going through `θ`:
```julia
function d2_truss_elementstiffness(E::Real, A::Real, x1::Real, y1::Real, x2::Real, y2::Real)
    L = d2_truss_elementlength(x1, y1, x2, y2)
    C, S = (x2 - x1) / L, (y2 - y1) / L
    validate_positive(A, "A")
    w = [C*C C*S; C*S S*S]
    return E * A / L * [w -w; -w w]
end
```

**Same pattern for:**
- `d2_truss_elementforces(E, A, x1, y1, x2, y2, u)`
- `d2_truss_elementstrain(x1, y1, x2, y2, u)`
- `d2_truss_elementstress(E, x1, y1, x2, y2, u)`
- `d2_spring_elementstiffness(k, x1, y1, x2, y2)`
- `d2_spring_elementforce(k, x1, y1, x2, y2, u)`
- `d2_planeframe_elementstiffness(E, A, I, x1, y1, x2, y2)`
- `d2_planeframe_elementforces(E, A, I, x1, y1, x2, y2, u)`

### Wins

- **Locality:** one call replaces 4 lines per call site
- **Leverage:** N call sites, one deepened interface
- **Consistency:** matches the d3_spaceframe coordinate-based pattern
- **Tests cover less boilerplate** — internal transformation is tested once

---

## Candidate 3: Generalize 3-node assembly

**Recommendation strength:** ✦ **Worth exploring** (amber)
**Category:** in-process

**Files:** `src/assembly.jl`, `src/quadraticbar.jl`

### Problem

`d1_quadraticbar_assemble` does not delegate to the shared `_assemble!` helper. It has:

- 9 individual indexed assignment statements
- Manual bounds checking
- Manual distinctness validation (`i == j || i == m || j == m`)
- **No `@views`**

The comment in the code says: "This is a custom assembly because the generic `_assemble!` helper only supports 2-node elements."

Every other element delegates to `_assemble!` with a one-liner. The quadratic bar is the sole exception.

### Solution

Extend `_assemble!` (or create `_assemble!` with variable arity) to support N-node elements:

```julia
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, ndofs::Integer, indices::Integer...)
    nnodes = length(indices)
    for (ri, rnode) in enumerate(indices)
        for (ci, cnode) in enumerate(indices)
            r_range = (rnode - 1) * ndofs + 1:rnode * ndofs
            c_range = (cnode - 1) * ndofs + 1:cnode * ndofs
            k_range = (ri - 1) * ndofs + 1:ri * ndofs, (ci - 1) * ndofs + 1:ci * ndofs
            K[r_range, c_range] .+= @view k[k_range...]
        end
    end
    return K
end
```

Then `d1_quadraticbar_assemble` becomes:

```julia
function d1_quadraticbar_assemble(K, k, i, j, m)
    return _assemble!(K, k, 1, i, j, m)
end
```

The existing `_assemble!(K, k, i, j, ndofs)` for 2-node elements can either forward to the generalized version or remain as a fast-path for the common case.

### Wins

- **Locality:** one assembly code path for all elements
- **Leverage:** adding future N-node elements (quadrilateral, triangle) is instant
- **Removes the comment** explaining why quadraticbar is special
- **@views applies uniformly** — no manual indexing

---

## Candidate 4: Delegate duplicated length functions

**Recommendation strength:** ✦ **Speculative** (slate)
**Category:** in-process

**Files:** `src/truss.jl`, `src/beam.jl`

### Problem

| Function | Implementation | Delegates? |
|----------|---------------|------------|
| `d2_truss_elementlength` | `√(Δx²+Δy²)` + `validate_positive` | — (primary) |
| `d3_truss_elementlength` | `√(Δx²+Δy²+Δz²)` + `validate_positive` | — (primary) |
| `d3_spaceframe_elementlength` | `√(Δx²+Δy²+Δz²)` + `validate_positive` | ❌ identical to d3_truss |
| `d2_planeframe_elementlength` | calls `d2_truss_elementlength` | ✓ |

`d3_spaceframe_elementlength` is identical to `d3_truss_elementlength`. The earlier enhancement plan (Item 12) already did this for `d2_planeframe_elementlength`. The 3D version left behind.

### Solution

```julia
function d3_spaceframe_elementlength(x1, y1, z1, x2, y2, z2)
    return d3_truss_elementlength(x1, y1, z1, x2, y2, z2)
end
```

### Wins

- **Locality:** one implementation to check for correctness
- **Consistency:** matches the `d2_planeframe_elementlength` delegation pattern

---

## Top Recommendation

**Remove the unused type hierarchy, then deepen the 2D coordinate-based API** — in this order.

1. **Delete `types.jl`** — pure simplification. No test changes. No downstream impact. Removes a gap between what the type hierarchy *says* the code does and what it *actually* does.
2. **Add coordinate-based overloads** to d2_truss, d2_spring, d2_planeframe — completes the pattern that d3_spaceframe already follows. Each overload is ~3-6 lines; removes ~4 lines of boilerplate from every call site.

These two changes together make the module depth match the expressed design intent: a function-oriented FEM library where the module absorbs coordinate transformation, and no dead abstractions confuse the structure.

The other candidates (N-node assembly generalization, elementlength delegation) are worth stacking in a follow-up but address smaller gaps.
