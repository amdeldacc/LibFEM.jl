#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 13.2 — Thin Plate with a Central Hole and 8 Bilinear
#               Quadrilateral (Q4) Elements
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: DISCRETIZATION OF THIN PLATE WITH A HOLE (Fig 13.9)
# =============================================================================
# Note: Discretized using 8 Bilinear Quadrilaterals (16 nodes total).
#       The central element (nodes 6, 7, 11, 10) is a hole (void).
#
#             13             14             15             16
#       - //|-O==============O==============O==============O
#       ^ //| |              |              |              |
# 0.3 m | //| |              |   ( HOLE )   |              |        |
#       v //| |              |              |              |        v
#       - //|-O==============O==============O==============O ------> 20 kN
#       ^ //| | 9            | 10           | 11           | 12
# 0.3 m | //| |              |              |              |
#       v //| |              |              |              |
#       - //|-O==============O==============O==============O
#       ^ //| | 5            | 6            | 7            | 8
# 0.3 m | //| |              |              |              |
#       v //| |              |              |              |
#       - //|-O==============O==============O==============O
#             1              2              3              4
#
#             |<--- 0.3 m -->|<--- 0.3 m -->|<--- 0.3 m -->|
#
# =============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# =============================================================================
# Assuming Node 1 is at the origin (0,0) and units are in meters:
#
#   Fixed Wall Nodes (x = 0):
#     Node 1  : ( 0.000, 0.000 ) -> Fixed Support (Encastrement)
#     Node 5  : ( 0.000, 0.300 ) -> Fixed Support
#     Node 9  : ( 0.000, 0.600 ) -> Fixed Support
#     Node 13 : ( 0.000, 0.900 ) -> Fixed Support
#
#   Loaded Node (x = 0.900, y = 0.900):
#     Node 16 : ( 0.900, 0.900 ) -> Applied Load: Fy = -20 kN
#
#   Internal & Boundary Nodes (Grid dx=0.3, dy=0.3):
#     Row 1 (y=0.000): N2(0.300, 0.000), N3(0.600, 0.000), N4(0.900, 0.000)
#     Row 2 (y=0.300): N6(0.300, 0.300), N7(0.600, 0.300), N8(0.900, 0.300)
#     Row 3 (y=0.600): N10(0.300, 0.600), N11(0.600, 0.600), N12(0.900, 0.600)
#     Row 4 (y=0.900): N14(0.300, 0.900), N15(0.600, 0.900)
#
# ELEMENTS (8 Bilinear Quadrilaterals - 4 nodes per element):
#   Element 1 : Nodes 1, 2, 6, 5
#   Element 2 : Nodes 2, 3, 7, 6
#   Element 3 : Nodes 3, 4, 8, 7
#   Element 4 : Nodes 5, 6, 10, 9
#   [ NO ELEMENT HERE - HOLE between nodes 6, 7, 11, 10 ]
#   Element 5 : Nodes 7, 8, 12, 11
#   Element 6 : Nodes 9, 10, 14, 13
#   Element 7 : Nodes 10, 11, 15, 14
#   Element 8 : Nodes 11, 12, 16, 15
#
# =============================================================================
# =============================================================================
# Parameters:
#   Material:    E = 70 GPa, ν = 0.25
#   Thickness:   h = 0.02 m
#   Type:        Plane stress (p=1)
#   Loading:     Downward point load of 20 kN at node 16 (0.9 m, 0.9 m),
#                top-right corner
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at all free nodes
#   3. Reactions at fixed nodes 1, 5, 9, 13
#   4. Element stresses (σ_xx, σ_yy, τ_xy) at each element centroid
#   5. Principal stresses at each element centroid
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 70e6   # Young's modulus (kPa)
NU = 0.25  # Poisson's ratio
h = 0.02   # thickness (m)
p = 1      # plane stress

# ─── Node coordinates ────────────────────────────────────────
# 16 nodes, 2 DOF per node. 3 columns × 3 rows of 0.3 × 0.3 Q4s
# with the central element removed (hole).
# Bottom row (y = 0)
x1,  y1  = 0.0,    0.0      # Node 1  — fixed
x2,  y2  = 0.3,    0.0      # Node 2
x3,  y3  = 0.6,    0.0      # Node 3
x4,  y4  = 0.9,    0.0      # Node 4
# Row 2 (y = 0.3)
x5,  y5  = 0.0,    0.3      # Node 5  — fixed
x6,  y6  = 0.3,    0.3      # Node 6  — hole corner
x7,  y7  = 0.6,    0.3      # Node 7  — hole corner
x8,  y8  = 0.9,    0.3      # Node 8
# Row 3 (y = 0.6)
x9,  y9  = 0.0,    0.6      # Node 9  — fixed
x10, y10 = 0.3,    0.6      # Node 10 — hole corner
x11, y11 = 0.6,    0.6      # Node 11 — hole corner
x12, y12 = 0.9,    0.6      # Node 12
# Top row (y = 0.9)
x13, y13 = 0.0,    0.9      # Node 13 — fixed
x14, y14 = 0.3,    0.9      # Node 14
x15, y15 = 0.6,    0.9      # Node 15
x16, y16 = 0.9,    0.9      # Node 16 — loaded (Fy = -20 kN)

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_q4_elementstiffness(E, NU, h, x1, y1, x2, y2, x6, y6, x5, y5, p)     # 1-2-6-5
k2 = d2_q4_elementstiffness(E, NU, h, x2, y2, x3, y3, x7, y7, x6, y6, p)     # 2-3-7-6
k3 = d2_q4_elementstiffness(E, NU, h, x3, y3, x4, y4, x8, y8, x7, y7, p)     # 3-4-8-7
k4 = d2_q4_elementstiffness(E, NU, h, x5, y5, x6, y6, x10, y10, x9, y9, p)   # 5-6-10-9
k5 = d2_q4_elementstiffness(E, NU, h, x7, y7, x8, y8, x12, y12, x11, y11, p) # 7-8-12-11
k6 = d2_q4_elementstiffness(E, NU, h, x9, y9, x10, y10, x14, y14, x13, y13, p) # 9-10-14-13
k7 = d2_q4_elementstiffness(E, NU, h, x10, y10, x11, y11, x15, y15, x14, y14, p) # 10-11-15-14
k8 = d2_q4_elementstiffness(E, NU, h, x11, y11, x12, y12, x16, y16, x15, y15, p) # 11-12-16-15

println("k1 ="); display(k1)
println("k8 ="); display(k8)

# ─── Assembly ────────────────────────────────────────────────
# 16 nodes × 2 DOF = 32 DOFs
K = zeros(32, 32)
K = d2_q4_assemble(K, k1, 1, 2, 6, 5)
K = d2_q4_assemble(K, k2, 2, 3, 7, 6)
K = d2_q4_assemble(K, k3, 3, 4, 8, 7)
K = d2_q4_assemble(K, k4, 5, 6, 10, 9)
K = d2_q4_assemble(K, k5, 7, 8, 12, 11)
K = d2_q4_assemble(K, k6, 9, 10, 14, 13)
K = d2_q4_assemble(K, k7, 10, 11, 15, 14)
K = d2_q4_assemble(K, k8, 11, 12, 16, 15)

# ─── Solve ───────────────────────────────────────────────────
# Fixed DOFs: nodes 1, 5, 9, 13 → DOFs 1:2, 9:10, 17:18, 25:26
# Free DOFs:  nodes 2-4 (3:8), 6-8 (11:16), 10-12 (19:24), 14-16 (27:32)
# Block-ordered reduction [3:8, 11:16, 19:24, 27:32] — matches Kattan's MATLAB
free = [3:8; 11:16; 19:24; 27:32]
k = K[free, free]
f = zeros(24)
f[24] = -20.0  # node 16, Fy (DOF 32 = 24th free DOF)

u = k \ f
U = zeros(32)
U[3:8]   = u[1:6]
U[11:16] = u[7:12]
U[19:24] = u[13:18]
U[27:32] = u[19:24]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nu (free DOFs, block order) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (1-2-6-5): global DOFs 1,2  3,4  11,12  9,10
u1 = [U[1]; U[2]; U[3]; U[4]; U[11]; U[12]; U[9]; U[10]]
sig1 = d2_q4_elementstress(E, NU, x1, y1, x2, y2, x6, y6, x5, y5, p, u1)

# Element 2 (2-3-7-6): global DOFs 3,4  5,6  13,14  11,12
u2 = [U[3]; U[4]; U[5]; U[6]; U[13]; U[14]; U[11]; U[12]]
sig2 = d2_q4_elementstress(E, NU, x2, y2, x3, y3, x7, y7, x6, y6, p, u2)

# Element 3 (3-4-8-7): global DOFs 5,6  7,8  15,16  13,14
u3 = [U[5]; U[6]; U[7]; U[8]; U[15]; U[16]; U[13]; U[14]]
sig3 = d2_q4_elementstress(E, NU, x3, y3, x4, y4, x8, y8, x7, y7, p, u3)

# Element 4 (5-6-10-9): global DOFs 9,10  11,12  19,20  17,18
u4 = [U[9]; U[10]; U[11]; U[12]; U[19]; U[20]; U[17]; U[18]]
sig4 = d2_q4_elementstress(E, NU, x5, y5, x6, y6, x10, y10, x9, y9, p, u4)

# Element 5 (7-8-12-11): global DOFs 13,14  15,16  23,24  21,22
u5 = [U[13]; U[14]; U[15]; U[16]; U[23]; U[24]; U[21]; U[22]]
sig5 = d2_q4_elementstress(E, NU, x7, y7, x8, y8, x12, y12, x11, y11, p, u5)

# Element 6 (9-10-14-13): global DOFs 17,18  19,20  27,28  25,26
u6 = [U[17]; U[18]; U[19]; U[20]; U[27]; U[28]; U[25]; U[26]]
sig6 = d2_q4_elementstress(E, NU, x9, y9, x10, y10, x14, y14, x13, y13, p, u6)

# Element 7 (10-11-15-14): global DOFs 19,20  21,22  29,30  27,28
u7 = [U[19]; U[20]; U[21]; U[22]; U[29]; U[30]; U[27]; U[28]]
sig7 = d2_q4_elementstress(E, NU, x10, y10, x11, y11, x15, y15, x14, y14, p, u7)

# Element 8 (11-12-16-15): global DOFs 21,22  23,24  31,32  29,30
u8 = [U[21]; U[22]; U[23]; U[24]; U[31]; U[32]; U[29]; U[30]]
sig8 = d2_q4_elementstress(E, NU, x11, y11, x12, y12, x16, y16, x15, y15, p, u8)

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
# Expected values from the Solutions Manual problem_13_2.m run under Octave
# (Symbolic pkg, SymPy) — see Doc/Kattan/Solutions-Manual/
# Node 2 displacements (m)
@assert isapprox(u[1], -2.9918e-5; rtol=1e-2) "Ux2 mismatch: $(u[1])"
@assert isapprox(u[2], -2.8358e-5; rtol=1e-2) "Uy2 mismatch: $(u[2])"

# Node 4 displacements (m)
@assert isapprox(u[5], -3.8644e-5; rtol=1e-2) "Ux4 mismatch: $(u[5])"
@assert isapprox(u[6], -1.1018e-4; rtol=1e-2) "Uy4 mismatch: $(u[6])"

# Node 6 (hole corner) displacements (m)
@assert isapprox(u[7], 1.4762e-6; rtol=1e-2) "Ux6 mismatch: $(u[7])"
@assert isapprox(u[8], -2.0309e-5; rtol=1e-2) "Uy6 mismatch: $(u[8])"

# Node 8 displacements (m)
@assert isapprox(u[11], -1.2326e-5; rtol=1e-2) "Ux8 mismatch: $(u[11])"
@assert isapprox(u[12], -1.0881e-4; rtol=1e-2) "Uy8 mismatch: $(u[12])"

# Node 12 displacements (m)
@assert isapprox(u[15], -2.3489e-6; rtol=1e-2) "Ux12 mismatch: $(u[15])"
@assert isapprox(u[16], -8.2419e-5; rtol=1e-2) "Uy12 mismatch: $(u[16])"

# Node 16 displacements (m) — max deflection (loaded corner)
@assert isapprox(u[23], 5.6534e-5; rtol=1e-2) "Ux16 mismatch: $(u[23])"
@assert isapprox(u[24], -1.5895e-4; rtol=1e-2) "Uy16 mismatch: $(u[24])"

# Reactions at fixed nodes 1, 5, 9, 13 (kN)
@assert isapprox(F[1], 17.6570; rtol=1e-2) "Fx1 mismatch: $(F[1])"
@assert isapprox(F[2], 3.4450; rtol=1e-2) "Fy1 mismatch: $(F[2])"
@assert isapprox(F[9], 7.4806; rtol=1e-2) "Fx5 mismatch: $(F[9])"
@assert isapprox(F[10], 7.0314; rtol=1e-2) "Fy5 mismatch: $(F[10])"
@assert isapprox(F[17], -7.9321; rtol=1e-2) "Fx9 mismatch: $(F[17])"
@assert isapprox(F[18], 6.7416; rtol=1e-2) "Fy9 mismatch: $(F[18])"
@assert isapprox(F[25], -17.2054; rtol=1e-2) "Fx13 mismatch: $(F[25])"
@assert isapprox(F[26], 2.7819; rtol=1e-2) "Fy13 mismatch: $(F[26])"

# Applied load at node 16
@assert isapprox(F[32], -20.0; rtol=1e-2) "Fy16 mismatch: $(F[32])"

# Element 1 stresses (bottom-left)
@assert isapprox(sig1[1], -3288.97; rtol=1e-2) "σxx1 mismatch: $(sig1[1])"
@assert isapprox(sig1[2], 116.86; rtol=1e-2) "σyy1 mismatch: $(sig1[2])"
@assert isapprox(sig1[3], -806.08; rtol=1e-2) "τxy1 mismatch: $(sig1[3])"

# Element 2 stresses
@assert isapprox(sig2[1], -2209.08; rtol=1e-2) "σxx2 mismatch: $(sig2[1])"
@assert isapprox(sig2[2], -158.45; rtol=1e-2) "σyy2 mismatch: $(sig2[2])"
@assert isapprox(sig2[3], -1949.31; rtol=1e-2) "τxy2 mismatch: $(sig2[3])"

# Element 3 stresses
@assert isapprox(sig3[1], -592.06; rtol=1e-2) "σxx3 mismatch: $(sig3[1])"
@assert isapprox(sig3[2], -532.59; rtol=1e-2) "σyy3 mismatch: $(sig3[2])"
@assert isapprox(sig3[3], -187.44; rtol=1e-2) "τxy3 mismatch: $(sig3[3])"

# Element 4 stresses (left, below the hole)
@assert isapprox(sig4[1], -27.362; rtol=1e-2) "σxx4 mismatch: $(sig4[1])"
@assert isapprox(sig4[2], 203.241; rtol=1e-2) "σyy4 mismatch: $(sig4[2])"
@assert isapprox(sig4[3], -1980.51; rtol=1e-2) "τxy4 mismatch: $(sig4[3])"

# Element 5 stresses (right, below the hole)
@assert isapprox(sig5[1], -308.67; rtol=1e-2) "σxx5 mismatch: $(sig5[1])"
@assert isapprox(sig5[2], -1949.31; rtol=1e-2) "σyy5 mismatch: $(sig5[2])"
@assert isapprox(sig5[3], -2209.09; rtol=1e-2) "τxy5 mismatch: $(sig5[3])"

# Element 6 stresses (left column, above the hole)
@assert isapprox(sig6[1], 3316.329; rtol=1e-2) "σxx6 mismatch: $(sig6[1])"
@assert isapprox(sig6[2], -48.438; rtol=1e-2) "σyy6 mismatch: $(sig6[2])"
@assert isapprox(sig6[3], -546.742; rtol=1e-2) "τxy6 mismatch: $(sig6[3])"

# Element 7 stresses (top-middle)
@assert isapprox(sig7[1], 2209.08; rtol=1e-2) "σxx7 mismatch: $(sig7[1])"
@assert isapprox(sig7[2], 446.45; rtol=1e-2) "σyy7 mismatch: $(sig7[2])"
@assert isapprox(sig7[3], -1384.02; rtol=1e-2) "τxy7 mismatch: $(sig7[3])"

# Element 8 stresses (top-right)
@assert isapprox(sig8[1], 900.72; rtol=1e-2) "σxx8 mismatch: $(sig8[1])"
@assert isapprox(sig8[2], -3267.68; rtol=1e-2) "σyy8 mismatch: $(sig8[2])"
@assert isapprox(sig8[3], -936.81; rtol=1e-2) "τxy8 mismatch: $(sig8[3])"

println("\nAll golden assertions passed ✓")
