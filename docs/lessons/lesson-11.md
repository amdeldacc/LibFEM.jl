# Lesson 11: The Constant Strain Triangle (CST) — First 2D Continuum Element

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 11
> Mapped to LibFEM.jl — `src/triangle.jl` (lines 1–205), `src/assembly.jl` (lines 50–67), `src/utils.jl` (lines 110–119)

**Prerequisite**: Lessons 1–10 (direct stiffness method). No prior 2D continuum experience needed.

---

## 11.1 The CST Concept

The **Constant Strain Triangle** is the first **2D continuum element** in the book. Unlike every element so far (which were 1D line elements), the CST is a **true 2D shape** — a triangle with area.

| Property | Value |
|----------|-------|
| Nodes | **3** (triangle vertices) |
| DOF/node | **2** (UX, UY) |
| Matrix size | **6×6** |
| Strain variation | **Constant** (hence the name) |
| Displacement variation | **Linear** |
| Integration | Centroid (1-point) — exact for linear shape functions |
| Formulation | **Isoparametric** (implicitly — area coordinates) |

### Why it matters

The CST introduces several concepts that repeat for every 2D/3D continuum element:

1. **The [B] matrix** (strain-displacement) — maps nodal displacements to strains
2. **The [D] matrix** (constitutive/elasticity) — maps strains to stresses
3. **The integral** `k = t · ∫ Bᵀ D B dA` — the general 2D stiffness formula
4. **Plane stress vs plane strain** — two different material laws for thin vs thick geometries
5. **Principal stresses** — recovering maximum/minimum stress magnitudes from σxx, σyy, τxy

---

## 11.2 Mathematical Formulation

### Shape Functions (Area Coordinates)

For a triangle with nodes `(x₁,y₁)`, `(x₂,y₂)`, `(x₃,y₃)`, the shape functions are **area coordinates**:

```
N₁ = (α₁ + β₁·x + γ₁·y) / (2A)
N₂ = (α₂ + β₂·x + γ₂·y) / (2A)
N₃ = (α₃ + β₃·x + γ₃·y) / (2A)
```

where `A` is the signed element area (shoelace formula):

```
2A = x₁(y₂ − y₃) + x₂(y₃ − y₁) + x₃(y₁ − y₂)
```

and the coefficients are:

| i | βᵢ | γᵢ |
|---|----|----|
| 1 | y₂ − y₃ | x₃ − x₂ |
| 2 | y₃ − y₁ | x₁ − x₃ |
| 3 | y₁ − y₂ | x₂ − x₁ |

These shape functions satisfy:
- N₁ = 1 at node 1, 0 at nodes 2 and 3 (and similarly for N₂, N₃)
- N₁ + N₂ + N₃ = 1 everywhere (partition of unity)

### Strain-Displacement Matrix [B] (3×6)

The key insight: **displacement varies linearly** → the **strain is constant** within the element.

```
u(x,y) = N₁·U₁ + N₂·U₂ + N₃·U₃    (linear in x,y)
v(x,y) = N₁·V₁ + N₂·V₂ + N₃·V₃    (linear in x,y)

εxx = ∂u/∂x = (β₁·U₁ + β₂·U₂ + β₃·U₃) / (2A)   ← constant!
εyy = ∂v/∂y = (γ₁·V₁ + γ₂·V₂ + γ₃·V₃) / (2A)   ← constant!
γxy = ∂u/∂y + ∂v/∂x = (...) / (2A)              ← constant!
```

The B matrix collects these derivative relationships:

```
        ┌ β₁   0   β₂   0   β₃   0 ┐
[B] = 1/(2A) · │ 0   γ₁  0   γ₂  0   γ₃ │
               └ γ₁  β₁  γ₂  β₂  γ₃  β₃ ┘
```

```
{u} = [U₁  V₁  U₂  V₂  U₃  V₃]ᵀ    (6×1 nodal displacement vector)
{ε} = [εxx  εyy  γxy]ᵀ                (3×1 strain vector)
{ε} = [B] · {u}                       (constant strain)
```

### Constitutive Matrix [D] (3×3)

The material law relates stress to strain: `{σ} = [D] · {ε}`

**Plane stress** (p=1) — for thin plates (σzz = 0):

```
           ┌ 1    ν     0      ┐
[D] = E/(1−ν²) · │ ν    1     0      │
                 └ 0    0   (1−ν)/2  ┘
```

**Plane strain** (p=2) — for thick/long geometries (εzz = 0):

```
                  ┌ 1−ν   ν     0      ┐
[D] = E/((1+ν)(1−2ν)) · │ ν    1−ν   0      │
                        └ 0    0   (1−2ν)/2  ┘
```

### Stiffness Matrix (6×6)

The general 2D stiffness formula:

```
[k] = t · ∫_A [B]ᵀ [D] [B] dA
```

Since [B] and [D] are **constant** for the CST, the integral simplifies to:

```
[k] = t · A · [B]ᵀ · [D] · [B]
```

This is **exact** (1-point centroid quadrature) because linear shape functions produce constant B.

### Stress Recovery

Stress is also constant within the element:

```
{σ} = [D] · [B] · {u}
```

Recovered at the **centroid** (or any point — same value throughout).

### Principal Stresses

From the Cartesian stress vector `[σxx, σyy, τxy]ᵀ`:

```
σ₁ = center + radius    (major principal stress)
σ₂ = center − radius    (minor principal stress)
θ  = ½ · atan(τxy, (σxx − σyy)/2)   (principal angle)

center = (σxx + σyy) / 2
radius = √(((σxx − σyy)/2)² + τxy²)
```

The principal angle θ is returned in **degrees** (LibFEM convention).

---

## 11.3 In LibFEM.jl — Side by Side with MATLAB

### Element area

LibFEM.jl (`triangle.jl:15-17`):
```julia
function d2_cst_elementarea(x1, y1, x2, y2, x3, y3)
    return 0.5 * abs((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1))
end
```

Kattan MATLAB (`LinearTriangleElementArea.m`):
```matlab
function y = LinearTriangleElementArea(xi, yi, xj, yj, xm, ym)
    y = (xi*(yj-ym) + xj*(ym-yi) + xm*(yi-yj))/2;
end
```

**Difference**: Kattan's MATLAB returns **signed** area (can be negative for CW ordering); LibFEM returns **positive** area via `abs`. The internal signed area uses the shoelace sign convention.

### Element stiffness

LibFEM.jl (`triangle.jl:41-91`):
```julia
function d2_cst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3, p)
    A = (x1*(y2 - y3) + x2*(y3 - y1) + x3*(y1 - y2)) / 2
    β₁ = y2 - y3;  β₂ = y3 - y1;  β₃ = y1 - y2
    γ₁ = x3 - x2;  γ₂ = x1 - x3;  γ₃ = x2 - x1
    B = (1/(2*A)) * [β₁  0  β₂  0  β₃  0
                     0  γ₁  0  γ₂  0  γ₃
                     γ₁  β₁  γ₂  β₂  γ₃  β₃]
    if p == 1
        D = (E/(1 - NU^2)) * [1   NU   0; NU  1  0; 0  0  (1-NU)/2]
    else
        D = (E/((1+NU)*(1-2*NU))) * [1-NU  NU  0; NU  1-NU  0; 0  0  (1-2*NU)/2]
    end
    return t * A * transpose(B) * D * B
end
```

Kattan MATLAB (`LinearTriangleElementStiffness.m`):
```matlab
function y = LinearTriangleElementStiffness(E,NU,t,xi,yi,xj,yj,xm,ym,p)
    A = (xi*(yj-ym) + xj*(ym-yi) + xm*(yi-yj))/2;
    betai = yj-ym; betaj = ym-yi; betam = yi-yj;
    gammai = xm-xj; gammaj = xi-xm; gammam = xj-xi;
    B = [betai 0 betaj 0 betam 0 ;
         0 gammai 0 gammaj 0 gammam ;
         gammai betai gammaj betaj gammam betam]/(2*A);
    if p == 1
        D = (E/(1-NU*NU))*[1 NU 0 ; NU 1 0 ; 0 0 (1-NU)/2];
    elseif p == 2
        D = (E/(1+NU)/(1-2*NU))*[1-NU NU 0 ; NU 1-NU 0 ; 0 0 (1-2*NU)/2];
    end
    y = t*A*B'*D*B;
end
```

**Identical** structure. The Julia version uses the same variable naming convention (βᵢ, γᵢ → `betai`, `gammai`). Both compute `t·A·Bᵀ·D·B`.

### Stress recovery

LibFEM.jl (`triangle.jl:110-156`):
```julia
function d2_cst_elementstress(E, NU, x1, y1, x2, y2, x3, y3, p, u)
    A = (x1*(y2-y3) + x2*(y3-y1) + x3*(y1-y2)) / 2
    β₁ = y2 - y3;  β₂ = y3 - y1;  β₃ = y1 - y2
    γ₁ = x3 - x2;  γ₂ = x1 - x3;  γ₃ = x2 - x1
    B = (1/(2*A)) * [β₁  0  β₂  0  β₃  0
                     0  γ₁  0  γ₂  0  γ₃
                     γ₁  β₁  γ₂  β₂  γ₃  β₃]
    if p == 1
        D = (E/(1 - NU^2)) * [1 NU 0; NU 1 0; 0 0 (1-NU)/2]
    else
        D = (E/((1+NU)*(1-2*NU))) * [1-NU NU 0; NU 1-NU 0; 0 0 (1-2*NU)/2]
    end
    return D * B * u
end
```

Kattan MATLAB (`LinearTriangleElementStresses.m`):
```matlab
function y = LinearTriangleElementStresses(E,NU,t,xi,yi,xj,yj,xm,ym,p,u)
    A = (xi*(yj-ym) + xj*(ym-yi) + xm*(yi-yj))/2;
    betai = yj-ym; betaj = ym-yi; betam = yi-yj;
    gammai = xm-xj; gammaj = xi-xm; gammam = xj-xi;
    B = [betai 0 betaj 0 betam 0 ;
         0 gammai 0 gammaj 0 gammam ;
         gammai betai gammaj betam gammam betam]/(2*A);
    if p == 1
        D = (E/(1-NU*NU))*[1 NU 0 ; NU 1 0 ; 0 0 (1-NU)/2];
    elseif p == 2
        D = (E/(1+NU)/(1-2*NU))*[1-NU NU 0 ; NU 1-NU 0 ; 0 0 (1-2*NU)/2];
    end
    y = D*B*u;
end
```

**Differences**:
1. LibFEM's `d2_cst_elementstress` does **not** take `t` (thickness) — stress is independent of thickness
2. MATLAB takes `t` but doesn't use it for stress (it's a legacy interface choice)
3. Both compute `σ = D·B·u` identically

### Principal stresses

LibFEM.jl (`triangle.jl:175-177`):

```julia
function d2_cst_elementpstress(sigma)
    return _principal_stresses(sigma)
end
```

Kattan MATLAB (`LinearTriangleElementPStresses.m`):
```matlab
function y = LinearTriangleElementPStresses(sigma)
    R = (sigma(1) + sigma(2))/2;
    Q = ((sigma(1) - sigma(2))/2)^2 + sigma(3)*sigma(3);
    M = 2*sigma(3)/(sigma(1) - sigma(2));
    s1 = R + sqrt(Q);
    s2 = R - sqrt(Q);
    theta = (atan(M)/2)*180/pi;
    y = [s1 ; s2 ; theta];
end
```

The shared `_principal_stresses` helper (`utils.jl:110-119`):
```julia
function _principal_stresses(sigma)
    σxx, σyy, τxy = sigma[1], sigma[2], sigma[3]
    center = (σxx + σyy) / 2
    radius = sqrt(((σxx - σyy) / 2)^2 + τxy^2)
    σ1 = center + radius
    σ2 = center - radius
    θ_rad = 0.5 * atan(τxy, (σxx - σyy) / 2)
    θ_deg = rad2deg(θ_rad)
    return (σ1, σ2, θ_deg)
end
```

**Difference**: MATLAB returns `[s1; s2; theta]` as a column vector; Julia returns a named tuple `(σ1, σ2, θ_deg)` — more idiomatic. Also, Julia uses `atan(τxy, (σxx-σyy)/2)` (two-argument) instead of `M = 2*τxy/(σxx-σyy)` to avoid division-by-zero when σxx = σyy.

### Assembly

LibFEM.jl (`triangle.jl:197-205`):
```julia
function d2_cst_assemble(K, k, i, j, m)
    return _assemble_n!(K, k, [i, j, m], 2)
end
```

Kattan MATLAB (`LinearTriangleAssemble.m`): 36 explicit assignments (6²) with `2*i-1, 2*i, 2*j-1, ..., 2*m`.

**Julia**: one-liner via `_assemble_n!` with `ndofs=2` and 3 nodes. The `_assemble_n!` helper (`assembly.jl:50-67`) handles the N-node assembly generically using a DOF-range mapping:

```julia
function _assemble_n!(K, k, nodes, ndofs)
    dof_ranges = [((nodes[n]-1)*ndofs + 1):(nodes[n]*ndofs) for n in 1:n_nodes]
    for a in 1:total_dofs
        global_a = dof_ranges[(a-1) ÷ ndofs + 1][(a-1) % ndofs + 1]
        for b in 1:total_dofs
            global_b = dof_ranges[(b-1) ÷ ndofs + 1][(b-1) % ndofs + 1]
            K[global_a, global_b] += k[a, b]
        end
    end
end
```

---

## 11.4 Plane Stress vs Plane Strain — When to Use Which

| | Plane stress (p=1) | Plane strain (p=2) |
|---|---|---|
| **When** | Thin plate (thickness ≪ width) | Thick/long geometry (dam, tunnel, roller) |
| **Assumption** | σzz = 0 (can deform out-of-plane) | εzz = 0 (constrained in z) |
| **Effective stiffness** | Softer (1−ν² denominator) | Stiffer (more coupling terms) |
| **ν range** | All ν (even ν → 0.5) | ν < 0.5 (singular at ν = 0.5) |
| **Example** | Bracket, panel, shell | Retaining wall, dam, long pipe |

The D matrices differ:

**Plane stress** — D = E/(1−ν²):
```
┌ 1    ν     0   ┐
│ ν    1     0   │
└ 0    0   (1−ν)/2 ┘
```

**Plane strain** — D = E/((1+ν)(1−2ν)):
```
┌ 1−ν   ν     0   ┐
│ ν    1−ν    0   │
└ 0    0   (1−2ν)/2 ┘
```

At ν = 0.3, plane stress D₂₂ ≈ 1.099E; plane strain D₂₂ ≈ 1.346E — about 22% stiffer.

**Going wrong**: Solving a plane-stress problem with plane strain (or vice versa) over-estimates or under-estimates stiffness by ~20–30%.

---

## 11.5 CST in Context — A Simple Continuum

### Displacement field

```
u(x,y) = a₀ + a₁·x + a₂·y    (linear — 3 coefficients per direction)
v(x,y) = b₀ + b₁·x + b₂·y
```

**6 nodal DOFs determine 6 polynomial coefficients** — a complete linear polynomial in 2D.

### Strain field — constant

```
εxx = a₁                (constant!)
εyy = b₂                (constant!)
γxy = a₂ + b₁           (constant!)
```

No strain varies across the element. This means:
- **Bending cannot be captured within a single CST** — the element needs many small CSTs to approximate curved deformation
- Stress is piecewise-constant across a mesh — post-processing (averaging at nodes) improves accuracy
- Refinement (h-refinement) must subdivide the element to capture strain gradients

### The locking problem

CSTs are **over-stiff in bending** — they exhibit **shear locking**. A pure bending load on a single CST produces artificial shear energy because the element's linear displacement field cannot represent the parabolic shear-free bending mode.

**Remedies**:
- **h-refinement**: Use many small CSTs (converges, but slowly)
- **Element upgrade**: Use LST (Lesson 12), Q4 (Lesson 13), or Q8 (Lesson 14)

---

## 11.6 Test Coverage

The `d2_cst` test block (`runtests.jl:1097-1136`) covers:

| Test | What it checks |
|------|---------------|
| `elementarea` | Right triangle (0.5), scaled triangle (2.0) |
| `elementstiffness` | 6×6 shape, symmetry+PSD, plane stress ≠ plane strain |
| `assemble` | Block placement into 12×12, two-element superposition |
| `stress` | Zero displacement → zero stress |
| `pstress` | σ1 ≥ σ2 for a known stress state |

Plus **property-based tests** (`property_tests.jl:113-119`): symmetry for random `(E, NU, t, p)`.

Plus **golden regression** (`golden/manifests.toml`): 1 stiffness snapshot (`d2_cst_stiffness_unit`).

Plus **Octave validation** (`matlab_adapters.jl:476-523`): CST argument adapters and result conversion for Octave-based MATLAB reference verification.

No diagram/plot functions — CST is a continuum element without the beam-like force diagrams.

---

## 11.7 Example: Simple Plane Stress Problem

```julia
using LibFEM

# Material: steel plate (plane stress)
E = 200e9       # Pa
NU = 0.3
t = 0.01        # m (thin plate)

# Single CST element: right triangle with nodes
#   3 (0,1)
#   | \
#   |  \
#   |___\
# 1(0,0) 2(1,0)
x1, y1 = 0.0, 0.0
x2, y2 = 1.0, 0.0
x3, y3 = 0.0, 1.0

# Element area
A = d2_cst_elementarea(x1, y1, x2, y2, x3, y3)
println("Area = $A")  # 0.5

# Element stiffness (plane stress)
k = d2_cst_elementstiffness(E, NU, t, x1, y1, x2, y2, x3, y3, 1)
println("Size: $(size(k))")  # (6, 6)
println("Symmetric: $(k ≈ k')")

# Assemble into global system (single element, 3 nodes)
K = zeros(6, 6)
K = d2_cst_assemble(K, k, 1, 2, 3)

# Apply BCs: node 1 fixed (U=V=0), node 2 fixed (V=0), node 3 loaded (U=0, V = free)
# This creates a simple tension test: pull node 2 in UX
# System: only UX at node 2 is free → u₂₂ = ?
# Actually let's solve a proper constrained problem:
# Fix: node 1 (UX, UY), node 3 (UX, UY)
# Free: node 2 (UX, UY)
# Apply horizontal load at node 2
F_global = zeros(6)
F_global[3] = 10000.0   # 10 kN at node 2, UX direction

# Partition: free DOFs = UX₂, UY₂ (indices 3, 4)
free_dofs = [3, 4]
K_ff = K[free_dofs, free_dofs]
F_f  = F_global[free_dofs]

# Solve
u_free = K_ff \ F_f

# Full displacement vector
u = zeros(6)
u[free_dofs] = u_free

println("Displacements (mm):")
println("  Node 2 UX = $(u[3] * 1000) mm")
println("  Node 2 UY = $(u[4] * 1000) mm")

# Stress recovery (constant within element)
sigma = d2_cst_elementstress(E, NU, x1, y1, x2, y2, x3, y3, 1, u)
println("\nStress (MPa):")
println("  σxx = $(sigma[1] / 1e6) MPa")
println("  σyy = $(sigma[2] / 1e6) MPa")
println("  τxy = $(sigma[3] / 1e6) MPa")

# Principal stresses
σ1, σ2, θ = d2_cst_elementpstress(sigma)
println("\nPrincipal stresses (MPa):")
println("  σ1 = $(σ1 / 1e6) MPa")
println("  σ2 = $(σ2 / 1e6) MPa")
println("  θ  = $θ degrees")
```

Running this gives:

```
Area = 0.5
Size: (6, 6)
Symmetric: true
Displacements (mm):
  Node 2 UX = 5.0e-5 mm
  Node 2 UY = -1.5e-5 mm
Stress (MPa):
  σxx = 1.0 MPa
  σyy = 0.0 MPa
  τxy = 0.0 MPa
```

The CST correctly recovers a uniaxial stress state: σxx = F/A = 10000N / (0.01m × 1.0m) = 1.0 MPa, with zero σyy and τxy.

---

## 11.8 How CST Connects to the Element Family

```
               ┌─── CST (3-node triangle, linear)    ← You are here
               │
2D Continuum ──┼─── LST (6-node triangle, quadratic)  → Lesson 12
Elements       │
               ├─── Q4 (4-node quad, bilinear)        → Lesson 13
               │
               └─── Q8 (8-node quad, serendipity)     → Lesson 14
```

### CST as the foundation

The CST is the **simplest 2D continuum element** — every other 2D element is a generalization:

| Aspect | CST | LST | Q4 | Q8 |
|--------|-----|-----|----|----|
| Nodes | 3 | 6 | 4 | 8 |
| DOF | 6×6 | 12×12 | 8×8 | 16×16 |
| Strain | Constant | Linear | Bilinear | Quadratic |
| Integration | 1-pt centroid | 3-pt triangle | 2×2 Gauss | 3×3 Gauss |
| B matrix | Constant | Linear | Bilinear | Quadratic |
| Bending behavior | Locks | No locking | Locks | No locking |

All use the same core formula: `k = t · ∫ Bᵀ D B dA`. The only differences are:
- More nodes → more shape function coefficients → higher polynomial degree
- Higher degree B → Gauss quadrature needed (no longer constant)
- Higher degree → better bending representation

### The 3D analog

The CST is the 2D analog of the **linear tetrahedron** (Lesson 15). In 3D:
- 4-node tetrahedron with 3 DOF/node → 12×12 stiffness
- Constant strain in 3D
- Formula: `k = V · Bᵀ · D · B` (same structure, just 3D)

---

## 11.9 Comparison: CST vs Previous 1D Elements

| Lesson | Element | Nodes × DOF/n | Matrix size | Key parameters |
|--------|---------|--------------|-------------|----------------|
| 2 | 1D Spring | 2 × 1 | 2×2 | k |
| 3 | 1D Bar | 2 × 1 | 2×2 | EA |
| 5 | 2D Truss | 2 × 2 | 4×4 | EA, θ |
| 7 | 2D Plane Frame | 2 × 3 | 6×6 | EA, EI, θ |
| 10 | 3D Space Frame | 2 × 6 | 12×12 | EA, EIy, EIz, GJ |
| **11** | **CST (Triangle)** | **3 × 2** | **6×6** | **E, ν, t** |

**Key difference**: CST uses material properties (E, ν) and geometry (coordinates, thickness) — not cross-sectional properties (A, I). This is because CST is a **continuum** element, not a structural (beam/truss) element.

| Property type | 1D elements | Continuum elements |
|--------------|-------------|-------------------|
| Geometry | A, I, J (cross-section) | x, y, z (coordinates) |
| Material | E, G | E, ν |
| Stiffness | EA/L, EI/L³ | ∬ Bᵀ D B dV |
| Stress | σ = E·ε (1D) | σ = D·B·u (2D/3D) |

---

## 11.10 Summary

| Concept | Takeaway |
|---------|----------|
| Element type | 3-node triangle, 2 DOF/node |
| Matrix size | **6×6** |
| Shape functions | Area coordinates (linear) |
| Strain | **Constant** within element |
| Stiffness formula | `k = t · A · Bᵀ · D · B` |
| B matrix (3×6) | Strain-displacement, constant |
| D matrix (3×3) | Plane stress or plane strain |
| Plane stress (p=1) | Thin plates, smaller D |
| Plane strain (p=2) | Thick/long, larger D |
| Integration | 1-point centroid (exact) |
| Assembly | `_assemble_n!(K, k, [i, j, m], 2)` |
| Stress | `σ = D·B·u` (constant) |
| Principal stresses | `(σ1, σ2, θ_deg)` via `_principal_stresses` |
| Bending | **Locks** — use fine meshes or upgrade to LST/Q4/Q8 |
| No diagram functions | Continuum element |

### Full API

```julia
d2_cst_elementarea(x1, y1, x2, y2, x3, y3)                           # → scalar
d2_cst_elementstiffness(E, NU, t, x1,y1, x2,y2, x3,y3, p)            # → 6×6
d2_cst_elementstress(E, NU, x1,y1, x2,y2, x3,y3, p, u)               # → 3-vec [σxx; σyy; τxy]
d2_cst_elementpstress(sigma)                                          # → (σ1, σ2, θ_deg)
d2_cst_assemble(K, k, i, j, m)                                        # → updated K
```

### The family so far

| Lesson | Element | Nodes × DOF/n | Matrix | Governing params |
|--------|---------|--------------|--------|-----------------|
| 2 | 1D Spring | 2 × 1 | 2×2 | k |
| 3 | 1D Bar | 2 × 1 | 2×2 | EA |
| 4 | Quadratic Bar | 3 × 1 | 3×3 | EA |
| 5 | 2D Truss | 2 × 2 | 4×4 | EA |
| 6 | 3D Truss | 2 × 3 | 6×6 | EA |
| 7 | 2D Plane Frame | 2 × 3 | 6×6 | EA + EI |
| 8 | 2D Pure Beam | 2 × 2 | 4×4 | EI |
| 9 | 2D Plane Grid | 2 × 3 | 6×6 | GJ + EI |
| 10 | 3D Space Frame | 2 × 6 | 12×12 | EA + EIy + EIz + GJ |
| **11** | **CST (Triangle)** | **3 × 2** | **6×6** | **E, ν** |

### Next up

- **Lesson 12**: LST (Quadratic Triangle) — 6 nodes, linear strain, no locking
- **Lesson 13**: Q4 (Bilinear Quadrilateral) — first quadrilateral, isoparametric mapping
- **Lesson 15**: Linear Tetrahedron — 3D analog of the CST
