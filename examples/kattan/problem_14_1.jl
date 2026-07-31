#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 14.1 — Thin Plate Supported by Three Springs
#               (1 Quadratic Quadrilateral (Q8) Element + 3 Springs)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: THIN PLATE SUPPORTED ON THREE SPRINGS
# =============================================================================
# Note: Discretized using 1 Quadratic Quadrilateral (Q8) and 3 Spring Elements.
#
#                                  w
#            +---------------------------------------+
#            ^   ^   ^   ^   ^   ^   ^   ^   ^   ^   ^
#            |   |   |   |   |   |   |   |   |   |   |
#          1 O===================O===================O 3      - - -
#            |         2         |         2          |          ^
#            |                   |                   |          |
#            |                   |                   |        0.4 m
#            |         4         |         5          |          |
#          6 O===================O===================O 8      - - -
#            |         7         |                   |
#           /                   /                   /
#           \ k                 \ k                 \ k
#           /                   /                   /
#           \                   \                   \
#            |                   |                   |
#          9 O                10 O                11 O
#          -----               -----               -----
#          /////               /////               /////
#
#            |<----- 0.35 m ---->|<----- 0.35 m ---->|
#
# =============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# =============================================================================
# Assuming Node 6 is at the origin (0,0) and units are in meters:
#
#   Plate Nodes (single Q8 element, 2 DOF each):
#     Node 1 : ( 0.00,  0.40 )  -> Corner (top-left), loaded
#     Node 2 : ( 0.35,  0.40 )  -> Mid-side (top), loaded
#     Node 3 : ( 0.70,  0.40 )  -> Corner (top-right), loaded
#     Node 4 : ( 0.00,  0.20 )  -> Mid-side (left)
#     Node 5 : ( 0.70,  0.20 )  -> Mid-side (right)
#     Node 6 : ( 0.00,  0.00 )  -> Corner (bottom-left),  -> Left Spring
#     Node 7 : ( 0.35,  0.00 )  -> Mid-side (bottom),     -> Middle Spring
#     Node 8 : ( 0.70,  0.00 )  -> Corner (bottom-right), -> Right Spring
#
#   Ground Support Nodes (1 DOF each):
#     Node 9  : ( 0.00, -Ls )   -> Fixed Support (Ls = spring un-stretched length)
#     Node 10 : ( 0.35, -Ls )   -> Fixed Support
#     Node 11 : ( 0.70, -Ls )   -> Fixed Support
#
#   Loads & Elements:
#     Distributed Load : w (upwards, +Y direction) acting on edge 1-2-3.
#     Plate Element   : 1 Quadratic Quadrilateral (Nodes 1-2-3-8-7-6-4 in
#                       global view; assembled as corners 6-8-3-1 and
#                       mid-sides 7-5-2-4 in local Q8 order).
#     Spring Elements : 3 Springs of stiffness k (Nodes 6-9, 7-10, and 8-11).
#
# =============================================================================
# =============================================================================
# Parameters:
#   Material:    E = 200 GPa, ν = 0.3
#   Thickness:   h = 0.01 m
#   Type:        Plane stress (p=1)
#   Loading:     Upward point loads of 5.8333 / 23.3333 / 5.8333 kN at the
#                three top nodes (1, 2, 3) — Q8 consistent nodal loads for a
#                uniform edge load w (total 35 kN); plate hangs from the springs
#   Supports:    Bottom nodes 6, 7, 8 on vertical springs k = 4000 kN/m
#                anchored to fixed ground (DOFs 17, 18, 19 constrained)
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (19 DOFs: 8 nodes × 2 + 3 spring grounds)
#   2. Displacements at all free nodes
#   3. Reactions at spring ground nodes 17, 18, 19
#   4. Element stresses (σ_xx, σ_yy, τ_xy) at the element centroid
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
# 8 plate nodes, 2 DOF per node (DOFs 1-16) + 3 spring grounds (DOFs 17-19)
# Top row (y = 0.4)
x1, y1 = 0.0,   0.4     # Node 1  — corner (TL), loaded (Fy = +5.8333 kN)
x2, y2 = 0.35,  0.4     # Node 2  — mid-side (T), loaded (Fy = +23.3333 kN)
x3, y3 = 0.7,   0.4     # Node 3  — corner (TR), loaded (Fy = +5.8333 kN)
# Middle row (y = 0.2)
x4, y4 = 0.0,   0.2     # Node 4  — mid-side (L)
x5, y5 = 0.7,   0.2     # Node 5  — mid-side (R)
# Bottom row (y = 0.0)
x6, y6 = 0.0,   0.0     # Node 6  — corner (BL), spring support
x7, y7 = 0.35,  0.0     # Node 7  — mid-side (B), spring support
x8, y8 = 0.7,   0.0     # Node 8  — corner (BR), spring support

# ─── Element stiffness matrices ──────────────────────────────
# Q8 element, local order: corners 6-8-3-1 (CCW), mid-sides 7-5-2-4
k1 = d2_q8_elementstiffness(E, NU, h, x6, y6, x8, y8, x3, y3, x1, y1,
                            x7, y7, x5, y5, x2, y2, x4, y4, p)
kspring = d1_spring_elementstiffness(4000)  # kN/m

println("k1 ="); display(k1)
println("kspring ="); display(kspring)

# ─── Assembly ────────────────────────────────────────────────
# 19 DOFs: 8 plate nodes × 2 DOF = 16, plus spring grounds 17, 18, 19
K = zeros(19, 19)
K = d2_q8_assemble(K, k1, 6, 8, 3, 1, 7, 5, 2, 4)
K = d1_spring_assemble(K, kspring, 12, 17)  # node 6 (DOF 12)  → ground (17)
K = d1_spring_assemble(K, kspring, 14, 18)  # node 7 (DOF 14)  → ground (18)
K = d1_spring_assemble(K, kspring, 16, 19)  # node 8 (DOF 16)  → ground (19)

# ─── Solve ───────────────────────────────────────────────────
# Fixed DOFs: 17, 18, 19 (spring grounds)
# Free DOFs:  1:16 (plate nodes)
k = K[1:16, 1:16]
f = zeros(16)
f[2] = 5.8333   # node 1, Fy
f[4] = 23.3333  # node 2, Fy
f[6] = 5.8333   # node 3, Fy

u = k \ f
U = [u; 0; 0; 0]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nu (free DOFs) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (6-8-3-1, mids 7-5-2-4): global DOFs
#   11,12  15,16  5,6  1,2  13,14  9,10  3,4  7,8
u1 = [U[11]; U[12]; U[15]; U[16]; U[5]; U[6]; U[1]; U[2];
      U[13]; U[14]; U[9]; U[10]; U[3]; U[4]; U[7]; U[8]]
sig1 = d2_q8_elementstress(E, NU, x6, y6, x8, y8, x3, y3, x1, y1,
                           x7, y7, x5, y5, x2, y2, x4, y4, p, u1)

# Principal stresses
s1 = d2_q8_elementpstress(sig1)

println("\nσ1 = $sig1 ; s1 = $s1")

# ─── Post-processing: spring forces ──────────────────────────
# Spring 1: nodes 6 (DOF 12) ↔ ground (DOF 17)
u2 = [U[12]; U[17]]
fspring1 = d1_spring_elementforce(kspring, u2)

# Spring 2: node 7 (DOF 14) ↔ ground (DOF 18)
u3 = [U[14]; U[18]]
fspring2 = d1_spring_elementforce(kspring, u3)

# Spring 3: node 8 (DOF 16) ↔ ground (DOF 19)
u4 = [U[16]; U[19]]
fspring3 = d1_spring_elementforce(kspring, u4)

println("\nfspring1 = $fspring1")
println("fspring2 = $fspring2")
println("fspring3 = $fspring3")

# ─── Equilibrium check ───────────────────────────────────────
# NOTE: DOFs 17-19 are the spring *ground* DOFs, which are y-direction.
# x-direction forces live in DOFs 1,3,5,7,9,11,13,15; y-direction in the rest.
println("\n--- Equilibrium check ---")
sum_fx = F[1] + F[3] + F[5] + F[7] + F[9] + F[11] + F[13] + F[15]
sum_fy = sum(F) - sum_fx
println("Sum Fx: $sum_fx (should ≈ 0)")
println("Sum Fy: $sum_fy (should = 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from the Solutions Manual problem_14_1.m run under Octave
# (Symbolic pkg, SymPy) — see Doc/Kattan/Solutions-Manual/
#
# NOTE ON UNIQUENESS: the plate is supported only by vertical springs, so the
# 16×16 reduced stiffness is SINGULAR in the x-direction (rigid x-translation
# is a zero-energy mode). The absolute ux values depend on the solver; only
# (a) uy, (b) ux differences between nodes, (c) reactions, and (d) stresses
# are physically unique. Golden ux values (Octave) are quoted for reference.

# Displacements — uy: near-uniform field (plate ≈ rigid vs soft springs)
# Node 1 (top-left)
@assert isapprox(u[2], 2.9309e-3; rtol=1e-2) "Uy1 mismatch: $(u[2])"
# Node 2 (top-mid-side)
@assert isapprox(u[4], 2.9339e-3; rtol=1e-2) "Uy2 mismatch: $(u[4])"
# Node 3 (top-right)
@assert isapprox(u[6], 2.9309e-3; rtol=1e-2) "Uy3 mismatch: $(u[6])"
# Node 4 (left mid-side)
@assert isapprox(u[8], 2.9212e-3; rtol=1e-2) "Uy4 mismatch: $(u[8])"
# Node 5 (right mid-side)
@assert isapprox(u[10], 2.9212e-3; rtol=1e-2) "Uy5 mismatch: $(u[10])"
# Node 6 (bottom-left, on spring)
@assert isapprox(u[12], 2.9105e-3; rtol=1e-2) "Uy6 mismatch: $(u[12])"
# Node 7 (bottom-mid-side, on spring)
@assert isapprox(u[14], 2.9290e-3; rtol=1e-2) "Uy7 mismatch: $(u[14])"
# Node 8 (bottom-right, on spring)
@assert isapprox(u[16], 2.9105e-3; rtol=1e-2) "Uy8 mismatch: $(u[16])"

# ux differences (unique despite the singular x-mode)
# Golden ux (Octave, m): [-4.3728, -4.3713, -4.3697, -4.3699, -4.3727,
#                         -4.3595, -4.3713, -4.3831]e-3
ux_rel(i) = u[2i - 1] - u[1]   # ux_i - ux_1 (m)
@assert isapprox(ux_rel(2),  1.5433e-6; atol=1e-9) "Ux2-Ux1 mismatch: $(ux_rel(2))"
@assert isapprox(ux_rel(3),  3.0867e-6; atol=1e-9) "Ux3-Ux1 mismatch: $(ux_rel(3))"
@assert isapprox(ux_rel(4),  2.9171e-6; atol=1e-9) "Ux4-Ux1 mismatch: $(ux_rel(4))"
@assert isapprox(ux_rel(5),  1.6956e-7; atol=1e-9) "Ux5-Ux1 mismatch: $(ux_rel(5))"
@assert isapprox(ux_rel(6),  1.3342e-5; atol=1e-9) "Ux6-Ux1 mismatch: $(ux_rel(6))"
@assert isapprox(ux_rel(7),  1.5433e-6; atol=1e-9) "Ux7-Ux1 mismatch: $(ux_rel(7))"
@assert isapprox(ux_rel(8), -1.0255e-5; atol=1e-9) "Ux8-Ux1 mismatch: $(ux_rel(8))"

# Reactions at spring grounds (kN)
@assert isapprox(F[17], -11.6419; rtol=1e-2) "R17 mismatch: $(F[17])"
@assert isapprox(F[18], -11.7162; rtol=1e-2) "R18 mismatch: $(F[18])"
@assert isapprox(F[19], -11.6419; rtol=1e-2) "R19 mismatch: $(F[19])"

# Applied loads
@assert isapprox(F[2], 5.8333; rtol=1e-6) "Fy1 mismatch: $(F[2])"
@assert isapprox(F[4], 23.3333; rtol=1e-6) "Fy2 mismatch: $(F[4])"
@assert isapprox(F[6], 5.8333; rtol=1e-6) "Fy3 mismatch: $(F[6])"

# Element stresses at centroid (kPa)
# (Manual prints σ = [-0.0709; 2.3805; 0.0000]·1e3 = [-70.9; 2380.5; 0].
#  Julia matches the manual; note the Octave symbolic pkg drifts slightly
#  to [-72.05; 2379.96; 0] — see Doc/Kattan/Solutions-Manual/problem_14_1.m.)
@assert isapprox(sig1[1], -70.85; rtol=1e-2) "σxx mismatch: $(sig1[1])"
@assert isapprox(sig1[2], 2380.54; rtol=1e-2) "σyy mismatch: $(sig1[2])"
@assert abs(sig1[3]) < 1e-2 "τxy not ≈ 0: $(sig1[3])"

# Spring element forces (kN) — positive = tension
@assert isapprox(fspring1[1], 11.6419; rtol=1e-2) "Spring1 force mismatch: $(fspring1[1])"
@assert isapprox(fspring2[1], 11.7162; rtol=1e-2) "Spring2 force mismatch: $(fspring2[1])"
@assert isapprox(fspring3[1], 11.6419; rtol=1e-2) "Spring3 force mismatch: $(fspring3[1])"

println("\nAll golden assertions passed ✓")
