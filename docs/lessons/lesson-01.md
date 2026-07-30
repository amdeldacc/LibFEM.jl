# Lesson 1: What is FEM? — The Finite Element Method & The 6-Step Recipe

> Based on Kattan, *MATLAB Guide to Finite Elements* (2nd ed., Springer 2007), Chapter 1
> Mapped to LibFEM.jl — an educational FEM library in Julia

---

## 1.1 The Big Idea

**Finite Element Method (FEM)** = break a big, complicated structure into small, simple pieces ("elements"), solve each piece individually, then glue them back together.

Think of it like building with LEGO:

| Concept | What it means |
|---------|--------------|
| **Element** | One LEGO brick — a simple piece with known behavior |
| **Node** | The studs where bricks connect — points where elements meet |
| **Stiffness matrix [k]** | The "rule book" for how that brick deforms when pushed |
| **Assembly** | Snapping bricks together at shared studs — combining element rules into a system-wide rule book |
| **Global stiffness matrix [K]** | The combined rule book for the whole structure |

### Why FEM?

Real structures (bridges, airplane wings, bones) have **continuous** geometry — infinite points. FEM approximates them with **finite** pieces, turning a calculus problem (differential equations) into a linear algebra problem (matrix equations) that computers solve easily.

---

## 1.2 The Universal 6-Step Recipe

Every FEM problem in Kattan's book — from a 1D spring to a 3D brick element — follows this exact sequence:

| Step | Action | Tool | Who does it |
|------|--------|------|-------------|
| **1** | **Discretize** — cut the domain into elements and nodes | Pen & paper | Engineer |
| **2** | **Element matrices** — compute stiffness matrix for each element | MATLAB/Julia function | Code |
| **3** | **Assemble** — combine all element matrices into a global matrix | Direct stiffness method | Code |
| **4** | **Boundary conditions** — identify fixed nodes and applied loads | Manual reasoning | Engineer |
| **5** | **Solve** — partition equations, solve for unknown displacements | Gaussian elimination (`\`) | Code |
| **6** | **Post-process** — compute forces, stresses, strains from displacements | MATLAB/Julia function | Code |

> **Rule of thumb**: Steps 1 and 4 require engineering judgment. Steps 2, 3, 5, 6 are mechanical — let the computer do them.

---

## 1.3 The Core Equation

At the heart of every structural FEM problem is this equation:

```
[K] {U} = {F}
```

| Symbol | Meaning | Size |
|--------|---------|------|
| [K] | Global stiffness matrix | N×N (N = total DOFs) |
| {U} | Nodal displacements (unknowns) | N×1 |
| {F} | Nodal forces (known loads + reactions) | N×1 |

### What it means: "Push a node, everything moves according to the combined stiffness."

---

## 1.4 DOF Convention (Degrees of Freedom)

**DOF** = the unknown quantity at each node. It depends on the element type:

| Element type | DOF per node | What it represents |
|-------------|-------------|-------------------|
| Spring, Bar | 1 | Displacement u (along axis) |
| 2D Truss | 2 | UX, UY (horizontal, vertical displacement) |
| Beam | 2 | UY, RZ (vertical displacement, rotation) |
| Plane Frame | 3 | UX, UY, RZ |
| 3D Truss / Brick | 3 | UX, UY, UZ |
| 3D Space Frame | 6 | UX, UY, UZ, RX, RY, RZ |
| Heat Transfer | 1 | Temperature T |

**DOF-to-global-slot mapping**: Node `n` occupies slots `[DOF_per_node × (n−1) + 1 : DOF_per_node × n]`

---

## 1.5 The General Stiffness Formula

Every structural element stiffness matrix comes from the same integral:

```
[k] = ∫ [B]ᵀ [D] [B] dV
```

| Symbol | Meaning |
|--------|---------|
| [B] | Strain-displacement matrix — relates nodal displacements to strains |
| [D] | Elasticity/constitutive matrix — relates stress to strain (material properties: E, ν) |
| dV | Volume integral (area × thickness for 2D, length × area for 1D) |

For **thermal** problems, it's the same formula but [D] = k·I (thermal conductivity).

You won't need to evaluate this integral by hand for basic elements — Kattan gives you the formulas. For 1D elements it's just arithmetic.

---

## 1.6 What's Coming

The remaining lessons build from simplest to most complex:

| Lesson | Element | DOF per node | Matrix size | New concept |
|--------|---------|-------------|-------------|-------------|
| 2 | Spring | 1 | 2×2 | First matrix, assembly |
| 3 | Linear Bar | 1 | 2×2 | Material properties (E, A, L) |
| 4 | Quadratic Bar | 1 | 3×3 | 3-node 1D element |
| 5 | 2D Truss | 2 | 4×4 | Coordinate transformation |
| 6 | 3D Truss | 3 | 6×6 | 3D direction cosines |
| 7 | Beam | 2 | 4×4 | Bending, rotations |
| 8 | Plane Frame | 3 | 6×6 | Axial + bending combined |

Each lesson follows the **same 6-step pattern**. Learn it once, apply everywhere.

---

## Quick Vocabulary

| Term | Definition |
|------|------------|
| **Element** | A finite region with defined shape, nodes, and interpolation functions |
| **Node** | A point where elements connect and unknowns are defined |
| **Stiffness matrix [k]** | Local matrix relating forces to displacements for one element |
| **Global matrix [K]** | System-wide assembled matrix for all elements |
| **Assembly** | Adding element matrices into the global matrix at matching node positions |
| **DOF** | Degree of Freedom — unknown quantity at a node (displacement, rotation, temperature) |
| **BCs** | Boundary conditions — prescribed displacements or applied forces |
| **Post-processing** | Computing derived quantities (stresses, reactions) from solved displacements |
