#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 13.1 — Thin Plate with 8 Bilinear Quadrilateral (Q4) Elements
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: DISCRETIZATION OF THIN PLATE (Fig 13.7)
# =============================================================================
# Note: Discretized using 8 Bilinear Quadrilaterals (15 nodes total).
#
#             11             12             13             14             15
#       - //|-O==============O==============O==============O==============O -----> 4.6875 kN
#       ^ //| |              |              |              |              |
# 0.125m| //| |              |              |              |              |
#       v //| |              |              |              |              |
#       - //|-O==============O==============O==============O==============O -----> 9.375 kN
#       ^ //| | 6            | 7            | 8            | 9            | 10
# 0.125m| //| |              |              |              |              |
#       v //| |              |              |              |              |
#       - //|-O==============O==============O==============O==============O -----> 4.6875 kN
#             1              2              3              4              5
#
#             |<-- 0.125m -->|<-- 0.125m -->|<-- 0.125m -->|<-- 0.125m -->|
#
# =============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# =============================================================================
# Assuming Node 1 is at the origin (0,0) and units are in meters:
#
#   Fixed Wall Nodes (x = 0):
#     Node 1  : ( 0.000, 0.000 ) -> Fixed Support (Encastrement)
#     Node 6  : ( 0.000, 0.125 ) -> Fixed Support
#     Node 11 : ( 0.000, 0.250 ) -> Fixed Support
#
#   Loaded Nodes (x = 0.500):
#     Node 5  : ( 0.500, 0.000 ) -> Applied Load: Fx = +4.6875 kN
#     Node 10 : ( 0.500, 0.125 ) -> Applied Load: Fx = +9.3750 kN
#     Node 15 : ( 0.500, 0.250 ) -> Applied Load: Fx = +4.6875 kN
#
#   Internal & Boundary Nodes (Grid dx=0.125, dy=0.125):
#     Row 1 (y=0.000): N2(0.125), N3(0.250), N4(0.375)
#     Row 2 (y=0.125): N7(0.125), N8(0.250), N9(0.375)
#     Row 3 (y=0.250): N12(0.125), N13(0.250), N14(0.375)
#
# ELEMENTS (8 Bilinear Quadrilaterals - 4 nodes per element):
#   Element 1 : Nodes 1, 2, 7, 6
#   Element 2 : Nodes 2, 3, 8, 7
#   ... and so on ...
#
# =============================================================================
# =============================================================================
# Parameters:
#   Material:    E = 210 GPa, ν = 0.3
#   Thickness:   h = 0.025 m
#   Type:        Plane stress (p=1)
#   Loading:     Uniform 37.5 kN/m on right edge (x = 0.5 m), split 1:2:1
#                between corner, mid-edge, corner nodes of each edge
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at all free nodes
#   3. Reactions at fixed nodes 1, 6, 11
#   4. Element stresses (σ_xx, σ_yy, τ_xy) at each element centroid
#   5. Principal stresses at each element centroid
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6   # Young's modulus (kPa)
NU = 0.3    # Poisson's ratio
h = 0.025   # thickness (m)
p = 1       # plane stress

# ─── Node coordinates ────────────────────────────────────────
# 15 nodes, 2 DOF per node. 4 columns × 2 rows of 0.125 × 0.125 Q4s.
# Bottom row (y = 0)
x1,  y1  = 0.0,    0.0      # Node 1  — fixed
x2,  y2  = 0.125,  0.0      # Node 2
x3,  y3  = 0.25,   0.0      # Node 3
x4,  y4  = 0.375,  0.0      # Node 4
x5,  y5  = 0.5,    0.0      # Node 5  — loaded (4.6875 kN)
# Middle row (y = 0.125)
x6,  y6  = 0.0,    0.125    # Node 6  — fixed
x7,  y7  = 0.125,  0.125    # Node 7
x8,  y8  = 0.25,   0.125    # Node 8
x9,  y9  = 0.375,  0.125    # Node 9
x10, y10 = 0.5,    0.125    # Node 10 — loaded (9.375 kN)
# Top row (y = 0.25)
x11, y11 = 0.0,    0.25     # Node 11 — fixed
x12, y12 = 0.125,  0.25     # Node 12
x13, y13 = 0.25,   0.25     # Node 13
x14, y14 = 0.375,  0.25     # Node 14
x15, y15 = 0.5,    0.25     # Node 15 — loaded (4.6875 kN)

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_q4_elementstiffness(E, NU, h, x1, y1, x2, y2, x7, y7, x6, y6, p)   # 1-2-7-6
k2 = d2_q4_elementstiffness(E, NU, h, x2, y2, x3, y3, x8, y8, x7, y7, p)   # 2-3-8-7
k3 = d2_q4_elementstiffness(E, NU, h, x3, y3, x4, y4, x9, y9, x8, y8, p)   # 3-4-9-8
k4 = d2_q4_elementstiffness(E, NU, h, x4, y4, x5, y5, x10, y10, x9, y9, p) # 4-5-10-9
k5 = d2_q4_elementstiffness(E, NU, h, x6, y6, x7, y7, x12, y12, x11, y11, p) # 6-7-12-11
k6 = d2_q4_elementstiffness(E, NU, h, x7, y7, x8, y8, x13, y13, x12, y12, p) # 7-8-13-12
k7 = d2_q4_elementstiffness(E, NU, h, x8, y8, x9, y9, x14, y14, x13, y13, p) # 8-9-14-13
k8 = d2_q4_elementstiffness(E, NU, h, x9, y9, x10, y10, x15, y15, x14, y14, p) # 9-10-15-14

println("k1 ="); display(k1)
println("k8 ="); display(k8)

# ─── Assembly ────────────────────────────────────────────────
# 15 nodes × 2 DOF = 30 DOFs
K = zeros(30, 30)
K = d2_q4_assemble(K, k1, 1, 2, 7, 6)
K = d2_q4_assemble(K, k2, 2, 3, 8, 7)
K = d2_q4_assemble(K, k3, 3, 4, 9, 8)
K = d2_q4_assemble(K, k4, 4, 5, 10, 9)
K = d2_q4_assemble(K, k5, 6, 7, 12, 11)
K = d2_q4_assemble(K, k6, 7, 8, 13, 12)
K = d2_q4_assemble(K, k7, 8, 9, 14, 13)
K = d2_q4_assemble(K, k8, 9, 10, 15, 14)

# ─── Solve ───────────────────────────────────────────────────
# Fixed DOFs: nodes 1, 6, 11 → DOFs 1:2, 11:12, 21:22
# Free DOFs:  nodes 2-5 (3:10), 7-10 (13:20), 12-15 (23:30)
# Block-ordered reduction [3:10, 13:20, 23:30] — matches Kattan's MATLAB
free = [3:10; 13:20; 23:30]
k = K[free, free]
f = zeros(24)
f[7]  = 4.6875  # node 5,  Fx
f[15] = 9.375   # node 10, Fx
f[23] = 4.6875  # node 15, Fx

u = k \ f
U = zeros(30)
U[3:10]  = u[1:8]
U[13:20] = u[9:16]
U[23:30] = u[17:24]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nu (free DOFs, block order) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (1-2-7-6): global DOFs 1,2  3,4  13,14  11,12
u1 = [U[1]; U[2]; U[3]; U[4]; U[13]; U[14]; U[11]; U[12]]
sig1 = d2_q4_elementstress(E, NU, x1, y1, x2, y2, x7, y7, x6, y6, p, u1)

# Element 2 (2-3-8-7): global DOFs 3,4  5,6  15,16  13,14
u2 = [U[3]; U[4]; U[5]; U[6]; U[15]; U[16]; U[13]; U[14]]
sig2 = d2_q4_elementstress(E, NU, x2, y2, x3, y3, x8, y8, x7, y7, p, u2)

# Element 3 (3-4-9-8): global DOFs 5,6  7,8  17,18  15,16
u3 = [U[5]; U[6]; U[7]; U[8]; U[17]; U[18]; U[15]; U[16]]
sig3 = d2_q4_elementstress(E, NU, x3, y3, x4, y4, x9, y9, x8, y8, p, u3)

# Element 4 (4-5-10-9): global DOFs 7,8  9,10  19,20  17,18
u4 = [U[7]; U[8]; U[9]; U[10]; U[19]; U[20]; U[17]; U[18]]
sig4 = d2_q4_elementstress(E, NU, x4, y4, x5, y5, x10, y10, x9, y9, p, u4)

# Element 5 (6-7-12-11): global DOFs 11,12  13,14  23,24  21,22
u5 = [U[11]; U[12]; U[13]; U[14]; U[23]; U[24]; U[21]; U[22]]
sig5 = d2_q4_elementstress(E, NU, x6, y6, x7, y7, x12, y12, x11, y11, p, u5)

# Element 6 (7-8-13-12): global DOFs 13,14  15,16  25,26  23,24
u6 = [U[13]; U[14]; U[15]; U[16]; U[25]; U[26]; U[23]; U[24]]
sig6 = d2_q4_elementstress(E, NU, x7, y7, x8, y8, x13, y13, x12, y12, p, u6)

# Element 7 (8-9-14-13): global DOFs 15,16  17,18  27,28  25,26
u7 = [U[15]; U[16]; U[17]; U[18]; U[27]; U[28]; U[25]; U[26]]
sig7 = d2_q4_elementstress(E, NU, x8, y8, x9, y9, x14, y14, x13, y13, p, u7)

# Element 8 (9-10-15-14): global DOFs 17,18  19,20  29,30  27,28
u8 = [U[17]; U[18]; U[19]; U[20]; U[29]; U[30]; U[27]; U[28]]
sig8 = d2_q4_elementstress(E, NU, x9, y9, x10, y10, x15, y15, x14, y14, p, u8)

# Principal stresses
s1 = d2_q4_elementpstress(sig1)
s2 = d2_q4_elementpstress(sig2)
s3 = d2_q4_elementpstress(sig3)
s4 = d2_q4_elementpstress(sig4)
s5 = d2_q4_elementpstress(sig5)
s6 = d2_q4_elementpstress(sig6)
s7 = d2_q4_elementpstress(sig7)
s8 = d2_q4_elementpstress(sig8)

println("\nσ1 = $sig1 ; s1 = $s1")
println("σ2 = $sig2 ; s2 = $s2")
println("σ3 = $sig3 ; s3 = $s3")
println("σ4 = $sig4 ; s4 = $s4")
println("σ5 = $sig5 ; s5 = $s5")
println("σ6 = $sig6 ; s6 = $s6")
println("σ7 = $sig7 ; s7 = $s7")
println("σ8 = $sig8 ; s8 = $s8")

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Sum Fx: $(sum(F[1:2:end])) (should ≈ 0)")
println("Sum Fy: $(sum(F[2:2:end])) (should = 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from the Solutions Manual problem_13_1.m run under Octave
# (Symbolic pkg v3.2.2, SymPy 1.14.0) — see Doc/Kattan/Solutions-Manual/
# Node 2 displacements (m)
@assert isapprox(u[1], 1.7679e-6; rtol=1e-2) "Ux2 mismatch: $(u[1])"
@assert isapprox(u[2], 5.5217e-7; rtol=1e-2) "Uy2 mismatch: $(u[2])"

# Node 3 displacements (m)
@assert isapprox(u[3], 3.4997e-6; rtol=1e-2) "Ux3 mismatch: $(u[3])"
@assert isapprox(u[4], 5.4773e-7; rtol=1e-2) "Uy3 mismatch: $(u[4])"

# Node 4 displacements (m)
@assert isapprox(u[5], 5.2841e-6; rtol=1e-2) "Ux4 mismatch: $(u[5])"
@assert isapprox(u[6], 5.3580e-7; rtol=1e-2) "Uy4 mismatch: $(u[6])"

# Node 5 displacements (m) — max x-displacement (bottom-right)
@assert isapprox(u[7], 7.0706e-6; rtol=1e-2) "Ux5 mismatch: $(u[7])"
@assert isapprox(u[8], 5.3505e-7; rtol=1e-2) "Uy5 mismatch: $(u[8])"

# Mid-row symmetry: Uy at x = 0.25 must vanish
@assert isapprox(u[10], 0.0; atol=1e-10) "Uy8 mismatch: $(u[10])"
@assert isapprox(u[14], 0.0; atol=1e-10) "Uy13 mismatch: $(u[14])"

# Top-row mirror of bottom row (Uy sign flip)
@assert isapprox(u[17], 1.7679e-6; rtol=1e-2) "Ux12 mismatch: $(u[17])"
@assert isapprox(u[18], -5.5217e-7; rtol=1e-2) "Uy12 mismatch: $(u[18])"
@assert isapprox(u[23], 7.0706e-6; rtol=1e-2) "Ux15 mismatch: $(u[23])"
@assert isapprox(u[24], -5.3505e-7; rtol=1e-2) "Uy15 mismatch: $(u[24])"

# Reactions at fixed nodes 1, 6, 11
@assert isapprox(F[1], -4.9836; rtol=1e-2) "Fx1 mismatch: $(F[1])"
@assert isapprox(F[2], -1.2580; rtol=1e-2) "Fy1 mismatch: $(F[2])"
@assert isapprox(F[11], -8.7829; rtol=1e-2) "Fx6 mismatch: $(F[11])"
@assert isapprox(F[21], -4.9836; rtol=1e-2) "Fx11 mismatch: $(F[21])"
@assert isapprox(F[22], 1.2580; rtol=1e-2) "Fy11 mismatch: $(F[22])"

# Element 1 stresses (bottom-left)
@assert isapprox(sig1[1], 3000.0; rtol=1e-2) "σxx1 mismatch: $(sig1[1])"
@assert isapprox(sig1[2], 436.2; rtol=1e-2) "σyy1 mismatch: $(sig1[2])"
@assert isapprox(sig1[3], 139.6; rtol=1e-2) "τxy1 mismatch: $(sig1[3])"

# Element 2 stresses
@assert isapprox(sig2[1], 3000.0; rtol=1e-2) "σxx2 mismatch: $(sig2[1])"
@assert isapprox(sig2[2], -23.92; rtol=1e-2) "σyy2 mismatch: $(sig2[2])"
@assert isapprox(sig2[3], -41.44; rtol=1e-2) "τxy2 mismatch: $(sig2[3])"

# Element 3 stresses
@assert isapprox(sig3[1], 3000.0; rtol=1e-2) "σxx3 mismatch: $(sig3[1])"
@assert isapprox(sig3[2], -10.17; rtol=1e-2) "σyy3 mismatch: $(sig3[2])"
@assert isapprox(sig3[3], -4.235; rtol=1e-2) "τxy3 mismatch: $(sig3[3])"

# Element 4 stresses (bottom-right)
@assert isapprox(sig4[1], 3000.0; rtol=1e-2) "σxx4 mismatch: $(sig4[1])"
@assert isapprox(sig4[2], 0.4880; rtol=1e-2) "σyy4 mismatch: $(sig4[2])"
@assert isapprox(sig4[3], 0.8013; rtol=1e-2) "τxy4 mismatch: $(sig4[3])"

# Element 5 stresses (top-left) — mirror of e1 with τxy sign flip
@assert isapprox(sig5[1], 3000.0; rtol=1e-2) "σxx5 mismatch: $(sig5[1])"
@assert isapprox(sig5[2], 436.2; rtol=1e-2) "σyy5 mismatch: $(sig5[2])"
@assert isapprox(sig5[3], -139.6; rtol=1e-2) "τxy5 mismatch: $(sig5[3])"

# Element 6 stresses
@assert isapprox(sig6[1], 3000.0; rtol=1e-2) "σxx6 mismatch: $(sig6[1])"
@assert isapprox(sig6[2], -23.92; rtol=1e-2) "σyy6 mismatch: $(sig6[2])"
@assert isapprox(sig6[3], 41.44; rtol=1e-2) "τxy6 mismatch: $(sig6[3])"

# Element 7 stresses
@assert isapprox(sig7[1], 3000.0; rtol=1e-2) "σxx7 mismatch: $(sig7[1])"
@assert isapprox(sig7[2], -10.17; rtol=1e-2) "σyy7 mismatch: $(sig7[2])"
@assert isapprox(sig7[3], 4.235; rtol=1e-2) "τxy7 mismatch: $(sig7[3])"

# Element 8 stresses (top-right) — mirror of e4 with τxy sign flip
@assert isapprox(sig8[1], 3000.0; rtol=1e-2) "σxx8 mismatch: $(sig8[1])"
@assert isapprox(sig8[2], 0.4880; rtol=1e-2) "σyy8 mismatch: $(sig8[2])"
@assert isapprox(sig8[3], -0.8013; rtol=1e-2) "τxy8 mismatch: $(sig8[3])"

println("\nAll golden assertions passed ✓")
