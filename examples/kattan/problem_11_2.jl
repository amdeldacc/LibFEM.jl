#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 11.2 — Thin Plate with 16 CST Elements (Hollow Center)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: DISCRETIZATION OF THIN PLATE WITH A HOLE (Fig 11.8)
# =============================================================================
# Note: Corrected to represent the hole in the central square (Nodes 6,7,11,10).
# This leaves exactly 16 linear triangles, matching the problem description.
#
#                                                   20 kN
#                                                     |
#    13             14             15             16  v
# //|-O==============O==============O==============O    - - -
# //| |            / |            / |            / |      ^
# //| |          /   |          /   |          /   |      |
# //| |        /     |        /     |        /     |    0.3 m
# //| |      /       |      /       |      /       |      |
# //| |    /         |    /         |    /         |      v
# //|-O==============O==============O==============O    - - -
# //| | 9          / | 10           | 11         / | 12   ^
# //| |          /   |              |          /   |      |
# //| |        /     |    [HOLE]    |        /     |    0.3 m
# //| |      /       |              |      /       |      |
# //| |    /         |              |    /         |      v
# //|-O==============O==============O==============O    - - -
# //| | 5          / | 6          / | 7          / | 8    ^
# //| |          /   |          /   |          /   |      |
# //| |        /     |        /     |        /     |    0.3 m
# //| |      /       |      /       |      /       |      |
# //| |    /         |    /         |    /         |      v
# //|-O==============O==============O==============O    - - -
#     1              2              3              4
#
#     |<--- 0.3 m -->|<--- 0.3 m -->|<--- 0.3 m -->|
#
# =============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# =============================================================================
# Assuming Node 1 is at the origin (0,0) and units are in meters:
#
#   Fixed Wall Nodes (x = 0):
#     Node 1  : ( 0.0, 0.0 )  -> Fixed Support (Encastrement)
#     Node 5  : ( 0.0, 0.3 )  -> Fixed Support
#     Node 9  : ( 0.0, 0.6 )  -> Fixed Support
#     Node 13 : ( 0.0, 0.9 )  -> Fixed Support
#
#   Loaded Node:
#     Node 16 : ( 0.9, 0.9 )  -> Applied Load: Fy = -20 kN
#
#   Hole Definition:
#     The square domain bounded by Nodes 6, 7, 11, 10 is empty (NO elements).
#     Total elements = 18 (full grid) - 2 (hole) = 16 Triangles.
#
# =============================================================================
# FULL NODE TABLE (all 16 nodes, 2 DOF each):
# =============================================================================
#
#   Node 1  : ( 0.0,  0.0)  -> Fixed Support (left column)
#   Node 2  : ( 0.3,  0.0)
#   Node 3  : ( 0.6,  0.0)
#   Node 4  : ( 0.9,  0.0)
#   Node 5  : ( 0.0,  0.3)  -> Fixed Support
#   Node 6  : ( 0.3,  0.3)
#   Node 7  : ( 0.6,  0.3)
#   Node 8  : ( 0.9,  0.3)
#   Node 9  : ( 0.0,  0.6)  -> Fixed Support
#   Node 10 : ( 0.3,  0.6)
#   Node 11 : ( 0.6,  0.6)
#   Node 12 : ( 0.9,  0.6)
#   Node 13 : ( 0.0,  0.9)  -> Fixed Support
#   Node 14 : ( 0.3,  0.9)
#   Node 15 : ( 0.6,  0.9)
#   Node 16 : ( 0.9,  0.9)  -> Applied Load: Fy = -20 kN
#
# ELEMENTS (16 Linear Triangles — ring of 8 around a hollow center):
#   Triangle 1  : Nodes 1-6-5      Triangle 9  : Nodes 7-12-11
#   Triangle 2  : Nodes 1-2-6      Triangle 10 : Nodes 7-8-12
#   Triangle 3  : Nodes 2-7-6      Triangle 11 : Nodes 9-14-13
#   Triangle 4  : Nodes 2-3-7      Triangle 12 : Nodes 9-10-14
#   Triangle 5  : Nodes 3-8-7      Triangle 13 : Nodes 10-15-14
#   Triangle 6  : Nodes 3-4-8      Triangle 14 : Nodes 10-11-15
#   Triangle 7  : Nodes 5-10-9     Triangle 15 : Nodes 11-16-15
#   Triangle 8  : Nodes 5-6-10     Triangle 16 : Nodes 11-12-16
#
# NOTE: The center square (nodes 6-7-11-10) is NOT meshed — the hollow
#       center is intentional, exactly as in the manual's problem_11_2.m.
#
# =============================================================================
# Parameters:
#   Material:    E = 70 GPa (Al), ν = 0.25
#   Thickness:   t = 0.02 m
#   Type:        Plane stress (p=1)
#   Loading:     Fy = -20 kN at node 16 (top-right corner)
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at all free nodes
#   3. Reactions at fixed nodes 1, 5, 9, 13
#   4. Element stresses (σ_xx, σ_yy, τ_xy)
#   5. Principal stresses at element centroids
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 70e6    # Young's modulus (kPa)
NU = 0.25   # Poisson's ratio
t = 0.02    # thickness (m)
p = 1       # plane stress

# ─── Node coordinates ────────────────────────────────────────
# 16 nodes, 2 DOF per node, 0.3 m spacing (0.9 m × 0.9 m plate)
x1,  y1  = 0.0, 0.0      # Node 1  — fixed
x2,  y2  = 0.3, 0.0      # Node 2  — free
x3,  y3  = 0.6, 0.0      # Node 3  — free
x4,  y4  = 0.9, 0.0      # Node 4  — free
x5,  y5  = 0.0, 0.3      # Node 5  — fixed
x6,  y6  = 0.3, 0.3      # Node 6  — free
x7,  y7  = 0.6, 0.3      # Node 7  — free
x8,  y8  = 0.9, 0.3      # Node 8  — free
x9,  y9  = 0.0, 0.6      # Node 9  — fixed
x10, y10 = 0.3, 0.6      # Node 10 — free
x11, y11 = 0.6, 0.6      # Node 11 — free
x12, y12 = 0.9, 0.6      # Node 12 — free
x13, y13 = 0.0, 0.9      # Node 13 — fixed
x14, y14 = 0.3, 0.9      # Node 14 — free
x15, y15 = 0.6, 0.9      # Node 15 — free
x16, y16 = 0.9, 0.9      # Node 16 — free (loaded)

# ─── Element stiffness matrices ──────────────────────────────
k1  = d2_cst_elementstiffness(E, NU, t, x1,  y1,  x6,  y6,  x5,  y5,  p)  # 1→6→5
k2  = d2_cst_elementstiffness(E, NU, t, x1,  y1,  x2,  y2,  x6,  y6,  p)  # 1→2→6
k3  = d2_cst_elementstiffness(E, NU, t, x2,  y2,  x7,  y7,  x6,  y6,  p)  # 2→7→6
k4  = d2_cst_elementstiffness(E, NU, t, x2,  y2,  x3,  y3,  x7,  y7,  p)  # 2→3→7
k5  = d2_cst_elementstiffness(E, NU, t, x3,  y3,  x8,  y8,  x7,  y7,  p)  # 3→8→7
k6  = d2_cst_elementstiffness(E, NU, t, x3,  y3,  x4,  y4,  x8,  y8,  p)  # 3→4→8
k7  = d2_cst_elementstiffness(E, NU, t, x5,  y5,  x10, y10, x9,  y9,  p)  # 5→10→9
k8  = d2_cst_elementstiffness(E, NU, t, x5,  y5,  x6,  y6,  x10, y10, p)  # 5→6→10
k9  = d2_cst_elementstiffness(E, NU, t, x7,  y7,  x12, y12, x11, y11, p)  # 7→12→11
k10 = d2_cst_elementstiffness(E, NU, t, x7,  y7,  x8,  y8,  x12, y12, p)  # 7→8→12
k11 = d2_cst_elementstiffness(E, NU, t, x9,  y9,  x14, y14, x13, y13, p)  # 9→14→13
k12 = d2_cst_elementstiffness(E, NU, t, x9,  y9,  x10, y10, x14, y14, p)  # 9→10→14
k13 = d2_cst_elementstiffness(E, NU, t, x10, y10, x15, y15, x14, y14, p)  # 10→15→14
k14 = d2_cst_elementstiffness(E, NU, t, x10, y10, x11, y11, x15, y15, p)  # 10→11→15
k15 = d2_cst_elementstiffness(E, NU, t, x11, y11, x16, y16, x15, y15, p)  # 11→16→15
k16 = d2_cst_elementstiffness(E, NU, t, x11, y11, x12, y12, x16, y16, p)  # 11→12→16

println("k1  ="); display(k1)
println("k2  ="); display(k2)
println("k3  ="); display(k3)
println("k4  ="); display(k4)
println("k5  ="); display(k5)
println("k6  ="); display(k6)
println("k7  ="); display(k7)
println("k8  ="); display(k8)
println("k9  ="); display(k9)
println("k10 ="); display(k10)
println("k11 ="); display(k11)
println("k12 ="); display(k12)
println("k13 ="); display(k13)
println("k14 ="); display(k14)
println("k15 ="); display(k15)
println("k16 ="); display(k16)

# ─── Assembly ────────────────────────────────────────────────
# 16 nodes × 2 DOF = 32 DOFs
K = zeros(32, 32)
K = d2_cst_assemble(K, k1,  1,  6,  5)
K = d2_cst_assemble(K, k2,  1,  2,  6)
K = d2_cst_assemble(K, k3,  2,  7,  6)
K = d2_cst_assemble(K, k4,  2,  3,  7)
K = d2_cst_assemble(K, k5,  3,  8,  7)
K = d2_cst_assemble(K, k6,  3,  4,  8)
K = d2_cst_assemble(K, k7,  5, 10,  9)
K = d2_cst_assemble(K, k8,  5,  6, 10)
K = d2_cst_assemble(K, k9,  7, 12, 11)
K = d2_cst_assemble(K, k10, 7,  8, 12)
K = d2_cst_assemble(K, k11, 9, 14, 13)
K = d2_cst_assemble(K, k12, 9, 10, 14)
K = d2_cst_assemble(K, k13, 10, 15, 14)
K = d2_cst_assemble(K, k14, 10, 11, 15)
K = d2_cst_assemble(K, k15, 11, 16, 15)
K = d2_cst_assemble(K, k16, 11, 12, 16)

println("\nK (32×32 global) ="); display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: nodes 2, 3, 4, 6, 7, 8, 10, 11, 12, 14, 15, 16
#           → DOFs 3:8, 11:16, 19:24, 27:32
# Fixed DOFs: nodes 1, 5, 9, 13 → DOFs 1:2, 9:10, 17:18, 25:26
k = [K[3:8, 3:8]  K[3:8, 11:16]  K[3:8, 19:24]  K[3:8, 27:32];
     K[11:16, 3:8] K[11:16, 11:16] K[11:16, 19:24] K[11:16, 27:32];
     K[19:24, 3:8] K[19:24, 11:16] K[19:24, 19:24] K[19:24, 27:32];
     K[27:32, 3:8] K[27:32, 11:16] K[27:32, 19:24] K[27:32, 27:32]]
f = zeros(24)
f[24] = -20.0   # Fy = -20 kN at node 16 (DOF 32)

u = k \ f
U = zeros(32)
U[3:8]    = u[1:6]
U[11:16]  = u[7:12]
U[19:24]  = u[13:18]
U[27:32]  = u[19:24]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nk (reduced, 24×24) ="); display(k)
println("\nf ="); display(f)
println("\nu (free DOFs: nodes 2,3,4, 6,7,8, 10,11,12, 14,15,16) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (1→6→5): global DOFs 1,2,11,12,9,10
u1 = [U[1]; U[2]; U[11]; U[12]; U[9]; U[10]]
sig1 = d2_cst_elementstress(E, NU, x1, y1, x6, y6, x5, y5, p, u1)

# Element 16 (11→12→16): global DOFs 21,22,23,24,31,32 (loaded corner)
u16 = [U[21]; U[22]; U[23]; U[24]; U[31]; U[32]]
sig16 = d2_cst_elementstress(E, NU, x11, y11, x12, y12, x16, y16, p, u16)

# Principal stresses
s1 = d2_cst_elementpstress(sig1)
s16 = d2_cst_elementpstress(sig16)

println("\nu1 ="); display(u1)
println("sig1 = $sig1")
println("σ1 = $(s1[1]), σ2 = $(s1[2]), θ = $(s1[3])°")

println("\nu16 ="); display(u16)
println("sig16 = $sig16")
println("σ1 = $(s16[1]), σ2 = $(s16[2]), θ = $(s16[3])°")

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Sum Fx: $(sum(F[1:2:end])) (should = 0)")
println("Sum Fy: $(sum(F[2:2:end])) (should = 0, incl. -20 kN applied load)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from Kattan's MATLAB/Solutions-Manual output (Problem 11.2)
# u printed with scale 1.0e-003, F unscaled, k1 with scale 1.0e+006

# Displacements u (24×1, manual scale 1.0e-003)
expected_u = [-0.0200, -0.0225, -0.0291, -0.0581, -0.0305, -0.0854,
              -0.0008, -0.0173, -0.0072, -0.0585, -0.0077, -0.0867,
               0.0001, -0.0176,  0.0010, -0.0639,  0.0064, -0.0960,
               0.0207, -0.0199,  0.0346, -0.0635,  0.0356, -0.1167] .* 1e-3
@assert isapprox(u, expected_u; rtol=1e-2) "u mismatch: max err $(maximum(abs.(u .- expected_u)))"

# Nodal forces F (32×1, no scale)
expected_F = [18.8054, 1.0788, 0, 0, 0, 0, 0, 0,
               1.3366, 9.2538, 0, 0, 0, 0, 0, 0,
               0.9105, 0.2247, 0, 0, 0, 0, 0, 0,
              -21.0525, 9.4427, 0, 0, 0, 0, 0, -20.0000]
@assert isapprox(F, expected_F; rtol=1e-2) "F mismatch: max err $(maximum(abs.(F .- expected_F)))"

# Element 1 stiffness k1 (6×6, manual scale 1.0e+006)
expected_k1 = [0.2800   0       0      -0.2800  -0.2800   0.2800;
               0       0.7467  -0.1867  0        0.1867  -0.7467;
               0      -0.1867   0.7467  0       -0.7467   0.1867;
              -0.2800  0        0       0.2800   0.2800  -0.2800;
              -0.2800  0.1867  -0.7467  0.2800   1.0267  -0.4667;
               0.2800 -0.7467   0.1867 -0.2800  -0.4667   1.0267] .* 1e6
@assert isapprox(k1, expected_k1; rtol=1e-2) "k1 mismatch: max err $(maximum(abs.(k1 .- expected_k1)))"

println("\nAll golden assertions passed ✓")
