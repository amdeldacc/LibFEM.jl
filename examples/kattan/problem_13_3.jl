#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 13.3 — Thin Plate Supported by Three Springs
#               (2 Bilinear Quadrilateral (Q4) Elements + 3 Springs)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: THIN PLATE ON THREE SPRING SUPPORTS (Fig 13.11)
# =============================================================================
# Note: Discretized using 2 Bilinear Quadrilaterals. The bottom edge
#       (nodes 4, 5, 6) rests on three vertical springs (k = 4000 kN/m)
#       anchored to the ground.
#
#                    8.75 kN   17.5 kN   8.75 kN
#                      |         |         |
#                      v         v         v
#             1==============O==============O==============3
#             |              |              |              |
#             |  Element 1   |  Element 2   |              |
#             |  (4,5,2,1)   |  (5,6,3,2)   |              |
#             |              |              |              |
#             4==============O==============O==============6
#                         5  |              |
#                            v              v
#                           /\/\           /\/\
#                           k=4000         k=4000
#                            |              |
#                          GROUND         GROUND
#
#             |<--- 0.35 m -->|<--- 0.35 m -->|
#
# =============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# =============================================================================
# Assuming Node 4 is at the origin (0,0) and units are in meters:
#
#   Top Row (y = 0.4):
#     Node 1 : ( 0.0, 0.4 )  -> Applied Load: Fy = +8.75 kN
#     Node 2 : ( 0.35, 0.4 ) -> Applied Load: Fy = +17.5 kN
#     Node 3 : ( 0.7, 0.4 )  -> Applied Load: Fy = +8.75 kN
#
#   Bottom Row (y = 0.0):
#     Node 4 : ( 0.0, 0.0 )  -> Spring support (k = 4000) to ground
#     Node 5 : ( 0.35, 0.0 ) -> Spring support (k = 4000) to ground
#     Node 6 : ( 0.7, 0.0 )  -> Spring support (k = 4000) to ground
#
#   Spring ground nodes (fixed): DOFs 13, 14, 15
#     Spring 3 : between node 4 (DOF 8)  and ground (DOF 13)
#     Spring 4 : between node 5 (DOF 10) and ground (DOF 14)
#     Spring 5 : between node 6 (DOF 12) and ground (DOF 15)
#
# ELEMENTS (2 Bilinear Quadrilaterals + 3 Springs):
#   Element 1 : Nodes 4, 5, 2, 1   (Q4, bottom-left half of plate)
#   Element 2 : Nodes 5, 6, 3, 2   (Q4, bottom-right half of plate)
#   Element 3 : Spring k=4000, DOFs 8  <-> 13  (supports node 4)
#   Element 4 : Spring k=4000, DOFs 10 <-> 14  (supports node 5)
#   Element 5 : Spring k=4000, DOFs 12 <-> 15  (supports node 6)
#
# =============================================================================
# =============================================================================
# Parameters:
#   Material:    E = 200 GPa, ν = 0.3
#   Thickness:   h = 0.01 m
#   Type:        Plane stress (p=1)
#   Loading:     Upward point loads of 8.75 / 17.5 / 8.75 kN at the three
#                top nodes (1, 2, 3) — plate hangs from the springs
#   Supports:    Bottom nodes 4, 5, 6 on vertical springs k = 4000 kN/m
#                anchored to fixed ground (DOFs 13, 14, 15 constrained)
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (15 DOFs: 6 nodes × 2 + 3 spring grounds)
#   2. Displacements at all free nodes
#   3. Reactions at spring ground nodes 13, 14, 15
#   4. Element stresses (σ_xx, σ_yy, τ_xy) at each element centroid
#   5. Spring element forces
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 200e6   # Young's modulus (kPa)
NU = 0.3    # Poisson's ratio
h = 0.01    # thickness (m)
p = 1       # plane stress

# ─── Node coordinates ────────────────────────────────────────
# 6 plate nodes, 2 DOF per node (DOFs 1-12) + 3 spring grounds (DOFs 13-15)
# Top row (y = 0.4)
x1, y1 = 0.0,    0.4     # Node 1  — loaded (Fy = +8.75 kN)
x2, y2 = 0.35,   0.4     # Node 2  — loaded (Fy = +17.5 kN)
x3, y3 = 0.7,    0.4     # Node 3  — loaded (Fy = +8.75 kN)
# Bottom row (y = 0.0)
x4, y4 = 0.0,    0.0     # Node 4  — spring support
x5, y5 = 0.35,   0.0     # Node 5  — spring support
x6, y6 = 0.7,    0.0     # Node 6  — spring support

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_q4_elementstiffness(E, NU, h, x4, y4, x5, y5, x2, y2, x1, y1, p) # 4-5-2-1
k2 = d2_q4_elementstiffness(E, NU, h, x5, y5, x6, y6, x3, y3, x2, y2, p) # 5-6-3-2
kspring = d1_spring_elementstiffness(4000)  # kN/m

println("k1 ="); display(k1)
println("kspring ="); display(kspring)

# ─── Assembly ────────────────────────────────────────────────
# 15 DOFs: 6 plate nodes × 2 DOF = 12, plus spring grounds 13, 14, 15
K = zeros(15, 15)
K = d2_q4_assemble(K, k1, 4, 5, 2, 1)
K = d2_q4_assemble(K, k2, 5, 6, 3, 2)
K = d1_spring_assemble(K, kspring, 8, 13)   # node 4 (DOF 8)  → ground (13)
K = d1_spring_assemble(K, kspring, 10, 14)  # node 5 (DOF 10) → ground (14)
K = d1_spring_assemble(K, kspring, 12, 15)  # node 6 (DOF 12) → ground (15)

# ─── Solve ───────────────────────────────────────────────────
# Fixed DOFs: 13, 14, 15 (spring grounds)
# Free DOFs:  1:12 (plate nodes)
k = K[1:12, 1:12]
f = zeros(12)
f[2] = 8.75   # node 1, Fy
f[4] = 17.5   # node 2, Fy
f[6] = 8.75   # node 3, Fy

u = k \ f
U = [u; 0; 0; 0]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nu (free DOFs) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (4-5-2-1): global DOFs 7,8  9,10  3,4  1,2
u1 = [U[7]; U[8]; U[9]; U[10]; U[3]; U[4]; U[1]; U[2]]
sig1 = d2_q4_elementstress(E, NU, x4, y4, x5, y5, x2, y2, x1, y1, p, u1)

# Element 2 (5-6-3-2): global DOFs 9,10  11,12  5,6  3,4
u2 = [U[9]; U[10]; U[11]; U[12]; U[5]; U[6]; U[3]; U[4]]
sig2 = d2_q4_elementstress(E, NU, x5, y5, x6, y6, x3, y3, x2, y2, p, u2)

# Principal stresses
s1 = d2_q4_elementpstress(sig1)
s2 = d2_q4_elementpstress(sig2)

println("\nσ1 = $sig1 ; s1 = $s1")
println("σ2 = $sig2 ; s2 = $s2")

# ─── Post-processing: spring forces ──────────────────────────
# Spring 3: nodes 4 (DOF 8) ↔ ground (DOF 13)
u3 = [U[8]; U[13]]
fspring3 = d1_spring_elementforce(kspring, u3)

# Spring 4: node 5 (DOF 10) ↔ ground (DOF 14)
u4 = [U[10]; U[14]]
fspring4 = d1_spring_elementforce(kspring, u4)

# Spring 5: node 6 (DOF 12) ↔ ground (DOF 15)
u5 = [U[12]; U[15]]
fspring5 = d1_spring_elementforce(kspring, u5)

println("\nfspring3 = $fspring3")
println("fspring4 = $fspring4")
println("fspring5 = $fspring5")

# ─── Equilibrium check ───────────────────────────────────────
# NOTE: DOFs 13-15 are the spring *ground* DOFs, which are y-direction.
# x-direction forces live in DOFs 1,3,5,7,9,11; y-direction in the rest.
println("\n--- Equilibrium check ---")
sum_fx = F[1] + F[3] + F[5] + F[7] + F[9] + F[11]
sum_fy = sum(F) - sum_fx
println("Sum Fx: $sum_fx (should ≈ 0)")
println("Sum Fy: $sum_fy (should = 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from the Solutions Manual problem_13_3.m run under Octave
# (Symbolic pkg, SymPy) — see Doc/Kattan/Solutions-Manual/
#
# NOTE ON UNIQUENESS: the plate is supported only by vertical springs, so the
# 12×12 reduced stiffness is SINGULAR in the x-direction (rigid x-translation
# is a zero-energy mode). The absolute ux values depend on the solver; only
# (a) uy, (b) ux differences between nodes, (c) reactions, and (d) stresses
# are physically unique. Golden ux values (Octave) are quoted for reference.

# Displacements — uy: near-uniform field (plate ≈ rigid vs soft springs)
# Node 1 (top-left)
@assert isapprox(u[2], 2.9269e-3; rtol=1e-2) "Uy1 mismatch: $(u[2])"
# Node 2 (top-middle)
@assert isapprox(u[4], 2.9292e-3; rtol=1e-2) "Uy2 mismatch: $(u[4])"
# Node 3 (top-right)
@assert isapprox(u[6], 2.9269e-3; rtol=1e-2) "Uy3 mismatch: $(u[6])"
# Node 4 (bottom-left, on spring)
@assert isapprox(u[8], 2.9138e-3; rtol=1e-2) "Uy4 mismatch: $(u[8])"
# Node 5 (bottom-middle, on spring)
@assert isapprox(u[10], 2.9223e-3; rtol=1e-2) "Uy5 mismatch: $(u[10])"
# Node 6 (bottom-right, on spring)
@assert isapprox(u[12], 2.9138e-3; rtol=1e-2) "Uy6 mismatch: $(u[12])"

# ux differences (unique despite the singular x-mode)
# Golden ux (Octave, m): [3.3336, 3.3105, 3.2875, 3.8125, 3.3105, 2.8086]e-5
ux_rel(i) = u[2i - 1] - u[1]   # ux_i - ux_1 (m)
@assert isapprox(ux_rel(2), -2.31e-7; atol=1e-9) "Ux2-Ux1 mismatch: $(ux_rel(2))"
@assert isapprox(ux_rel(3), -4.61e-7; atol=1e-9) "Ux3-Ux1 mismatch: $(ux_rel(3))"
@assert isapprox(ux_rel(4),  4.79e-6; atol=1e-9) "Ux4-Ux1 mismatch: $(ux_rel(4))"
@assert isapprox(ux_rel(5), -2.31e-7; atol=1e-9) "Ux5-Ux1 mismatch: $(ux_rel(5))"
@assert isapprox(ux_rel(6), -5.25e-6; atol=1e-9) "Ux6-Ux1 mismatch: $(ux_rel(6))"

# Reactions at spring grounds (kN)
@assert isapprox(F[13], -11.6553; rtol=1e-2) "R13 mismatch: $(F[13])"
@assert isapprox(F[14], -11.6894; rtol=1e-2) "R14 mismatch: $(F[14])"
@assert isapprox(F[15], -11.6553; rtol=1e-2) "R15 mismatch: $(F[15])"

# Applied loads
@assert isapprox(F[2], 8.75; rtol=1e-2) "Fy1 mismatch: $(F[2])"
@assert isapprox(F[4], 17.5; rtol=1e-2) "Fy2 mismatch: $(F[4])"
@assert isapprox(F[6], 8.75; rtol=1e-2) "Fy3 mismatch: $(F[6])"

# Element 1 stresses (bottom-left half)
@assert abs(sig1[1]) < 1e-2 "σxx1 not ≈ 0: $(sig1[1])"
@assert isapprox(sig1[2], 5000.0; rtol=1e-2) "σyy1 mismatch: $(sig1[2])"
@assert isapprox(sig1[3], 726.33; rtol=1e-2) "τxy1 mismatch: $(sig1[3])"

# Element 2 stresses (bottom-right half)
@assert abs(sig2[1]) < 1e-2 "σxx2 not ≈ 0: $(sig2[1])"
@assert isapprox(sig2[2], 5000.0; rtol=1e-2) "σyy2 mismatch: $(sig2[2])"
@assert isapprox(sig2[3], -726.33; rtol=1e-2) "τxy2 mismatch: $(sig2[3])"

# Spring element forces (kN) — positive = tension
@assert isapprox(fspring3[1], 11.6553; rtol=1e-2) "Spring3 force mismatch: $(fspring3[1])"
@assert isapprox(fspring4[1], 11.6894; rtol=1e-2) "Spring4 force mismatch: $(fspring4[1])"
@assert isapprox(fspring5[1], 11.6553; rtol=1e-2) "Spring5 force mismatch: $(fspring5[1])"

println("\nAll golden assertions passed ✓")
