#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 12.1 — Thin Plate with 4 LST Elements
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: DISCRETIZATION OF THIN PLATE (Fig 12.x)
# =============================================================================
#
#      y ^
#        |
#  0.25 m|  11 --- 12 --- 13 -------> 3.125 kN
#        |   | \   |   /   |         (uniform 75 kN/m on right edge,
#        |   |   \ | /     |          1/6 : 2/3 : 1/6 quadratic split)
#        |   6 --- 7 ---  8 ------> 12.5 kN
#        |   |   / | \     |
#        |   | /   |   \   |
#        |   1 --- 2 ---  3 ------> 3.125 kN
#        |
#        |-------- 0.5 m ---------> x
#
#      left edge (x=0) fixed: nodes 1, 6, 11
#
# =============================================================================
# NODE COORDINATES & LOADS:
# =============================================================================
# Unit is meters. 13 nodes, 2 DOF per node (ux, uy).
#
#   Node 1  : (0.000, 0.000)    Node 8  : (0.500, 0.125)  -> Fx = +12.5 kN
#   Node 2  : (0.250, 0.000)    Node 9  : (0.125, 0.1875)
#   Node 3  : (0.500, 0.000)  -> Fx = +3.125 kN
#   Node 4  : (0.125, 0.0625)   Node 10 : (0.375, 0.1875)
#   Node 5  : (0.375, 0.0625)   Node 11 : (0.000, 0.250)  -> Fixed Support
#   Node 6  : (0.000, 0.125)  -> Fixed Support
#   Node 7  : (0.250, 0.125)    Node 12 : (0.250, 0.250)
#                               Node 13 : (0.500, 0.250)  -> Fx = +3.125 kN
#
# ELEMENTS (4 Quadratic Triangles, node order: corners then mid-edge):
#   Element 1 : 1-7-11  / 4-9-6
#   Element 2 : 1-3-7   / 2-5-4
#   Element 3 : 7-13-11 / 10-12-9
#   Element 4 : 7-3-13  / 5-8-10
#
# =============================================================================
# Parameters:
#   Material:    E = 210 GPa, ν = 0.3
#   Thickness:   t = 0.025 m
#   Type:        Plane stress (p=1)
#   Loading:     Uniform 75 kN/m on right edge (x = 0.5 m), split 1/6 : 2/3 : 1/6
#                between corner, mid-edge, corner nodes of the quadratic edge
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
t = 0.025   # thickness (m)
p = 1       # plane stress

# ─── Node coordinates ────────────────────────────────────────
# 13 nodes, 2 DOF per node. Corner nodes first, then mid-edge nodes.
# Element 1 (1-7-11 / 4-9-6)
x1,  y1  = 0.0,    0.0      # Node 1  — fixed
x7,  y7  = 0.25,   0.125    # Node 7  — free
x11, y11 = 0.0,    0.25     # Node 11 — fixed
x4,  y4  = 0.125,  0.0625   # Node 4  — mid 1-7
x9,  y9  = 0.125,  0.1875   # Node 9  — mid 7-11
x6,  y6  = 0.0,    0.125    # Node 6  — mid 11-1 (fixed)

# Element 2 (1-3-7 / 2-5-4)
x3,  y3  = 0.5,    0.0      # Node 3  — free (loaded)
x2,  y2  = 0.25,   0.0      # Node 2  — mid 1-3
x5,  y5  = 0.375,  0.0625   # Node 5  — mid 3-7

# Element 3 (7-13-11 / 10-12-9)
x13, y13 = 0.5,    0.25     # Node 13 — free (loaded)
x10, y10 = 0.375,  0.1875   # Node 10 — mid 7-13
x12, y12 = 0.25,   0.25     # Node 12 — mid 13-11

# Element 4 (7-3-13 / 5-8-10)
x8,  y8  = 0.5,    0.125    # Node 8  — mid 3-13 (loaded)

# ─── Element stiffness matrices ──────────────────────────────
# Node order inside each element: corners (1,2,3) then mid-edge (4,5,6)
k1 = d2_lst_elementstiffness(E, NU, t, x1, y1, x7, y7, x11, y11, x4, y4, x9, y9, x6, y6, p)   # 1-7-11 / 4-9-6
k2 = d2_lst_elementstiffness(E, NU, t, x1, y1, x3, y3, x7, y7, x2, y2, x5, y5, x4, y4, p)     # 1-3-7 / 2-5-4
k3 = d2_lst_elementstiffness(E, NU, t, x7, y7, x13, y13, x11, y11, x10, y10, x12, y12, x9, y9, p) # 7-13-11 / 10-12-9
k4 = d2_lst_elementstiffness(E, NU, t, x7, y7, x3, y3, x13, y13, x5, y5, x8, y8, x10, y10, p) # 7-3-13 / 5-8-10

println("k1 ="); display(k1)
println("k2 ="); display(k2)
println("k3 ="); display(k3)
println("k4 ="); display(k4)

# ─── Assembly ────────────────────────────────────────────────
# 13 nodes × 2 DOF = 26 DOFs
K = zeros(26, 26)
K = d2_lst_assemble(K, k1, 1, 7, 11, 4, 9, 6)
K = d2_lst_assemble(K, k2, 1, 3, 7, 2, 5, 4)
K = d2_lst_assemble(K, k3, 7, 13, 11, 10, 12, 9)
K = d2_lst_assemble(K, k4, 7, 3, 13, 5, 8, 10)

println("\nK (26×26 global) ="); display(K)

# ─── Solve ───────────────────────────────────────────────────
# Fixed DOFs: nodes 1, 6, 11 → DOFs 1:2, 11:12, 21:22
# Free DOFs:  nodes 2-5 (3:10), 7-10 (13:20), 12-13 (23:26)
# Block-ordered reduction [3:10, 13:20, 23:26] — matches Kattan's MATLAB
free = [3:10; 13:20; 23:26]
k = K[free, free]
f = zeros(20)
f[3]  = 3.125  # node 3,  Fx
f[11] = 12.5   # node 8,  Fx
f[19] = 3.125  # node 13, Fx

u = k \ f
U = zeros(26)
U[3:10]   = u[1:8]
U[13:20]  = u[9:16]
U[23:26]  = u[17:20]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nk (reduced, 20×20) ="); display(k)
println("\nf ="); display(f)
println("\nu (free DOFs, block order) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (1-7-11 / 4-9-6): global DOFs 1,2  13,14  21,22  7,8  17,18  11,12
u1 = [U[1]; U[2]; U[13]; U[14]; U[21]; U[22]; U[7]; U[8]; U[17]; U[18]; U[11]; U[12]]
sig1 = d2_lst_elementstress(E, NU, x1, y1, x7, y7, x11, y11, x4, y4, x9, y9, x6, y6, p, u1)

# Element 2 (1-3-7 / 2-5-4): global DOFs 1,2  5,6  13,14  3,4  9,10  7,8
u2 = [U[1]; U[2]; U[5]; U[6]; U[13]; U[14]; U[3]; U[4]; U[9]; U[10]; U[7]; U[8]]
sig2 = d2_lst_elementstress(E, NU, x1, y1, x3, y3, x7, y7, x2, y2, x5, y5, x4, y4, p, u2)

# Element 3 (7-13-11 / 10-12-9): global DOFs 13,14  25,26  21,22  19,20  23,24  17,18
u3 = [U[13]; U[14]; U[25]; U[26]; U[21]; U[22]; U[19]; U[20]; U[23]; U[24]; U[17]; U[18]]
sig3 = d2_lst_elementstress(E, NU, x7, y7, x13, y13, x11, y11, x10, y10, x12, y12, x9, y9, p, u3)

# Element 4 (7-3-13 / 5-8-10): global DOFs 13,14  5,6  25,26  9,10  15,16  19,20
u4 = [U[13]; U[14]; U[5]; U[6]; U[25]; U[26]; U[9]; U[10]; U[15]; U[16]; U[19]; U[20]]
sig4 = d2_lst_elementstress(E, NU, x7, y7, x3, y3, x13, y13, x5, y5, x8, y8, x10, y10, p, u4)

# Principal stresses
s1 = d2_lst_elementpstress(sig1)
s2 = d2_lst_elementpstress(sig2)
s3 = d2_lst_elementpstress(sig3)
s4 = d2_lst_elementpstress(sig4)

println("\nu1 ="); display(u1)
println("sig1 = $sig1")
println("σ1 = $(s1[1]), σ2 = $(s1[2]), θ = $(s1[3])°")

println("\nu2 ="); display(u2)
println("sig2 = $sig2")
println("σ1 = $(s2[1]), σ2 = $(s2[2]), θ = $(s2[3])°")

println("\nu3 ="); display(u3)
println("sig3 = $sig3")
println("σ1 = $(s3[1]), σ2 = $(s3[2]), θ = $(s3[3])°")

println("\nu4 ="); display(u4)
println("sig4 = $sig4")
println("σ1 = $(s4[1]), σ2 = $(s4[2]), θ = $(s4[3])°")

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Sum Fx: $(sum(F[1:2:end])) (should ≈ 0)")
println("Sum Fy: $(sum(F[2:2:end])) (should = 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from the Solutions Manual problem_12_1.m run under Octave
# (Symbolic pkg v3.2.2, SymPy 1.14.0) — see Doc/Kattan/Solutions-Manual/
# Node 2 displacements (m)
@assert isapprox(u[1], 3.4997e-6; rtol=1e-2) "Ux2 mismatch: $(u[1])"
@assert isapprox(u[2], 5.9026e-7; rtol=1e-2) "Uy2 mismatch: $(u[2])"

# Node 3 displacements (m)
@assert isapprox(u[3], 7.0058e-6; rtol=1e-2) "Ux3 mismatch: $(u[3])"
@assert isapprox(u[4], 4.1514e-7; rtol=1e-2) "Uy3 mismatch: $(u[4])"

# Node 7 (center) displacements (m)
@assert isapprox(u[9], 3.4535e-6; rtol=1e-2) "Ux7 mismatch: $(u[9])"
@assert isapprox(u[10], 0.0; atol=1e-10) "Uy7 mismatch: $(u[10])"

# Node 8 displacements (m) — max x-displacement
@assert isapprox(u[11], 7.0799e-6; rtol=1e-2) "Ux8 mismatch: $(u[11])"
@assert isapprox(u[12], 0.0; atol=1e-10) "Uy8 mismatch: $(u[12])"

# Node 13 displacements (m)
@assert isapprox(u[19], 7.0058e-6; rtol=1e-2) "Ux13 mismatch: $(u[19])"
@assert isapprox(u[20], -4.1514e-7; rtol=1e-2) "Uy13 mismatch: $(u[20])"

# Reactions at fixed nodes 1, 6, 11
@assert isapprox(F[1], -3.4469; rtol=1e-2) "Fx1 mismatch: $(F[1])"
@assert isapprox(F[2], -1.5335; rtol=1e-2) "Fy1 mismatch: $(F[2])"
@assert isapprox(F[11], -11.8562; rtol=1e-2) "Fx6 mismatch: $(F[11])"
@assert isapprox(F[21], -3.4469; rtol=1e-2) "Fx11 mismatch: $(F[21])"
@assert isapprox(F[22], 1.5335; rtol=1e-2) "Fy11 mismatch: $(F[22])"

# Element 1 stresses (left-bottom triangle)
@assert isapprox(sig1[1], 2970.2; rtol=1e-2) "σxx1 mismatch: $(sig1[1])"
@assert isapprox(sig1[2], 506.7; rtol=1e-2) "σyy1 mismatch: $(sig1[2])"
@assert isapprox(sig1[3], 0.0; atol=1e-10) "τxy1 mismatch: $(sig1[3])"

# Element 2 stresses (bottom-right triangle)
@assert isapprox(sig2[1], 3008.8; rtol=1e-2) "σxx2 mismatch: $(sig2[1])"
@assert isapprox(sig2[2], -21.3; rtol=1e-2) "σyy2 mismatch: $(sig2[2])"
@assert isapprox(sig2[3], 10.5; rtol=1e-2) "τxy2 mismatch: $(sig2[3])"

# Element 3 stresses (top-left triangle)
@assert isapprox(sig3[1], 3008.8; rtol=1e-2) "σxx3 mismatch: $(sig3[1])"
@assert isapprox(sig3[2], -21.3; rtol=1e-2) "σyy3 mismatch: $(sig3[2])"
@assert isapprox(sig3[3], -10.5; rtol=1e-2) "τxy3 mismatch: $(sig3[3])"

# Element 4 stresses (top-right triangle)
@assert isapprox(sig4[1], 3012.2; rtol=1e-2) "σxx4 mismatch: $(sig4[1])"
@assert isapprox(sig4[2], 26.5; rtol=1e-2) "σyy4 mismatch: $(sig4[2])"
@assert isapprox(sig4[3], 0.0; atol=1e-10) "τxy4 mismatch: $(sig4[3])"

println("\nAll golden assertions passed ✓")
