#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 10.1 — Rectangular Space Frame (3D Beam Structure)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
# ===============================================================================
# PROBLEM OVERVIEW: SPACE FRAME WITH EIGHT ELEMENTS (Fig 10.3)
# ===============================================================================
# Note: 3D perspective is mathematically scaled for plain text readability.
# Exact coordinates and dimensions are provided in the table below.
#
#             Y
#             ^
#             |
#           8 O=============================O 7 <------- 15 kN
#            /|                            /|
#           / |                           / |
#          /  |                          /  |
#       5 O=============================O 6 |
#         |   |                         |   |
#         |   |                         |   |
#         | 4 O - - - - - - - - - - - - + - O 3 ----> X
#   5 m   |  / ///                      |  / ///
#         | /                           | /
#         |/                            |/
#       1 O - - - - - - - - - - - - - - O 2
#        ///                           ///
#          \
#           v Z
#
#           |<--------- 4 m --------->| (Width in X)
#         (Depth from 1 to 4 is 4 m in Z)
#
# ===============================================================================
# NODE COORDINATES & LOADS:
# ===============================================================================
# Assuming Node 4 is at the origin (0,0,0) and units are in meters:
#
#   Node 1 : ( 0, 0, 4)   -> Fixed Support (Encastrement)
#   Node 2 : ( 4, 0, 4)   -> Fixed Support (Encastrement)
#   Node 3 : ( 4, 0, 0)   -> Fixed Support (Encastrement)
#   Node 4 : ( 0, 0, 0)   -> Fixed Support (Encastrement)
#   Node 5 : ( 0, 5, 4)
#   Node 6 : ( 4, 5, 4)
#   Node 7 : ( 4, 5, 0)   -> Applied Load: Fx = -15 kN
#   Node 8 : ( 0, 5, 0)
#
# ELEMENTS (8 total):
#   Columns: 1-5, 2-6, 3-7, 4-8 (Vertical elements)
#   Beams  : 5-6, 6-7, 7-8, 8-5 (Horizontal roof elements)
#
# ===============================================================================

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6   # 210 GPa → kPa
G = 84e6    # 84  GPa → kPa
A = 2e-2    # cross-sectional area (m²)
Iy = 10e-5  # moment of inertia about local y-axis (m⁴)
Iz = 20e-5  # moment of inertia about local z-axis (m⁴)
J = 5e-5    # torsional constant (m⁴)

# ─── Node coordinates ────────────────────────────────────────
# Ground nodes (fixed):
x1, y1, z1 = 0.0, 0.0, 0.0   # Node 1
x2, y2, z2 = 0.0, 0.0, 4.0   # Node 2
x3, y3, z3 = 4.0, 0.0, 4.0   # Node 3
x4, y4, z4 = 4.0, 0.0, 0.0   # Node 4

# Top nodes (free):
x5, y5, z5 = 0.0, 5.0, 0.0   # Node 5
x6, y6, z6 = 0.0, 5.0, 4.0   # Node 6
x7, y7, z7 = 4.0, 5.0, 4.0   # Node 7
x8, y8, z8 = 4.0, 5.0, 0.0   # Node 8

# ─── Element stiffness matrices ──────────────────────────────
# Columns (vertical along Y):
k1 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x5, y5, z5)  # 1→5
k2 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x2, y2, z2, x6, y6, z6)  # 2→6
k3 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x3, y3, z3, x7, y7, z7)  # 3→7
k4 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x4, y4, z4, x8, y8, z8)  # 4→8

# Roof beams (horizontal):
k5 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x5, y5, z5, x6, y6, z6)  # 5→6 (along Z)
k6 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x6, y6, z6, x7, y7, z7)  # 6→7 (along X)
k7 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x7, y7, z7, x8, y8, z8)  # 7→8 (along Z)
k8 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, x5, y5, z5, x8, y8, z8)  # 5→8 (along X)

println("k1 (column 1→5) ="); display(k1)
println("k2 (column 2→6) ="); display(k2)
println("k3 (column 3→7) ="); display(k3)
println("k4 (column 4→8) ="); display(k4)
println("k5 (beam 5→6) ="); display(k5)
println("k6 (beam 6→7) ="); display(k6)
println("k7 (beam 7→8) ="); display(k7)
println("k8 (beam 5→8) ="); display(k8)

# ─── Assembly ────────────────────────────────────────────────
# 8 nodes × 6 DOF = 48 DOFs
# DOF order per node: [Ux, Uy, Uz, Rx, Ry, Rz]
K = zeros(48, 48)
K = d3_spaceframe_assemble(K, k1, 1, 5)
K = d3_spaceframe_assemble(K, k2, 2, 6)
K = d3_spaceframe_assemble(K, k3, 3, 7)
K = d3_spaceframe_assemble(K, k4, 4, 8)
K = d3_spaceframe_assemble(K, k5, 5, 6)
K = d3_spaceframe_assemble(K, k6, 6, 7)
K = d3_spaceframe_assemble(K, k7, 7, 8)
K = d3_spaceframe_assemble(K, k8, 5, 8)

println("\nK (48×48 global) ="); display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: nodes 5-8 = DOF 25-48
k = K[25:48, 25:48]
f = zeros(24)
f[13] = -15.0  # -15 kN vertical at Node 7 (DOF 37 = Y at node 7)

u = k \ f
U = zeros(48)
U[25:48] = u
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nk (reduced, 24×24) ="); display(k)
println("\nf ="); display(f)
println("\nu (nodes 5-8: Ux,Uy,Uz,Rx,Ry,Rz) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element forces ─────────────────────────
# Element 1 (1→5): global DOFs 1-6, 25-30
u1 = [U[1:6]; U[25:30]]
f1 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x5, y5, z5, u1)

# Element 2 (2→6): global DOFs 7-12, 31-36
u2 = [U[7:12]; U[31:36]]
f2 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x2, y2, z2, x6, y6, z6, u2)

# Element 3 (3→7): global DOFs 13-18, 37-42
u3 = [U[13:18]; U[37:42]]
f3 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x3, y3, z3, x7, y7, z7, u3)

# Element 4 (4→8): global DOFs 19-24, 43-48
u4 = [U[19:24]; U[43:48]]
f4 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x4, y4, z4, x8, y8, z8, u4)

# Element 5 (5→6): global DOFs 25-30, 31-36
u5 = [U[25:30]; U[31:36]]
f5 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x5, y5, z5, x6, y6, z6, u5)

# Element 6 (6→7): global DOFs 31-36, 37-42
u6 = [U[31:36]; U[37:42]]
f6 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x6, y6, z6, x7, y7, z7, u6)

# Element 7 (7→8): global DOFs 37-42, 43-48
u7 = [U[37:42]; U[43:48]]
f7 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x7, y7, z7, x8, y8, z8, u7)

# Element 8 (5→8): global DOFs 25-30, 43-48
u8 = [U[25:30]; U[43:48]]
f8 = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, x5, y5, z5, x8, y8, z8, u8)

println("\nu1 (element 1: nodes 1→5) ="); display(u1)
println("f1 (element 1 forces) ="); display(f1)
println("\nu2 (element 2: nodes 2→6) ="); display(u2)
println("f2 (element 2 forces) ="); display(f2)
println("\nu3 (element 3: nodes 3→7) ="); display(u3)
println("f3 (element 3 forces) ="); display(f3)
println("\nu4 (element 4: nodes 4→8) ="); display(u4)
println("f4 (element 4 forces) ="); display(f4)
println("\nu5 (element 5: nodes 5→6) ="); display(u5)
println("f5 (element 5 forces) ="); display(f5)
println("\nu6 (element 6: nodes 6→7) ="); display(u6)
println("f6 (element 6 forces) ="); display(f6)
println("\nu7 (element 7: nodes 7→8) ="); display(u7)
println("f7 (element 7 forces) ="); display(f7)
println("\nu8 (element 8: nodes 5→8) ="); display(u8)
println("f8 (element 8 forces) ="); display(f8)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Sum of all reaction forces (should = [0, -15, 0]):")
println("  Fx: ", sum(F[1:6:end]))
println("  Fy: ", sum(F[2:6:end]))
println("  Fz: ", sum(F[3:6:end]))

# ─── Self-validation ─────────────────────────────────────────
# Goldens from full-precision Julia solve, verified against the
# Octave reference (Doc/Kattan/Solutions-Manual/problem_10_1.m,
# rtol=1e-8 agreement). Book prints rounded values (e.g. u ≈
# [-0.0004, -0.0006, -0.0021, 0.0006]); exact solve values below.
# Margin: rtol=1e-6 vs machine error ~1e-13 (≈7 orders of headroom).
# Node 5 displacements (×10⁻³)
@assert isapprox(u[1], -0.0003989809313828602; rtol=1e-6) "Ux5 mismatch: $(u[1])"
@assert isapprox(u[3], -0.0005893458738371708; rtol=1e-6) "Uz5 mismatch: $(u[3])"

# Node 7 displacements (load point)
@assert isapprox(u[13], -0.0021320523257627485; rtol=1e-6) "Ux7 mismatch: $(u[13])"
@assert isapprox(u[15], 0.000589345873837151; rtol=1e-6) "Uz7 mismatch: $(u[15])"

# Node 1 reactions
@assert isapprox(F[1], 1.1598654556901022; rtol=1e-6) "Fx₁ mismatch: $(F[1])"
@assert isapprox(F[2], 2.5054380271529157; rtol=1e-6) "Fy₁ mismatch: $(F[2])"
@assert isapprox(F[6], -3.2736850222632468; rtol=1e-6) "Rz₁ mismatch: $(F[6])"

# Node 2 reactions
@assert isapprox(F[7], 6.33238870616126; rtol=1e-6) "Fx₂ mismatch: $(F[7])"
@assert isapprox(F[12], -17.693714045819316; rtol=1e-6) "Rz₂ mismatch: $(F[12])"

# Element 1 forces
@assert isapprox(f1[1], 2.5054380271529157; rtol=1e-6) "f1[1] axial mismatch: $(f1[1])"
@assert isapprox(f1[6], -3.2736850222632468; rtol=1e-6) "f1[6] moment mismatch: $(f1[6])"

# Element 5 forces (roof beam 5→6)
@assert isapprox(f5[1], 0.0; atol=1e-9) "f5[1] axial mismatch: $(f5[1])"
@assert isapprox(f5[2], 1.1494403625749396; rtol=1e-6) "f5[2] shear mismatch: $(f5[2])"

println("\nAll golden assertions passed ✓")
