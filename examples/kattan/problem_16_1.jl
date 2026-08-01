#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 16.1 — Thin Plate Cantilever Under Axial Nodal Loads
#               (2 Linear 8-node Brick Elements)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# ===============================================================================
# PROBLEM OVERVIEW: DISCRETIZATION INTO TWO LINEAR BRICKS (Fig 16.5)
# ===============================================================================
# Note: Isometric view (Isoview) of a 3D plate discretized into 2 Hexahedral
# (Brick) elements. The exact connectivity is provided in the table below.
#
#               Y (Up)
#               ^
#               | 3                   7                   11 (Top-Back)
#         //|---O===================O===================O
#         //|  /|                 / |                 / |
#         //| / |               /   |               /   |
#         //|/  |             /     |             /     |
#       4 //O===================O===================O 12 (Top-Front)
#         //|   |             8 |   |               |   |
#         //|   |               |   |               |   |
#         //|   |   2           |   |   6           |   |   10 (Bottom-Back)
#         //|   O - - - - - - - |- -O - - - - - - - |- -O ----> X (Right)
#         //|  /                |  /                |  /
#         //| /                 | /                 | /
#         //|/                  |/                  |/
#       1 //O===================O===================O 9 (Bottom-Front)
#          /                    5
#         v Z (Forward)
#
# ===============================================================================
# NODE COORDINATES & BOUNDARY CONDITIONS:
# ===============================================================================
# Assuming Node 2 is at the origin (0,0,0) and the block dimensions are (L, H, W):
#
#   Fixed Wall Nodes (Left Face, X = 0):
#     Node 1 : ( 0, 0, W ) -> Fixed Support (Encastrement)
#     Node 2 : ( 0, 0, 0 ) -> Fixed Support
#     Node 3 : ( 0, H, 0 ) -> Fixed Support
#     Node 4 : ( 0, H, W ) -> Fixed Support
#
#   Middle Nodes (X = L/2):
#     Nodes 5, 6, 7, 8
#
#   Right Face Nodes (X = L):
#     Nodes 9, 10, 11, 12
#
# ===============================================================================
# ELEMENT CONNECTIVITY (TABLE 16.2):
# ===============================================================================
# Element    Node i  Node j  Node m  Node n  Node p  Node q  Node r  Node s
# Number
# -------------------------------------------------------------------------------
#    1          1       2       3       4       5       6       7       8
#    2          5       6       7       8       9      10      11      12
# ===============================================================================
# Parameters:
#   Material:  E = 210 GPa, ν = 0.3
#   Type:      3D (linear brick, 8-node trilinear hexahedron)
#   Loading:   Axial forces at the free-end face nodes 9..12:
#              Fx = 4.6875 kN each (total 18.75 kN)
#   Supports:  Face nodes 1, 2, 3, 4 fully fixed (DOFs 1:12)
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (36 × 36)
#   2. Displacements at the 24 free DOFs (nodes 5..12)
#   3. Reactions at the 12 fixed DOFs (nodes 1..4)
# ═══════════════════════════════════════════════════════════════
# NOTE ON THE SOLUTIONS MANUAL: the book assembles its symbolic
# COMPONENT-major element matrices through the NODE-major
# LinearBrickAssemble.m. The resulting global K is inconsistent and its
# reduction k = K(13:36,13:36) is SINGULAR (rank 23/24, RCOND ~ 1.5e-17),
# so the manual's printed displacements (u = 1.57e8 m) are garbage.
# This port assembles the physically-correct NODE-major stiffness; the
# goldens below are Julia-computed and are verified self-consistently
# (equilibrium K·U = F, reaction balance). See docs/adr/.
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6    # Young's modulus (kPa)
NU = 0.3     # Poisson's ratio
L, H, T = 0.5, 0.25, 0.025   # length, height, thickness (m)

# ─── Node coordinates ────────────────────────────────────────
# Face X = 0 (fixed)
x1, y1, z1 = 0.0,    0.0,    T       # Node 1
x2, y2, z2 = 0.0,    0.0,    0.0     # Node 2
x3, y3, z3 = 0.0,    H,      0.0     # Node 3
x4, y4, z4 = 0.0,    H,      T       # Node 4
# Face X = 0.25
x5, y5, z5 = L/2,    0.0,    T       # Node 5
x6, y6, z6 = L/2,    0.0,    0.0     # Node 6
x7, y7, z7 = L/2,    H,      0.0     # Node 7
x8, y8, z8 = L/2,    H,      T       # Node 8
# Face X = 0.5 (loaded)
x9,  y9,  z9  = L,    0.0,    T       # Node 9
x10, y10, z10 = L,    0.0,    0.0     # Node 10
x11, y11, z11 = L,    H,      0.0     # Node 11
x12, y12, z12 = L,    H,      T       # Node 12

# ─── Element stiffness matrices ──────────────────────────────
# NOTE: d3_brick_elementstiffness expects the LOCAL node order J1..J8,
# which maps to the problem's M1..M8 as:
#   J1=M2, J2=M6, J3=M7, J4=M3, J5=M1, J6=M5, J7=M8, J8=M4
# (J-order = bottom face CCW from (0,0,0), top face CCW from (0,0,T)).
# k1: global nodes (2,6,7,3,1,5,8,4)   -> brick X in [0, 0.25]
# k2: global nodes (6,10,11,7,5,9,12,8) -> brick X in [0.25, 0.5]
k1 = d3_brick_elementstiffness(E, NU, x2,y2,z2, x6,y6,z6, x7,y7,z7, x3,y3,z3, x1,y1,z1, x5,y5,z5, x8,y8,z8, x4,y4,z4)
k2 = d3_brick_elementstiffness(E, NU, x6,y6,z6, x10,y10,z10, x11,y11,z11, x7,y7,z7, x5,y5,z5, x9,y9,z9, x12,y12,z12, x8,y8,z8)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(36, 36)
K = d3_brick_assemble(K, k1, 2, 6, 7, 3, 1, 5, 8, 4)
K = d3_brick_assemble(K, k2, 6, 10, 11, 7, 5, 9, 12, 8)

# ─── Solve ───────────────────────────────────────────────────
# Fixed DOFs: 1:12 (nodes 1..4).  Free DOFs: 13:36 (nodes 5..12).
free = 13:36
fixed = 1:12
k = K[free, free]
f = zeros(24)
f[13] = 4.6875   # node 9,  Fx   (free DOF 13 = global DOF 25)
f[16] = 4.6875   # node 10, Fx   (free DOF 16 = global DOF 28)
f[19] = 4.6875   # node 11, Fx   (free DOF 19 = global DOF 31)
f[22] = 4.6875   # node 12, Fx   (free DOF 22 = global DOF 34)

u = k \ f
U = zeros(36)
U[free] = u
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nu (free DOFs, m) ="); display(u)
println("\nU (all DOFs, m) ="); display(U)
println("\nF (global forces, kN) ="); display(F)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
sum_fx = sum(F[1:3:36])
sum_fy = sum(F[2:3:36])
sum_fz = sum(F[3:3:36])
println("Sum Fx: $sum_fx (should ≈ 0)")
println("Sum Fy: $sum_fy (should ≈ 0)")
println("Sum Fz: $sum_fz (should ≈ 0)")
println("Applied load total: $(f[13]+f[16]+f[19]+f[22]) kN (should = 18.75)")

# ─── Self-validation ─────────────────────────────────────────
# The Solutions Manual's own solve is singular (see header NOTE), so the
# goldens below are Julia-computed on the physically-correct assembly and
# verified via the equilibrium/reaction-balance assertions above.

# Displacements (m) — free DOFs 13:36, nodes 5..12 (Julia-computed goldens)
@assert isapprox(u[1],  3.1958828389624026e-6; rtol=1e-6) "Ux5 mismatch: $(u[1])"
@assert isapprox(u[2],  6.072461518759357e-7;  rtol=1e-6) "Uy5 mismatch: $(u[2])"
@assert isapprox(u[3], -6.593376152285259e-8;  rtol=1e-6) "Uz5 mismatch: $(u[3])"
@assert isapprox(u[4],  3.195882838962374e-6;  rtol=1e-6) "Ux6 mismatch: $(u[4])"
@assert isapprox(u[5],  6.0724615187595e-7;    rtol=1e-6) "Uy6 mismatch: $(u[5])"
@assert isapprox(u[6],  6.593376152252052e-8;  rtol=1e-6) "Uz6 mismatch: $(u[6])"
@assert isapprox(u[7],  3.1958828389625005e-6; rtol=1e-6) "Ux7 mismatch: $(u[7])"
@assert isapprox(u[8], -6.072461518760465e-7;  rtol=1e-6) "Uy7 mismatch: $(u[8])"
@assert isapprox(u[9],  6.593376152266689e-8;  rtol=1e-6) "Uz7 mismatch: $(u[9])"
@assert isapprox(u[10], 3.1958828389625064e-6; rtol=1e-6) "Ux8 mismatch: $(u[10])"
@assert isapprox(u[11],-6.072461518760609e-7;  rtol=1e-6) "Uy8 mismatch: $(u[11])"
@assert isapprox(u[12],-6.593376152271287e-8;  rtol=1e-6) "Uz8 mismatch: $(u[12])"
@assert isapprox(u[13], 6.8214927696327516e-6; rtol=1e-6) "Ux9 mismatch: $(u[13])"
@assert isapprox(u[14], 5.197306274629394e-7;  rtol=1e-6) "Uy9 mismatch: $(u[14])"
@assert isapprox(u[15],-4.829659198604257e-8;  rtol=1e-6) "Uz9 mismatch: $(u[15])"
@assert isapprox(u[16], 6.821492769632714e-6;  rtol=1e-6) "Ux10 mismatch: $(u[16])"
@assert isapprox(u[17], 5.197306274629792e-7;  rtol=1e-6) "Uy10 mismatch: $(u[17])"
@assert isapprox(u[18], 4.829659198502911e-8;  rtol=1e-6) "Uz10 mismatch: $(u[18])"
@assert isapprox(u[19], 6.821492769632977e-6;  rtol=1e-6) "Ux11 mismatch: $(u[19])"
@assert isapprox(u[20],-5.197306274634197e-7;  rtol=1e-6) "Uy11 mismatch: $(u[20])"
@assert isapprox(u[21], 4.829659198543291e-8;  rtol=1e-6) "Uz11 mismatch: $(u[21])"
@assert isapprox(u[22], 6.821492769632987e-6;  rtol=1e-6) "Ux12 mismatch: $(u[22])"
@assert isapprox(u[23],-5.197306274634598e-7;  rtol=1e-6) "Uy12 mismatch: $(u[23])"
@assert isapprox(u[24],-4.829659198564395e-8;  rtol=1e-6) "Uz12 mismatch: $(u[24])"

# Reactions (kN) at fixed nodes 1..4 (DOFs 1:12) — Julia-computed goldens
@assert isapprox(F[1],  -4.687500000000182; rtol=1e-6) "Rx1 mismatch: $(F[1])"
@assert isapprox(F[2],  -1.474035604056745; rtol=1e-6) "Ry1 mismatch: $(F[2])"
@assert isapprox(F[3],  13.379026616555146; rtol=1e-6) "Rz1 mismatch: $(F[3])"
@assert isapprox(F[4],  -4.687499999999687; rtol=1e-6) "Rx2 mismatch: $(F[4])"
@assert isapprox(F[5],  -1.4740356040567458; rtol=1e-6) "Ry2 mismatch: $(F[5])"
@assert isapprox(F[6],  -13.379026616555135; rtol=1e-6) "Rz2 mismatch: $(F[6])"
@assert isapprox(F[7],  -4.687499999999884; rtol=1e-6) "Rx3 mismatch: $(F[7])"
@assert isapprox(F[8],  1.4740356040567403; rtol=1e-6) "Ry3 mismatch: $(F[8])"
@assert isapprox(F[9],  -13.379026616555302; rtol=1e-6) "Rz3 mismatch: $(F[9])"
@assert isapprox(F[10], -4.687500000000153; rtol=1e-6) "Rx4 mismatch: $(F[10])"
@assert isapprox(F[11], 1.4740356040567467; rtol=1e-6) "Ry4 mismatch: $(F[11])"
@assert isapprox(F[12], 13.379026616555304; rtol=1e-6) "Rz4 mismatch: $(F[12])"

# Applied loads (echoed at free DOFs)
@assert isapprox(F[25], 4.6875; rtol=1e-6) "Fx9 mismatch: $(F[25])"
@assert isapprox(F[28], 4.6875; rtol=1e-6) "Fx10 mismatch: $(F[28])"
@assert isapprox(F[31], 4.6875; rtol=1e-6) "Fx11 mismatch: $(F[31])"
@assert isapprox(F[34], 4.6875; rtol=1e-6) "Fx12 mismatch: $(F[34])"

# Equilibrium: net force per direction must vanish
@assert abs(sum_fx) < 1e-8 "Fx not balanced: $sum_fx"
@assert abs(sum_fy) < 1e-8 "Fy not balanced: $sum_fy"
@assert abs(sum_fz) < 1e-8 "Fz not balanced: $sum_fz"

println("\nAll golden assertions passed ✓")
