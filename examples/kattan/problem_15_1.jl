#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 15.1 — 3D Block Under Vertical Nodal Loads
#               (6 Linear Tetrahedron Elements)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# ═══════════════════════════════════════════════════════════════
#  DISCRETIZATION OF A THIN PLATE (BRICK) INTO 6 LINEAR TETRAHEDRA  (Fig 15.4)
# ═══════════════════════════════════════════════════════════════
#   * The 3-D view below is an OBLIQUE projection of the 8-node brick.
#       - vertical  direction on screen = Y  (height)
#       - horizontal direction on screen = X  (length)
#       - up-left   slant  on screen     = Z  (thickness / depth)
#   * Each corner of the brick is labelled by its NODE NUMBER (1..8).
#   * '///'  = hatched rigid wall  ->  ENCASTREMENT (fixed support)
#
#               5 ____________ 8
#              ///|           /|
#             /// |          / |
#            ///  |         /  |
#           ///   |        /   |
#           6_____|_______7    |
#          ///    |       |    |
#          ///    |       |    |
#          ///    1_______|____4
#          ///   /        |   /
#          ///  /         |  /
#          ////          | /
#          2_____________3
#
#        ^^^^
#        HATCHED WALL  =  face X = 0  is FULLY FIXED  (nodes 1, 2, 5, 6)
#
#   Axis triad :        Y
#                       ^
#                       |
#                       |
#                       +-------> X
#                      /
#                     Z
#
#   Face panels (6 faces, 2 rows of 3) — view each face from OUTSIDE:
#      TOP   (Y = H)        FRONT (Z = T)        RIGHT (X = L)
#      5-----7              2-----4              4-----8
#      |     |              |     |              |     |
#      6-----8              6-----8              3-----7
#      diag 5-8             diag 2-8             diag 4-7
#
#      LEFT  (X = 0) FIXED  BACK  (Z = 0)        BOTTOM (Y = 0)
#      ///1-----5           1-----5              1-----2
#      ///|     |           |     |              |     |
#      ///2-----6           3-----7              3-----4
#      diag 2-5             diag 1-7             diag 1-4
#
#   DIAGONAL RULE (easy to remember):
#     - the 3 faces that touch node 8  ->  diagonal joins the opposite corner
#                                          to 8   :  5-8 , 2-8 , 4-7
#     - the 3 faces that touch node 1  ->  diagonal joins the opposite corner
#                                          to 1   :  2-5 , 1-7 , 1-4
#     - plus the INTERNAL (body) diagonal        :  1-8   (shared by ALL tets)
#
#   Let L = length (X),  H = height (Y),  T = thickness (Z).
#
#   node |   ( X ,  Y ,  Z )   |  support
#   -----+---------------------+----------
#     1  |   ( 0 ,  0 ,  0 )   |  FIXED  (encastrement)
#     2  |   ( 0 ,  0 ,  T )   |  FIXED
#     5  |   ( 0 ,  H ,  0 )   |  FIXED
#     6  |   ( 0 ,  H ,  T )   |  FIXED
#     3  |   ( L ,  0 ,  0 )   |  free
#     4  |   ( L ,  0 ,  T )   |  free
#     7  |   ( L ,  H ,  0 )   |  free
#     8  |   ( L ,  H ,  T )   |  free
#
#   Fixed face = {1,2,5,6}  (the whole wall X = 0)
#
#   The 6 tetrahedra:
#     Tet 1 :  1, 2, 5, 8     ( fixed-face tri 1-2-5  +  interior tri 2-5-8 )
#     Tet 2 :  2, 5, 6, 8     ( fixed-face tri 2-5-6  +  top   tri 5-6-8 )
#     Tet 3 :  1, 5, 7, 8     ( back  tri 1-5-7  +  top   tri 5-7-8 )
#     Tet 4 :  1, 4, 7, 8     ( right tri 4-7-8  +  bottom tri 1-4-8 )
#     Tet 5 :  1, 3, 4, 7     ( right tri 3-4-7  +  back  tri 1-3-7 )
#     Tet 6 :  1, 2, 4, 8     ( front tri 2-4-8  +  bottom tri 1-2-4 )
# ═══════════════════════════════════════════════════════════════
# Parameters:
#   Material:  E = 210 GPa, ν = 0.3
#   Type:      3D (linear tetrahedron, constant stress per element)
#   Loading:   Upward vertical forces at the top-face nodes:
#              Fy = 3.125 / 6.25 / 6.25 / 3.125 kN at nodes 3 / 4 / 7 / 8
#              (total 18.75 kN)
#   Supports:  Bottom-face nodes 1, 2, 5, 6 fully fixed (DOFs 1:6, 13:18)
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (24 × 24)
#   2. Displacements at the 12 free DOFs (top-face nodes)
#   3. Reactions at the 12 fixed DOFs (bottom-face nodes)
#   4. Element stresses (σ_xx, σ_yy, σ_zz, τ_xy, τ_yz, τ_zx) — 6 tetrahedra
#   5. Stress invariants per element + principal stresses
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6   # Young's modulus (kPa)
NU = 0.3    # Poisson's ratio

# ─── Node coordinates ────────────────────────────────────────
# Bottom face (y = 0, fixed)
x1, y1, z1 = 0.0,   0.0,  0.00   # Node 1
x2, y2, z2 = 0.025, 0.0,  0.00   # Node 2
x5, y5, z5 = 0.0,   0.0,  0.25   # Node 5
x6, y6, z6 = 0.025, 0.0,  0.25   # Node 6
# Top face (y = 0.5, loaded)
x3, y3, z3 = 0.0,   0.5,  0.00   # Node 3
x4, y4, z4 = 0.025, 0.5,  0.00   # Node 4
x7, y7, z7 = 0.0,   0.5,  0.25   # Node 7
x8, y8, z8 = 0.025, 0.5,  0.25   # Node 8

# ─── Element stiffness matrices ──────────────────────────────
# k1: nodes (1,2,4,8)   k2: (1,2,8,5)   k3: (2,8,5,6)
# k4: nodes (1,3,7,4)   k5: (1,7,5,8)   k6: (1,8,4,7)
k1 = d3_tet_elementstiffness(E, NU, x1, y1, z1, x2, y2, z2, x4, y4, z4, x8, y8, z8)
k2 = d3_tet_elementstiffness(E, NU, x1, y1, z1, x2, y2, z2, x8, y8, z8, x5, y5, z5)
k3 = d3_tet_elementstiffness(E, NU, x2, y2, z2, x8, y8, z8, x5, y5, z5, x6, y6, z6)
k4 = d3_tet_elementstiffness(E, NU, x1, y1, z1, x3, y3, z3, x7, y7, z7, x4, y4, z4)
k5 = d3_tet_elementstiffness(E, NU, x1, y1, z1, x7, y7, z7, x5, y5, z5, x8, y8, z8)
k6 = d3_tet_elementstiffness(E, NU, x1, y1, z1, x8, y8, z8, x4, y4, z4, x7, y7, z7)

println("k1 ="); display(k1)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(24, 24)
K = d3_tet_assemble(K, k1, 1, 2, 4, 8)
K = d3_tet_assemble(K, k2, 1, 2, 8, 5)
K = d3_tet_assemble(K, k3, 2, 8, 5, 6)
K = d3_tet_assemble(K, k4, 1, 3, 7, 4)
K = d3_tet_assemble(K, k5, 1, 7, 5, 8)
K = d3_tet_assemble(K, k6, 1, 8, 4, 7)

# ─── Solve ───────────────────────────────────────────────────
# Fixed DOFs: 1:6 (nodes 1, 2) and 13:18 (nodes 5, 6)
# Free DOFs:  7:12 (nodes 3, 4) and 19:24 (nodes 7, 8)
free = [7:12; 19:24]
fixed = [1:6; 13:18]
k = K[free, free]
f = zeros(12)
f[2]  = 3.125  # node 3, Fy
f[5]  = 6.25   # node 4, Fy
f[8]  = 6.25   # node 7, Fy
f[11] = 3.125  # node 8, Fy

u = k \ f
U = zeros(24)
U[free] = u
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nu (free DOFs) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element nodal displacement vectors (local node order)
u1 = [U[1:6];  U[10:12]; U[22:24]]   # nodes 1, 2, 4, 8
u2 = [U[1:6];  U[22:24]; U[13:15]]   # nodes 1, 2, 8, 5
u3 = [U[4:6];  U[22:24]; U[13:15]; U[16:18]]  # nodes 2, 8, 5, 6
u4 = [U[1:3];  U[7:9];   U[19:21]; U[10:12]]  # nodes 1, 3, 7, 4
u5 = [U[1:3];  U[19:21]; U[13:15]; U[22:24]]  # nodes 1, 7, 5, 8
u6 = [U[1:3];  U[22:24]; U[10:12]; U[19:21]]  # nodes 1, 8, 4, 7

sig1 = d3_tet_elementstress(E, NU, x1, y1, z1, x2, y2, z2, x4, y4, z4, x8, y8, z8, u1)
sig2 = d3_tet_elementstress(E, NU, x1, y1, z1, x2, y2, z2, x8, y8, z8, x5, y5, z5, u2)
sig3 = d3_tet_elementstress(E, NU, x2, y2, z2, x8, y8, z8, x5, y5, z5, x6, y6, z6, u3)
sig4 = d3_tet_elementstress(E, NU, x1, y1, z1, x3, y3, z3, x7, y7, z7, x4, y4, z4, u4)
sig5 = d3_tet_elementstress(E, NU, x1, y1, z1, x7, y7, z7, x5, y5, z5, x8, y8, z8, u5)
sig6 = d3_tet_elementstress(E, NU, x1, y1, z1, x8, y8, z8, x4, y4, z4, x7, y7, z7, u6)

# Stress invariants: I1 = trace, I2 = sum of principal minors, I3 = det
invariants(s) = (s[1] + s[2] + s[3],
                 s[1]*s[2] + s[1]*s[3] + s[2]*s[3] - s[4]^2 - s[5]^2 - s[6]^2,
                 det([s[1] s[4] s[6]; s[4] s[2] s[5]; s[6] s[5] s[3]]))

# Principal stresses (σ1 ≥ σ2 ≥ σ3) + τ_max
p1 = d3_tet_elementpstress(sig1)
p2 = d3_tet_elementpstress(sig2)
p3 = d3_tet_elementpstress(sig3)
p4 = d3_tet_elementpstress(sig4)
p5 = d3_tet_elementpstress(sig5)
p6 = d3_tet_elementpstress(sig6)

println("\nσ1 = $sig1 ; invariants = $(invariants(sig1)) ; principal = $p1")
println("σ2 = $sig2 ; invariants = $(invariants(sig2)) ; principal = $p2")
println("σ3 = $sig3 ; invariants = $(invariants(sig3)) ; principal = $p3")
println("σ4 = $sig4 ; invariants = $(invariants(sig4)) ; principal = $p4")
println("σ5 = $sig5 ; invariants = $(invariants(sig5)) ; principal = $p5")
println("σ6 = $sig6 ; invariants = $(invariants(sig6)) ; principal = $p6")

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
sum_fx = F[1] + F[4] + F[7] + F[10] + F[13] + F[16] + F[19] + F[22]
sum_fy = F[2] + F[5] + F[8] + F[11] + F[14] + F[17] + F[20] + F[23]
sum_fz = F[3] + F[6] + F[9] + F[12] + F[15] + F[18] + F[21] + F[24]
println("Sum Fx: $sum_fx (should ≈ 0)")
println("Sum Fy: $sum_fy (should = 0)")
println("Sum Fz: $sum_fz (should ≈ 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from the Solutions Manual problem_15_1.m run under Octave
# (format long g) — see Doc/Kattan/Solutions-Manual/
#
# NOTE ON UNIQUENESS: the bottom face is fully fixed, so K is non-singular
# and all 12 free displacements are unique.

# Displacements (m) — free DOFs 7:12, 19:24
# Golden u (Octave): node3 ≈ (1.8466, 6.7099, 1.4852)e-6 m, ...
@assert isapprox(u[1], 1.846590992634907e-07; rtol=1e-4) "Ux3 mismatch: $(u[1])"
@assert isapprox(u[2], 6.709937720724766e-06; rtol=1e-4) "Uy3 mismatch: $(u[2])"
@assert isapprox(u[3], 1.485208020455631e-06; rtol=1e-4) "Uz3 mismatch: $(u[3])"
@assert isapprox(u[4], 9.07262051068782e-08;  rtol=1e-4) "Ux4 mismatch: $(u[4])"
@assert isapprox(u[5], 6.698777435174929e-06; rtol=1e-4) "Uy4 mismatch: $(u[5])"
@assert isapprox(u[6], 1.489155301206617e-06; rtol=1e-4) "Uz4 mismatch: $(u[6])"
@assert isapprox(u[7], 1.831613663252598e-07; rtol=1e-4) "Ux7 mismatch: $(u[7])"
@assert isapprox(u[8], 5.809126841859452e-06; rtol=1e-4) "Uy7 mismatch: $(u[8])"
@assert isapprox(u[9], 3.188325752472113e-07; rtol=1e-4) "Uz7 mismatch: $(u[9])"
@assert isapprox(u[10], 7.408420903751547e-08; rtol=1e-4) "Ux8 mismatch: $(u[10])"
@assert isapprox(u[11], 5.794544023355245e-06; rtol=1e-4) "Uy8 mismatch: $(u[11])"
@assert isapprox(u[12], 3.173716316460239e-07; rtol=1e-4) "Uz8 mismatch: $(u[12])"

# Reactions (kN) at fixed nodes 1, 2 (F1:F6) and 5, 6 (F13:F18)
@assert isapprox(F[1],  -51.19249793433492; rtol=1e-6) "Rx1 mismatch: $(F[1])"
@assert isapprox(F[2],   -3.056522511152604; rtol=1e-6) "Ry1 mismatch: $(F[2])"
@assert isapprox(F[3],   -4.484218066705922; rtol=1e-6) "Rz1 mismatch: $(F[3])"
@assert isapprox(F[4],   51.20900702348261; rtol=1e-6) "Rx2 mismatch: $(F[4])"
@assert isapprox(F[5],   -6.318477488847259; rtol=1e-6) "Ry2 mismatch: $(F[5])"
@assert isapprox(F[6],   -3.036817407557082; rtol=1e-6) "Rz2 mismatch: $(F[6])"
@assert isapprox(F[13], -29.25534696033375; rtol=1e-6) "Rx5 mismatch: $(F[13])"
@assert isapprox(F[14],  -6.318477488848091; rtol=1e-6) "Ry5 mismatch: $(F[14])"
@assert isapprox(F[15],   4.649308958182774; rtol=1e-6) "Rz5 mismatch: $(F[15])"
@assert isapprox(F[16],  29.23883787118602; rtol=1e-6) "Rx6 mismatch: $(F[16])"
@assert isapprox(F[17],  -3.056522511151611; rtol=1e-6) "Ry6 mismatch: $(F[17])"
@assert isapprox(F[18],   2.871726516080239; rtol=1e-6) "Rz6 mismatch: $(F[18])"

# Applied loads (echoed at free DOFs)
@assert isapprox(F[8],  3.125; rtol=1e-6) "Fy3 mismatch: $(F[8])"
@assert isapprox(F[11], 6.25;  rtol=1e-6) "Fy4 mismatch: $(F[11])"
@assert isapprox(F[20], 6.25;  rtol=1e-6) "Fy7 mismatch: $(F[20])"
@assert isapprox(F[23], 3.125; rtol=1e-6) "Fy8 mismatch: $(F[23])"

# Element stresses (kPa) — constant per linear tetrahedron
# Golden (Octave): see Doc/Kattan/Solutions-Manual/problem_15_1.m
@assert isapprox(sig1[1], 1055.300907889945; rtol=1e-4) "σxx1 mismatch: $(sig1[1])"
@assert isapprox(sig1[2], 3219.521310023383; rtol=1e-4) "σyy1 mismatch: $(sig1[2])"
@assert isapprox(sig1[3], 298.1483829431006; rtol=1e-4) "σzz1 mismatch: $(sig1[3])"
@assert isapprox(sig1[4], 14.65577159418802; rtol=1e-4) "τxy1 mismatch: $(sig1[4])"
@assert isapprox(sig1[5], -51.58109208529072; rtol=1e-4) "τyz1 mismatch: $(sig1[5])"
@assert isapprox(sig1[6], -5.376644883947961; rtol=1e-4) "τzx1 mismatch: $(sig1[6])"

@assert isapprox(sig2[1], 1404.06259027454; rtol=1e-4) "σxx2 mismatch: $(sig2[1])"
@assert isapprox(sig2[2], 3276.146043973927; rtol=1e-4) "σyy2 mismatch: $(sig2[2])"
@assert isapprox(sig2[3], 1404.06259027454; rtol=1e-4) "σzz2 mismatch: $(sig2[3])"
@assert isapprox(sig2[4], 11.96744915221404; rtol=1e-4) "τxy2 mismatch: $(sig2[4])"
@assert isapprox(sig2[5], 51.26772511205002; rtol=1e-4) "τyz2 mismatch: $(sig2[5])"
@assert abs(sig2[6]) < 1e-8 "τzx2 not ≈ 0: $(sig2[6])"

# Element 3 is identical to element 2 (same shape functions, mirrored node order)
@assert isapprox(sig3, sig2; rtol=1e-12) "σ3 ≠ σ2: $sig3 vs $sig2"

@assert isapprox(sig4[1], -1.53822504246682; rtol=1e-4) "σxx4 mismatch: $(sig4[1])"
@assert isapprox(sig4[2], 2773.238816203646; rtol=1e-4) "σyy4 mismatch: $(sig4[2])"
@assert isapprox(sig4[3], -148.2451966267186; rtol=1e-4) "σzz4 mismatch: $(sig4[3])"
@assert isapprox(sig4[4], -6.226760356908926; rtol=1e-4) "τxy4 mismatch: $(sig4[4])"
@assert isapprox(sig4[5], -51.11298832903799; rtol=1e-4) "τyz4 mismatch: $(sig4[5])"
@assert isapprox(sig4[6], 12.26887024621828; rtol=1e-4) "τzx4 mismatch: $(sig4[6])"

@assert isapprox(sig5[1], 174.1851869660662; rtol=1e-4) "σxx5 mismatch: $(sig5[1])"
@assert isapprox(sig5[2], 2755.786259887622; rtol=1e-4) "σyy5 mismatch: $(sig5[2])"
@assert isapprox(sig5[3], 878.9914340561063; rtol=1e-4) "σzz5 mismatch: $(sig5[3])"
@assert isapprox(sig5[4], -17.52611599182273; rtol=1e-4) "τxy5 mismatch: $(sig5[4])"
@assert isapprox(sig5[5], 51.50372369378029; rtol=1e-4) "τyz5 mismatch: $(sig5[5])"
@assert isapprox(sig5[6], -4.719971634605372; rtol=1e-4) "τzx5 mismatch: $(sig5[6])"

@assert isapprox(sig6[1], -174.5764954185288; rtol=1e-4) "σxx6 mismatch: $(sig6[1])"
@assert isapprox(sig6[2], 2699.161525937078; rtol=1e-4) "σyy6 mismatch: $(sig6[2])"
@assert isapprox(sig6[3], -226.9227732753332; rtol=1e-4) "σzz6 mismatch: $(sig6[3])"
@assert isapprox(sig6[4], -14.83779354984654; rtol=1e-4) "τxy6 mismatch: $(sig6[4])"
@assert isapprox(sig6[5], -51.34509350356047; rtol=1e-4) "τyz6 mismatch: $(sig6[5])"
@assert isapprox(sig6[6], -10.09661651855333; rtol=1e-4) "τzx6 mismatch: $(sig6[6])"

# Stress invariants (golden from TetrahedronElementPStresses under Octave)
@assert isapprox(invariants(sig1)[1], 4572.970600856429; rtol=1e-4) "I1(σ1) mismatch"
@assert isapprox(invariants(sig1)[2], 4669190.78406686; rtol=1e-4) "I2(σ1) mismatch"
@assert isapprox(invariants(sig1)[3], 1010021416.625032; rtol=1e-4) "I3(σ1) mismatch"
@assert isapprox(invariants(sig2)[1], 6084.271224523007; rtol=1e-4) "I1(σ2) mismatch"
@assert isapprox(invariants(sig2)[2], 11168448.35917051; rtol=1e-4) "I2(σ2) mismatch"
@assert isapprox(invariants(sig2)[3], 6454675808.015096; rtol=1e-4) "I3(σ2) mismatch"
@assert isapprox(invariants(sig4)[1], 2623.455394534461; rtol=1e-4) "I1(σ4) mismatch"
@assert isapprox(invariants(sig4)[2], -417958.9998204918; rtol=1e-4) "I2(σ4) mismatch"
@assert isapprox(invariants(sig4)[3], 232527.890274289; rtol=1e-4) "I3(σ4) mismatch"
@assert isapprox(invariants(sig5)[1], 3808.962880909794; rtol=1e-4) "I1(σ5) mismatch"
@assert isapprox(invariants(sig5)[2], 3052454.872302094; rtol=1e-4) "I2(σ5) mismatch"
@assert isapprox(invariants(sig5)[3], 421146041.2244004; rtol=1e-4) "I3(σ5) mismatch"
@assert isapprox(invariants(sig6)[1], 2297.662257243216; rtol=1e-4) "I1(σ6) mismatch"
@assert isapprox(invariants(sig6)[2], -1047054.416670724; rtol=1e-4) "I2(σ6) mismatch"
@assert isapprox(invariants(sig6)[3], 107147973.668339; rtol=1e-4) "I3(σ6) mismatch"

println("\nAll golden assertions passed ✓")
