# Space Frame (3D Beam) Element - d3_beam

## Overview

The space frame (3D beam) element models a straight structural member in three-dimensional space that resists axial, bending, and torsional loads. Each node has 6 degrees of freedom (three translations and three rotations), producing a 12x12 stiffness matrix. This element follows Euler-Bernoulli beam theory for bending and uses a local-to-global coordinate transformation to orient the element arbitrarily in space.

The element stiffness is first computed in the local (primal) coordinate system aligned with the element axis. A 3x3 rotation matrix Lambda, built from the nodal coordinates, transforms local forces and displacements to the global coordinate system. The full 12x12 rotation matrix is block-diagonal: `R = diag(Lambda, Lambda, Lambda, Lambda)`. The global stiffness is `K_global = R^T * k_prime * R`, and element forces are computed as `f = k_prime * R * u`.

## Function Reference

### `_d3_beam_kprime(E, G, A, Iy, Iz, J, L)` (private)

Compute the 12x12 local (primal) stiffness matrix for a 3D beam element in its local coordinate system.

**Arguments:**

| Arg | Type | Description |
|-----|------|-------------|
| `E` | `Real` | Modulus of elasticity |
| `G` | `Real` | Shear modulus |
| `A` | `Real` | Cross-sectional area |
| `Iy` | `Real` | Moment of inertia about the local y-axis |
| `Iz` | `Real` | Moment of inertia about the local z-axis |
| `J` | `Real` | Torsional constant |
| `L` | `Real` | Element length |

**Returns:** `Matrix{Float64}` (12x12)

**Note:** This is a private helper (underscore-prefixed, not exported). It is called internally by `d3_beam_elementstiffness` and `d3_beam_elementforces`.

---

### `d3_beam_elementlength(x1, y1, z1, x2, y2, z2)`

Return the length of a space frame element given the coordinates of its two nodes.

```julia
function d3_beam_elementlength(
    x1::Real, y1::Real, z1::Real,
    x2::Real, y2::Real, z2::Real,
) -> Float64
```

**Arguments:**

| Arg | Type | Description |
|-----|------|-------------|
| `x1, y1, z1` | `Real` | Coordinates of the first node |
| `x2, y2, z2` | `Real` | Coordinates of the second node |

**Returns:** `Float64` - the Euclidean distance between the two nodes.

---

### `d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)`

Return the 12x12 element stiffness matrix for a space frame element. Computes the local stiffness via `_d3_beam_kprime`, builds the rotation matrix Lambda from the nodal coordinates, and transforms to global coordinates as `R^T * k_prime * R`.

```julia
function d3_beam_elementstiffness(
    E::Real, G::Real, A::Real,
    Iy::Real, Iz::Real, J::Real,
    x1::Real, y1::Real, z1::Real,
    x2::Real, y2::Real, z2::Real,
) -> Matrix{Float64}
```

**Arguments:**

| Arg | Type | Description |
|-----|------|-------------|
| `E` | `Real` | Modulus of elasticity |
| `G` | `Real` | Shear modulus |
| `A` | `Real` | Cross-sectional area |
| `Iy` | `Real` | Moment of inertia about the local y-axis |
| `Iz` | `Real` | Moment of inertia about the local z-axis |
| `J` | `Real` | Torsional constant |
| `x1, y1, z1` | `Real` | Coordinates of the first node |
| `x2, y2, z2` | `Real` | Coordinates of the second node |

**Returns:** `Matrix{Float64}` (12x12) - the element stiffness matrix in the global coordinate system.

---

### `d3_beam_assemble(K, k, i, j)`

Assemble a 12x12 element stiffness matrix `k` for element with nodes `i` and `j` into the global stiffness matrix `K`. Delegates to the private `_assemble!` helper with `dofs=6`.

```julia
function d3_beam_assemble(
    K::AbstractMatrix,
    k::AbstractMatrix,
    i::Integer,
    j::Integer,
) -> Matrix
```

**Arguments:**

| Arg | Type | Description |
|-----|------|-------------|
| `K` | `AbstractMatrix` | Global stiffness matrix (modified in place) |
| `k` | `AbstractMatrix` | Element stiffness matrix (12x12) |
| `i` | `Integer` | Global index of the first node |
| `j` | `Integer` | Global index of the second node |

**Returns:** `Matrix` - the global stiffness matrix `K` after assembly (same object, modified in place).

---

### `d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)`

Return the 12-element element nodal force vector in the global coordinate system. Computes `f = k_prime * R * u`, where `k_prime` is the local stiffness matrix and `R` is the block-diagonal rotation matrix.

```julia
function d3_beam_elementforces(
    E::Real, G::Real, A::Real,
    Iy::Real, Iz::Real, J::Real,
    x1::Real, y1::Real, z1::Real,
    x2::Real, y2::Real, z2::Real,
    u::AbstractVector,
) -> Vector{Float64}
```

**Arguments:**

| Arg | Type | Description |
|-----|------|-------------|
| `E` | `Real` | Modulus of elasticity |
| `G` | `Real` | Shear modulus |
| `A` | `Real` | Cross-sectional area |
| `Iy` | `Real` | Moment of inertia about the local y-axis |
| `Iz` | `Real` | Moment of inertia about the local z-axis |
| `J` | `Real` | Torsional constant |
| `x1, y1, z1` | `Real` | Coordinates of the first node |
| `x2, y2, z2` | `Real` | Coordinates of the second node |
| `u` | `AbstractVector` | Element nodal displacement vector (12 elements) |

**Returns:** `Vector{Float64}` (12 elements) - the element force vector in the global coordinate system.

---

### `d3_beam_elementaxialdiagram(f, L)`

Plot and return the axial force diagram for a space frame element.

```julia
function d3_beam_elementaxialdiagram(f::AbstractVector, L::Real) -> Plots.Plot
```

Uses `z = [-f[1], f[7]]` over `x = [0, L]`. The axial force at node 1 is `-f[1]` and at node 2 is `f[7]`.

**Arguments:**

| Arg | Type | Description |
|-----|------|-------------|
| `f` | `AbstractVector` | Element nodal force vector (12 elements) |
| `L` | `Real` | Element length |

**Returns:** `Plots.Plot` - a Plot object with title "Axial Force Diagram".

---

### `d3_beam_elementshearydiagram(f, L)`

Plot and return the shear force Y diagram (shear in the local y-direction).

```julia
function d3_beam_elementshearydiagram(f::AbstractVector, L::Real) -> Plots.Plot
```

Uses `z = [f[2], -f[8]]` over `x = [0, L]`. The shear force at node 1 is `f[2]` and at node 2 is `-f[8]`.

**Returns:** `Plots.Plot` with title "Shear Force Y Diagram".

---

### `d3_beam_elementshearzdiagram(f, L)`

Plot and return the shear force Z diagram (shear in the local z-direction).

```julia
function d3_beam_elementshearzdiagram(f::AbstractVector, L::Real) -> Plots.Plot
```

Uses `z = [f[3], -f[9]]` over `x = [0, L]`. The shear force at node 1 is `f[3]` and at node 2 is `-f[9]`.

**Returns:** `Plots.Plot` with title "Shear Force Z Diagram".

---

### `d3_beam_elementmomentydiagram(f, L)`

Plot and return the bending moment Y diagram (moment about the local y-axis).

```julia
function d3_beam_elementmomentydiagram(f::AbstractVector, L::Real) -> Plots.Plot
```

Uses `z = [f[5], -f[11]]` over `x = [0, L]`. The moment at node 1 is `f[5]` and at node 2 is `-f[11]`.

**Returns:** `Plots.Plot` with title "Bending Moment Y Diagram".

---

### `d3_beam_elementmomentzdiagram(f, L)`

Plot and return the bending moment Z diagram (moment about the local z-axis).

```julia
function d3_beam_elementmomentzdiagram(f::AbstractVector, L::Real) -> Plots.Plot
```

Uses `z = [f[6], -f[12]]` over `x = [0, L]`. The moment at node 1 is `f[6]` and at node 2 is `-f[12]`.

**Returns:** `Plots.Plot` with title "Bending Moment Z Diagram".

---

### `d3_beam_elementtorsiondiagram(f, L)`

Plot and return the torsion diagram (torque about the element x-axis).

```julia
function d3_beam_elementtorsiondiagram(f::AbstractVector, L::Real) -> Plots.Plot
```

Uses `z = [f[4], -f[10]]` over `x = [0, L]`. The torque at node 1 is `f[4]` and at node 2 is `-f[10]`.

**Returns:** `Plots.Plot` with title "Torsion Diagram".

## DOF Ordering

The 12 degrees of freedom are ordered as follows:

| Index | Node | DOF | Description |
|-------|------|-----|-------------|
| 1 | 1 | `delta_x1` | Translation in x at node 1 |
| 2 | 1 | `delta_y1` | Translation in y at node 1 |
| 3 | 1 | `delta_z1` | Translation in z at node 1 |
| 4 | 1 | `theta_x1` | Rotation about x at node 1 |
| 5 | 1 | `theta_y1` | Rotation about y at node 1 |
| 6 | 1 | `theta_z1` | Rotation about z at node 1 |
| 7 | 2 | `delta_x2` | Translation in x at node 2 |
| 8 | 2 | `delta_y2` | Translation in y at node 2 |
| 9 | 2 | `delta_z2` | Translation in z at node 2 |
| 10 | 2 | `theta_x2` | Rotation about x at node 2 |
| 11 | 2 | `theta_y2` | Rotation about y at node 2 |
| 12 | 2 | `theta_z2` | Rotation about z at node 2 |

Full 12-element vector: `[delta_x1, delta_y1, delta_z1, theta_x1, theta_y1, theta_z1, delta_x2, delta_y2, delta_z2, theta_x2, theta_y2, theta_z2]`

This ordering matches the rows and columns of the local stiffness matrix `k_prime` and the force vector `f`.

## Usage Example

```julia
using LibFEM

# Element properties
E = 3e10   # Young's modulus (Pa)
G = 1.15e8  # Shear modulus (Pa)
A = 0.01    # Cross-sectional area (m^2)
Iy = 1e-4   # Moment of inertia about y (m^4)
Iz = 2e-4   # Moment of inertia about z (m^4)
J = 1e-5    # Torsional constant (m^4)

# Nodes at (0,0,0) and (4,0,0)
x1, y1, z1 = 0, 0, 0
x2, y2, z2 = 4, 0, 0

# Stiffness matrix
k = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)

# Assemble into global matrix
K = zeros(12, 12)
d3_beam_assemble(K, k, 1, 2)

# Element forces (u = nodal displacement vector)
u = zeros(12)
u[1] = 0.001  # 1 mm axial displacement at node 1
f = d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)

# Plot diagrams
d3_beam_elementaxialdiagram(f, 4)
d3_beam_elementmomentydiagram(f, 4)
d3_beam_elementtorsiondiagram(f, 4)
```

## Coordinate Transformation

The element is defined in a local coordinate system where the x-axis runs along the element from node 1 to node 2. The transformation to global coordinates uses a 3x3 rotation matrix Lambda built from the direction cosines:

```
Cx = (x2 - x1) / L
Cy = (y2 - y1) / L
Cz = (z2 - z1) / L
```

For a general orientation (non-vertical element, i.e. `x1 != x2` or `y1 != y2`), the auxiliary term `D = sqrt(Cx^2 + Cy^2)` is computed and Lambda is:

```
Lambda = [  Cx           Cy           Cz
           -Cy/D        Cx/D         0
           -Cx*Cz/D    -Cy*Cz/D      D     ]
```

For vertical elements (`x1 == x2 && y1 == y2`), the standard formula would divide by zero (`D = 0`). A special case is used instead:

- If `z2 > z1` (element pointing up):
  ```
  Lambda = [ 0  0  1
             0  1  0
            -1  0  0 ]
  ```
- If `z2 < z1` (element pointing down):
  ```
  Lambda = [ 0  0 -1
             0  1  0
             1  0  0 ]
  ```

The full 12x12 rotation matrix is block-diagonal with Lambda on each block:

```
R = [ Lambda   0        0        0
      0        Lambda   0        0
      0        0        Lambda   0
      0        0        0        Lambda ]
```

The transformation rules are:

- **Global stiffness matrix**: `K_global = R^T * k_prime * R`
- **Element force vector**: `f = k_prime * R * u`

## MATLAB Reference

These functions are based on MATLAB code from Peter Kattan's "MATLAB Guide to Finite Elements, An Interactive Approach" (2nd ed.). The naming convention maps `SpaceFrame{Operation}` in MATLAB to `d3_beam_{operation}` in LibFEM.jl.

| LibFEM.jl | MATLAB file | Purpose |
|-----------|-------------|---------|
| `d3_beam_elementlength` | `SpaceFrameElementLength.m` | Element length |
| `d3_beam_elementstiffness` | `SpaceFrameElementStiffness.m` | 12x12 stiffness matrix |
| `d3_beam_assemble` | `SpaceFrameAssemble.m` | Assembly into global matrix |
| `d3_beam_elementforces` | `SpaceFrameElementForces.m` | Element force vector |
| `d3_beam_elementaxialdiagram` | `SpaceFrameElementAxialDiagram.m` | Axial force diagram |
| `d3_beam_elementshearydiagram` | `SpaceFrameElementShearYDiagram.m` | Shear force Y diagram |
| `d3_beam_elementshearzdiagram` | `SpaceFrameElementShearZDiagram.m` | Shear force Z diagram |
| `d3_beam_elementmomentydiagram` | `SpaceFrameElementMomentYDiagram.m` | Bending moment Y diagram |
| `d3_beam_elementmomentzdiagram` | `SpaceFrameElementMomentZDiagram.m` | Bending moment Z diagram |
| `d3_beam_elementtorsiondiagram` | `SpaceFrameElementTorsionDiagram.m` | Torsion diagram |

The internal helper `_d3_beam_kprime` corresponds to the local stiffness matrix computation inside `SpaceFrameElementStiffness.m` (lines 24-35 of the MATLAB source), implementing the standard 3D beam stiffness formulation with axial, bending, torsional, and shear coupling terms.
