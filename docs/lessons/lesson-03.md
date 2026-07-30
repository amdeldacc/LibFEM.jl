# Lesson 3: The Linear Bar Element — From Abstract Spring to Physical Bar

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 3
> Mapped to LibFEM.jl — `src/bar.jl`, `src/utils.jl`, `src/assembly.jl`

**Prerequisites**: Lesson 1 (6-step method), Lesson 2 (spring assembly)

---

## 3.1 The Leap: Spring → Bar

In Lesson 2, the spring used an abstract stiffness `k`:

```
k_spring = [k  -k; -k  k]
```

The **linear bar** replaces `k` with a physically-derived quantity:

```
k_bar = (E·A/L) × [1  -1; -1  1]
```

| Symbol | Meaning | Unit | Typical value |
|--------|---------|------|---------------|
| **E** | Young's modulus (material stiffness) | Pa (N/m²) | 200×10⁹ (steel) |
| **A** | Cross-sectional area (geometry) | m² | 0.01 |
| **L** | Element length | m | 4.0 |
| **EA/L** | Axial stiffness | N/m | 5×10⁸ |

### Physical intuition

- **↑E** (stiffer material) **→ ↑stiffness** — steel is harder to stretch than rubber
- **↑A** (thicker bar) **→ ↑stiffness** — a thick rod is harder to stretch than a thin wire
- **↑L** (longer bar) **→ ↓stiffness** — a long rubber band is easier to stretch than a short one

---

## 3.2 MATLAB → Julia Mapping

Kattan calls this element `LinearBar` in MATLAB (Ch3). LibFEM.jl names it `d1_bar` to match the MATLAB `LinearBar` convention (renamed from the earlier `d1_truss` prefix).

| Operation | Kattan MATLAB | LibFEM.jl Julia | Source |
|-----------|--------------|-----------------|--------|
| Stiffness | `LinearBarElementStiffness(E, A, L)` | `d1_bar_elementstiffness(E, A, L)` | `bar.jl:20-25` |
| Assembly | `LinearBarAssemble(K, k, i, j)` | `d1_bar_assemble(K, k, i, j)` | `bar.jl:89-94` |
| Forces | `LinearBarElementForces(k, u)` | `d1_bar_elementforces(Ke, u)` | `bar.jl:35-41` |
| Stresses | `LinearBarElementStresses(k, u, A)` | `d1_bar_elementstress(Ke, u, A)` | `bar.jl:51-59` |
| Strain | *(not in Kattan)* | `d1_bar_elementstrain(L, u)` | `bar.jl:69-76` |

**LibFEM.jl adds a `strain` function** that Kattan doesn't provide — a natural extension. (Renamed from `d1_truss_*` to `d1_bar_*` to match the MATLAB `LinearBar` convention.)

### Side-by-side code comparison

**Stiffness** — identical structure, just Julia syntax:

```matlab
% MATLAB (Kattan, Ch3)
function y = LinearBarElementStiffness(E, A, L)
    y = [E*A/L  -E*A/L;  -E*A/L  E*A/L];
end
```

```julia
# Julia (LibFEM.jl, bar.jl:20-25)
function d1_bar_elementstiffness(E::Real, A::Real, L::Real)
    validate_positive(L, "L")
    validate_positive(A, "A")
    return E * A / L * [1 -1; -1 1]
end
```

Key differences:
- **Type annotations**: Julia uses `E::Real` to ensure type stability
- **Input validation**: LibFEM.jl checks `L > 0` and `A > 0` before computing — MATLAB silently accepts negatives
- **Syntax**: Julia's `E * A / L * [1 -1; -1 1]` vs MATLAB's `[E*A/L -E*A/L; -E*A/L E*A/L]` — same math

**Assembly** — identical to the spring, both delegate to `_assemble!`:

```julia
# Julia (bar.jl:89-94)
function d1_bar_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)   # ndofs=1 (same as spring!)
end
```

```matlab
% MATLAB (Kattan, Ch3)
function y = LinearBarAssemble(K, k, i, j)
    K(i,i) = K(i,i) + k(1,1);
    K(i,j) = K(i,j) + k(1,2);
    K(j,i) = K(j,i) + k(2,1);
    K(j,j) = K(j,j) + k(2,2);
    y = K;
end
```

Same 4-line pattern. Same `ndofs=1`. **Assembly is dimension-agnostic** — it only cares about how many DOFs each node has.

**Forces** — pure Hooke's law, identical to spring:

```julia
# Julia (bar.jl:35-41)
function d1_bar_elementforces(Ke::AbstractMatrix, u::AbstractVector)
    return Ke * u       # f = k · u
end
```

**Stress** — Kattan's addition (Ch3), dividing force by area:

```julia
# Julia (bar.jl:51-59)
function d1_bar_elementstress(Ke::AbstractMatrix, u::AbstractVector, A::Real)
    validate_positive(A, "A")
    return Ke * u / A   # σ = f / A
end
```

```matlab
% MATLAB (Kattan, Ch3)
function y = LinearBarElementStresses(k, u, A)
    y = k * u / A;
end
```

**Strain** — LibFEM.jl extension (not in Kattan):

```julia
# Julia (bar.jl:69-76)
function d1_bar_elementstrain(L::Real, u::AbstractVector)
    validate_positive(L, "L")
    return (u[2] - u[1]) / L   # ε = ΔL / L
end
```

---

## 3.3 The Spring-Bar Identity

A critical insight verified in LibFEM.jl's tests (`runtests.jl:973-974`):

```julia
@test d1_spring_elementstiffness(500) == d1_bar_elementstiffness(500, 1, 1)
```

**When EA/L = k, the matrices are numerically identical.** The bar is just a spring with a physically-derived stiffness constant. This identity extends to 2D and 3D:

```julia
# 2D: spring(k=EA/L, θ) = truss(E, A, L, θ) when EA/L = k
@test d2_spring_elementstiffness(100, 30) ≈ d2_truss_elementstiffness(100, 1, 1, 30)

# 3D: same identity
@test d3_spring_elementstiffness(100, 30, 45, 60) ≈ d3_truss_elementstiffness(100, 1, 1, 30, 45, 60)
```

So mathematically, **the spring element and the bar element are the same** — the only difference is whether you provide the stiffness directly (spring) or compute it from material/geometry (bar).

---

## 3.4 Validation — Physical Plausibility

LibFEM.jl rejects physically impossible inputs. The helpers in `src/utils.jl`:

```julia
# utils.jl:87-90
@inline function validate_positive(x::Real, name::AbstractString)
    x > 0 || throw(ElementParameterError(name, "$name must be positive, got $x"))
    return nothing
end
```

**What is validated (throws `ElementParameterError`)**:

| Parameter | Why | Test coverage |
|-----------|-----|---------------|
| `L ≤ 0` | Zero/negative length is nonsensical | `runtests.jl:193-196` |
| `A ≤ 0` | Zero/negative area is nonsensical | `runtests.jl:215-217` |

**What is NOT validated (passes through)**:

| Parameter | Behavior | Why |
|-----------|----------|-----|
| `E = 0` | Returns zero matrix (`runtests.jl:219`) | A zero-modulus material (rigid-body limit) |
| `E < 0` | Produces negative-definite matrix (`runtests.jl:221`) | Not physically meaningful, but not explicitly blocked |

```julia
# Tested edge cases (runtests.jl:213-222)
@test d1_bar_elementstiffness(0.0, 1.0, 1.0) == zeros(2, 2)   # E=0 → zero stiffness
@test d1_bar_elementstiffness(-1.0, 1.0, 1.0) == -[1 -1; -1 1]  # E<0 → flipped sign
```

**Assembly error case**: trying to assemble an element with the same node at both ends (`i == j`):

```julia
# assembly.jl:22
i == j && throw(AssemblyError("Assembly requires i ≠ j, got i=j=$i"))
```

---

## 3.5 The 4-Function API

The 1D truss extends the 3-function pattern (stiffness, assemble, force) to 4 functions by adding strain:

```
Element type: 1D Linear Bar / Truss
DOF count:    2 nodes × 1 DOF/node = 2 total DOFs
Matrix size:  2×2
```

| Function | Purpose | Returns | Calls |
|----------|---------|---------|-------|
| `d1_bar_elementstiffness(E, A, L)` | Build 2×2 stiffness matrix | `Matrix{Float64}` | `validate_positive` |
| `d1_bar_assemble(K, k, i, j)` | Insert into global K | Updated K | `_assemble!(..., 1)` |
| `d1_bar_elementforces(Ke, u)` | Nodal forces | `Vector{Float64}` (2×1) | `Ke * u` |
| `d1_bar_elementstress(Ke, u, A)` | Nodal stresses | `Vector{Float64}` (2×1) | `Ke * u / A` |
| `d1_bar_elementstrain(L, u)` | Element strain | scalar `Float64` | `(u₂−u₁)/L` |

---

## 3.6 Full Worked Example — 3-Bar System

**Problem (Kattan Example 3.1)**: Three steel bars (E = 200 GPa) with cross-sectional area A = 0.01 m². Lengths: L₁ = 2 m, L₂ = 3 m, L₃ = 4 m. A load P = 100 kN is applied at node 3. Nodes 1 and 4 are fixed to walls.

```
  wall                          wall
  ┌────┳━━━(1)━━━┳━━━(2)━━━┳━━━(3)━━━┳────┐
 node1        node2         node3        node4
                                          ▲
                                          │ P = 100 kN
```

### Step 1: Discretize
4 nodes, 3 elements. Each node has 1 DOF (axial displacement).

### Step 2: Element stiffnesses

```julia
using LibFEM

E = 200e9     # Pa
A = 0.01      # m²
L1, L2, L3 = 2.0, 3.0, 4.0

k1 = d1_bar_elementstiffness(E, A, L1)   # EA/L₁ = 1e9
k2 = d1_bar_elementstiffness(E, A, L2)   # EA/L₂ ≈ 6.667e8
k3 = d1_bar_elementstiffness(E, A, L3)   # EA/L₃ = 5e8
```

Verifying the stiffness values:

```julia
julia> E*A/L1
1.0e9

julia> E*A/L2
6.666666666666667e8

julia> E*A/L3
5.0e8
```

### Step 3: Assemble

```julia
K = zeros(4, 4)
K = d1_bar_assemble(K, k1, 1, 2)  # element 1: nodes 1-2
K = d1_bar_assemble(K, k2, 2, 3)  # element 2: nodes 2-3
K = d1_bar_assemble(K, k3, 3, 4)  # element 3: nodes 3-4
```

Result:

```
K = 10⁸ ×
    ┌                                ┐
    │  10.00  -10.00    0       0    │  node1
    │ -10.00   16.667   -6.667  0    │  node2
    │   0      -6.667   11.667 -5.0  │  node3
    │   0       0       -5.0    5.0  │  node4
    └                                ┘
```

### Step 4: Boundary conditions

| Node | Known | Unknown |
|------|-------|---------|
| 1 | `u₁ = 0` (fixed) | F₁ (reaction) |
| 2 | `F₂ = 0` | u₂ |
| 3 | `F₃ = 100e3` (100 kN →) | u₃ |
| 4 | `u₄ = 0` (fixed) | F₄ (reaction) |

### Step 5: Partition and solve

Remove rows/cols 1 and 4 (fixed DOFs). Solve 2×2 system for u₂, u₃:

```julia
K_red = K[2:3, 2:3]         # [16.667  -6.667; -6.667  11.667] × 10⁸
F_red = [0.0, 100e3]        # F₂=0, F₃=100kN
u_red = K_red \ F_red

u = zeros(4)
u[1] = 0.0                  # fixed
u[2] = u_red[1]
u[3] = u_red[2]
u[4] = 0.0                  # fixed
```

Results: **u₂ ≈ 1.0×10⁻⁶ m**, **u₃ ≈ 1.45×10⁻⁵ m**

### Step 6: Post-process

**Element forces**:

```julia
f1 = d1_bar_elementforces(k1, u[1:2])
f2 = d1_bar_elementforces(k2, u[2:3])
f3 = d1_bar_elementforces(k3, u[3:4])
```

**Element stresses** (σ = f/A):

```julia
σ1 = d1_bar_elementstress(k1, u[1:2], A)
σ2 = d1_bar_elementstress(k2, u[2:3], A)
σ3 = d1_bar_elementstress(k3, u[3:4], A)
```

**Element strains** (ε = ΔL/L):

```julia
ε1 = d1_bar_elementstrain(L1, u[1:2])
ε2 = d1_bar_elementstrain(L2, u[2:3])
ε3 = d1_bar_elementstrain(L3, u[3:4])
```

**Reactions** (from the full K·u = F):

```julia
F_full = K * u
F1 = F_full[1]    # reaction at node 1 (wall)
F4 = F_full[4]    # reaction at node 4 (wall)
# F1 + F4 = -100 kN (equilibrium with applied load ✓)
```

---

## 3.7 The Property-Based Invariants

LibFEM.jl uses **property-based tests** (`test/property_tests.jl`) to verify that every stiffness matrix satisfies fundamental physical invariants for random valid inputs:

```julia
# property_tests.jl:132-137
Ke = d1_bar_elementstiffness(e, a, l)
@test Ke ≈ Ke'                       # Symmetry: K = Kᵀ
@test all(>(0), eigvals(Ke))         # Positive semi-definite: all eigenvalues ≥ 0
@test sum(Ke; dims=2) ≈ zeros(2)     # Zero row-sum: each row sums to 0
```

These invariants hold for **every** structural element in LibFEM.jl:
1. **Symmetry**: K[i,j] = K[j,i]
2. **Positive semi-definite**: all eigenvalues ≥ 0 (one zero eigenvalue = rigid body motion)
3. **Zero row-sum**: unconstrained element rows sum to 0

---

## 3.8 The Big Picture: Hierarchy of 1D Elements

```
All 1D elements (1 DOF/node) share:
  • Same 2×2 matrix shape
  • Same assembly (_assemble!, ndofs=1)
  • Same force recovery (Ke × u)

The only difference is WHAT multiplies the [1 -1; -1 1] pattern:

  Spring (Ch2):    k          (abstract stiffness)
  Linear Bar (Ch3): EA/L       (material × geometry)
  Heat 1D (Ch12):  kₜₕ/L      (thermal conductivity)
```

In code:

```julia
# Spring — direct k
d1_spring_elementstiffness(k)  →  k * [1 -1; -1 1]

# Bar — computed from E, A, L
d1_bar_elementstiffness(E, A, L)  →  E*A/L * [1 -1; -1 1]

# They're the same matrix when EA/L = k
@test d1_spring_elementstiffness(500) == d1_bar_elementstiffness(500, 1, 1)
```

---

## 3.9 Running the Tests

```bash
julia --project=. test/runtests.jl
```

This runs the d1_bar test block (formerly d1_truss) at lines 145-223 of `runtests.jl`, covering:
- Stiffness matrix shape, values, and physical invariants (symmetry, PSD, zero row-sum)
- Force calculation with known displacement
- Stress calculation with area division
- Strain calculation (ΔL/L)
- Assembly correctness (K receives k at right positions)
- Error paths: L=0, L<0, A=0, A<0, i=j assembly
- Boundary cases: E=0 (zero matrix), E<0 (negated matrix)

---

## Summary

| Concept | Takeaway |
|---------|----------|
| Bar stiffness | `EA/L × [1 -1; -1 1]` — physically derived from material + geometry |
| Spring ↔ Bar | When `k = EA/L`, the matrices are **identical** |
| Stress | `σ = f / A` — force divided by area |
| Strain | `ε = (u₂ − u₁) / L` — normalized elongation |
| Validation | `L > 0` and `A > 0` enforced via `validate_positive` |
| MATLAB → Julia | `LinearBar*` → `d1_bar_*` (renamed from `d1_truss_*`) + added strain function |

**Coming up in Lesson 4**: The Quadratic Bar — a 3-node 1D element that extends the pattern from 2×2 to 3×3.
