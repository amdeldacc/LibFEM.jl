#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 11.3 — Plate with 2 CST Triangles and 2 Springs
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: THIN PLATE SUPPORTED ON TWO SPRINGS (Fig 11.9)
# =============================================================================
#
#                                  w
#            +---------------------------+
#            ^   ^   ^   ^   ^   ^   ^   ^
#            |   |   |   |   |   |   |   |
#          1 O===========================O 2    - - -
#            |                       /   |        ^
#            |                   /       |        |
#            |               /           |      0.4 m
#            |           /               |        |
#            |       /                   |        |
#            |   /                       |        v
#          3 O===========================O 4    - - -
#            |                           |
#           /                           /
#           \ k                         \ k
#           /                           /
#           \                           \
#            |                           |
#          5 O                           O 6
#          -----                       -----
#          /////                       /////
#
#            |<--------- 0.7 m --------->|
#
# =============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# =============================================================================
# Assuming Node 3 is at the origin (0,0) and units are in meters:
#
#   Plate Nodes:
#     Node 1 : ( 0.0,  0.4 )
#     Node 2 : ( 0.7,  0.4 )
#     Node 3 : ( 0.0,  0.0 )  -> Connected to Left Spring
#     Node 4 : ( 0.7,  0.0 )  -> Connected to Right Spring
#
#   Ground Support Nodes:
#     Node 5 : ( 0.0, -Ls )   -> Fixed Support (Ls = spring un-stretched length)
#     Node 6 : ( 0.7, -Ls )   -> Fixed Support
#
#   Loads & Elements:
#     Distributed Load : w (upwards, +Y direction) acting on top edge 1-2.
#     Plate Elements   : 2 Linear Triangles (e.g., Nodes 1-3-2 and Nodes 3-4-2).
#     Spring Elements  : 2 Springs of stiffness k (Nodes 3-5 and Nodes 4-6).
#
# =============================================================================
# =============================================================================
# PROBLEM OVERVIEW: MIXED CST + SPRING MODEL
# =============================================================================
# Two CST triangles (plane stress) carry two point loads; two springs
# (k = 4000 kN/m each) tie the plate's bottom nodes to a fixed ground
# node (node 5). The reduced system K(1:8,1:8) is SINGULAR — see below.
#
#       17.5 kN       17.5 kN
#          |              |
#          v              v
#     1 O----------------O 2
#       | \            / |
#       |  \     2   /   |
#       |   \       /    |
#       | 1  \   /       |
#       |     \ /        |
#     3 O------X---------O 4
#       |   ~~~     ~~~  |
#       +---O---------O--+     5  GROUND (fixed: U9 = U10 = 0)
#           |         |
#         k3=4000   k4=4000
#
#     |<---- 0.7 m ---->|
#     |  0.4 m (height) |
#
# =============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# =============================================================================
# Node 5 is a ground/support node below the plate — the springs anchor
# to its DOFs (U9 = U10 = 0). It is NOT part of the CST triangles.
#
#   Fixed Node:
#     Node 5  : ground node -> Fixed Support (U9 = U10 = 0)
#
#   Loaded Nodes:
#     Node 1  : ( 0.0, 0.4 )  -> Applied Load: Fy = 17.5 kN
#     Node 2  : ( 0.7, 0.4 )  -> Applied Load: Fy = 17.5 kN
#
#   Free Nodes (load-free, spring-supported):
#     Node 3  : ( 0.0, 0.0 )  -> spring 3 (DOF 6) to ground (DOF 9)
#     Node 4  : ( 0.7, 0.0 )  -> spring 4 (DOF 8) to ground (DOF 10)
#
# =============================================================================
# FULL NODE TABLE (all 5 nodes, 2 DOF each):
# =============================================================================
#
#   DOF mapping: node n -> global DOFs (2n-1, 2n)
#   Node 1 -> DOFs 1,2      Node 3 -> DOFs 5,6      Node 5 -> DOFs 9,10
#   Node 2 -> DOFs 3,4      Node 4 -> DOFs 7,8
#
#   Node 1  : ( 0.0,  0.4)  -> Applied Load: Fy = 17.5 kN
#   Node 2  : ( 0.7,  0.4)  -> Applied Load: Fy = 17.5 kN
#   Node 3  : ( 0.0,  0.0)  -> Free (spring to node 5)
#   Node 4  : ( 0.7,  0.0)  -> Free (spring to node 5)
#   Node 5  : ground node   -> Fixed Support (U9 = U10 = 0; spring anchor)
#
# ELEMENTS (2 CST triangles + 2 springs):
#   Element 1 : CST triangle, nodes (1, 3, 2) -> global DOFs 1,2 | 5,6 | 3,4
#   Element 2 : CST triangle, nodes (2, 3, 4) -> global DOFs 3,4 | 5,6 | 7,8
#   Element 3 : Spring k3 = 4000 kN/m, DOF 6 (node 3, y) <-> DOF 9 (node 5, x)
#   Element 4 : Spring k4 = 4000 kN/m, DOF 8 (node 4, y) <-> DOF 10 (node 5, y)
#
# NOTE: The springs use DIRECT global DOF indices (6<->9 and 8<->10),
#       following Kattan's SpringAssemble convention — they do NOT follow
#       the 2-DOF-per-node node-pair scheme used by the CST triangles.
#
# =============================================================================
# Parameters:
#   Material:    E = 200 GPa (200e6 kPa), ν = 0.3
#   Thickness:   t = 0.01 m
#   Type:        Plane stress (p=1)
#   Springs:     k3 = k4 = 4000 kN/m (to ground node 5)
#   Loading:     Fy = 17.5 kN at nodes 1 and 2
#   Units:       kPa (E), kN (forces), m (coordinates) — as in the manual
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (10×10)
#   2. Displacements at nodes 1-4 (singular reduced system, rank 7)
#   3. Reactions at ground node 5 (through the springs)
#   4. Element stresses (σ_xx, σ_yy, τ_xy) for both CST triangles
#   5. Principal stresses and spring forces
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 200e6    # Young's modulus (kPa)
NU = 0.3     # Poisson's ratio
t = 0.01     # thickness (m)
p = 1        # plane stress

# ─── Node coordinates ────────────────────────────────────────
# 5 nodes, 2 DOF per node. Node 5 is the ground node (spring anchor);
# it has no mesh coordinates — the springs attach to its DOFs directly.
x1, y1 = 0.0, 0.4     # Node 1 — top-left (loaded: Fy = 17.5 kN)
x2, y2 = 0.7, 0.4     # Node 2 — top-right (loaded: Fy = 17.5 kN)
x3, y3 = 0.0, 0.0     # Node 3 — bottom-left (spring 3 to node 5)
x4, y4 = 0.7, 0.0     # Node 4 — bottom-right (spring 4 to node 5)

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_cst_elementstiffness(E, NU, t, x1, y1, x3, y3, x2, y2, p)  # 1→3→2
k2 = d2_cst_elementstiffness(E, NU, t, x2, y2, x3, y3, x4, y4, p)  # 2→3→4
k3 = d1_spring_elementstiffness(4000)   # spring 3 (kN/m)
k4 = d1_spring_elementstiffness(4000)   # spring 4 (kN/m)

println("k1 ="); display(k1)
println("k2 ="); display(k2)
println("k3 ="); display(k3)
println("k4 ="); display(k4)

# ─── Assembly ────────────────────────────────────────────────
# 5 nodes × 2 DOF = 10 DOFs (nodes 1-4 + ground node 5)
K = zeros(10, 10)
K = d2_cst_assemble(K, k1, 1, 3, 2)
K = d2_cst_assemble(K, k2, 2, 3, 4)
K = d1_spring_assemble(K, k3, 6, 9)   # node 3 (y) ↔ node 5 (x)
K = d1_spring_assemble(K, k4, 8, 10)  # node 4 (y) ↔ node 5 (y)

println("\nK (10×10 global) ="); display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: 1:8 (nodes 1-4); fixed DOFs: 9,10 (node 5, ground)
k = K[1:8, 1:8]
f = [0.0; 17.5; 0.0; 17.5; 0.0; 0.0; 0.0; 0.0]   # Fy = 17.5 kN at nodes 1, 2
u = k \ f    # k is SINGULAR (rank 7): see the note in Self-validation below
U = zeros(10)
U[1:8] = u
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nk (reduced, 8×8, singular) ="); display(k)
println("rank(k) = $(rank(k))  (rigid x-translation unconstrained)")
println("\nf ="); display(f)
println("\nu (free DOFs: nodes 1..4) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (1→3→2): global DOFs 1,2,5,6,3,4
u1 = [U[1]; U[2]; U[5]; U[6]; U[3]; U[4]]
# Element 2 (2→3→4): global DOFs 3,4,5,6,7,8
u2 = [U[3]; U[4]; U[5]; U[6]; U[7]; U[8]]
# Springs: u3 = [U(6); U(9)] and u4 = [U(8); U(10)] per the manual
u3 = [U[6]; U[9]]
u4 = [U[8]; U[10]]

sigma1 = d2_cst_elementstress(E, NU, x1, y1, x3, y3, x2, y2, p, u1)
sigma2 = d2_cst_elementstress(E, NU, x2, y2, x3, y3, x4, y4, p, u2)

# Principal stresses with the reference's single-arg atan convention
# (LinearTriangleElementPStresses.m): two-arg atan (as in
# d2_cst_elementpstress) would flip θ to 90° for this σyy-dominated
# stress state, failing the Octave comparison.
function pstress(sigma)
    R = (sigma[1] + sigma[2]) / 2
    Q = ((sigma[1] - sigma[2]) / 2)^2 + sigma[3] * sigma[3]
    M = 2 * sigma[3] / (sigma[1] - sigma[2])
    return [R + sqrt(Q); R - sqrt(Q); (atan(M) / 2) * 180 / pi]
end
s1 = pstress(sigma1)
s2 = pstress(sigma2)

f3 = d1_spring_elementforce(k3, u3)
f4 = d1_spring_elementforce(k4, u4)

println("\nu1 ="); display(u1)
println("sigma1 = $sigma1")
println("σ1 = $(s1[1]), σ2 = $(s1[2]), θ = $(s1[3])°")

println("\nu2 ="); display(u2)
println("sigma2 = $sigma2")
println("σ1 = $(s2[1]), σ2 = $(s2[2]), θ = $(s2[3])°")

println("\nu3 = $u3,  f3 = $f3")
println("u4 = $u4,  f4 = $f4")

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Sum F: $(sum(F)) (should = 0, incl. +35 kN applied and -35 kN spring reactions)")
println("Reaction at node 5 (x): F9  = $(F[9])  (should = -17.5 kN)")
println("Reaction at node 5 (y): F10 = $(F[10]) (should = -17.5 kN)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from Kattan's Solutions Manual (Problem 11.3):
# K printed with scale 1.0e+006, F unscaled, u y-values at 4 d.p.
#
# NOTE ON THE SINGULARITY: k = K[1:8,1:8] is SINGULAR (rank 7) — nothing
# restrains the plate's rigid x-translation, so the x-components of u are
# an ARBITRARY particular solution chosen by the solver (the manual's
# Octave prints 0.0002; Julia's LU here gives ≈ -0.00028). They are NOT
# asserted; only the deterministic y-components are checked below.

# Global stiffness K (10×10, manual scale 1.0e+006)
expected_K = [ 1.3010  -0.7143  -0.6279   0.3846  -0.6731   0.3297   0.0      0.0      0.0      0.0;
              -0.7143   2.1429   0.3297  -0.2198   0.3846  -1.9231   0.0      0.0      0.0      0.0;
              -0.6279   0.3297   1.3010   0.0      0.0     -0.7143  -0.6731   0.3846   0.0      0.0;
               0.3846  -0.2198   0.0      2.1429  -0.7143   0.0      0.3297  -1.9231   0.0      0.0;
              -0.6731   0.3846   0.0     -0.7143   1.3010   0.0     -0.6279   0.3297   0.0      0.0;
               0.3297  -1.9231  -0.7143   0.0      0.0      2.1469   0.3846  -0.2198  -0.0040   0.0;
               0.0      0.0     -0.6731   0.3297  -0.6279   0.3846   1.3010  -0.7143   0.0      0.0;
               0.0      0.0      0.3846  -1.9231   0.3297  -0.2198  -0.7143   2.1469   0.0     -0.0040;
               0.0      0.0      0.0      0.0      0.0     -0.0040   0.0      0.0      0.0040   0.0;
               0.0      0.0      0.0      0.0      0.0      0.0      0.0     -0.0040   0.0      0.0040] .* 1e6
@assert isapprox(K, expected_K; rtol=1e-2) "K mismatch: max err $(maximum(abs.(K .- expected_K)))"

# Nodal forces F (10×1, no scale)
expected_F = [0.0; 17.5; 0.0; 17.5; 0.0; 0.0; 0.0; 0.0; -17.5; -17.5]
@assert isapprox(F, expected_F; rtol=1e-2) "F mismatch: max err $(maximum(abs.(F .- expected_F)))"

# Displacements: y-components ONLY (x-components are solver-dependent —
# see the singularity note above). The manual prints 0.0044 at 4 d.p.;
# the exact values are 0.004385 (nodes 1, 2) and 0.004375 (nodes 3, 4).
@assert isapprox(u[2], 0.004385; rtol=1e-2) "u[2] (node 1, y) mismatch: $(u[2])"
@assert isapprox(u[4], 0.004385; rtol=1e-2) "u[4] (node 2, y) mismatch: $(u[4])"
@assert isapprox(u[6], 0.004375; rtol=1e-2) "u[6] (node 3, y) mismatch: $(u[6])"
@assert isapprox(u[8], 0.004375; rtol=1e-2) "u[8] (node 4, y) mismatch: $(u[8])"

# Spring forces (k × Δ = 4000 × 0.004375 = 17.5 ≈ 17.5)
@assert isapprox(f3, [17.5; -17.5]; rtol=1e-2) "f3 mismatch: max err $(maximum(abs.(f3 .- [17.5; -17.5])))"
@assert isapprox(f4, [17.5; -17.5]; rtol=1e-2) "f4 mismatch: max err $(maximum(abs.(f4 .- [17.5; -17.5])))"

# Element stresses (deterministic: rigid motion contributes zero strain).
# σ_yy = 5000 kPa for both triangles; σ_xx and τ_xy are ~1e-10 numerical
# zeros, hence the tiny atol.
@assert isapprox(sigma1, [0.0, 5000.0, 0.0]; rtol=1e-2, atol=1e-6) "sigma1 mismatch: max err $(maximum(abs.(sigma1 .- [0.0, 5000.0, 0.0])))"
@assert isapprox(sigma2, [0.0, 5000.0, 0.0]; rtol=1e-2, atol=1e-6) "sigma2 mismatch: max err $(maximum(abs.(sigma2 .- [0.0, 5000.0, 0.0])))"

# Principal stresses: σ1 = 5000 kPa, σ2 ≈ 0 for both elements
@assert isapprox(s1, [5000.0, 0.0, 0.0]; rtol=1e-2, atol=1e-6) "s1 mismatch: max err $(maximum(abs.(s1 .- [5000.0, 0.0, 0.0])))"
@assert isapprox(s2, [5000.0, 0.0, 0.0]; rtol=1e-2, atol=1e-6) "s2 mismatch: max err $(maximum(abs.(s2 .- [5000.0, 0.0, 0.0])))"

# Equilibrium: no net force; spring reactions at ground node 5
@assert isapprox(sum(F), 0.0; atol=1e-6) "sum(F) = $(sum(F)) ≠ 0"
@assert isapprox(F[9], -17.5; rtol=1e-2) "F[9] (node 5, x reaction) mismatch: $(F[9])"
@assert isapprox(F[10], -17.5; rtol=1e-2) "F[10] (node 5, y reaction) mismatch: $(F[10])"

println("\nAll golden assertions passed ✓")
