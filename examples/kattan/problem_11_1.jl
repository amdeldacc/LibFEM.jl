#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 11.1 — Thin Plate with 4 CST Elements
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: DISCRETIZATION OF THIN PLATE (Fig 11.6)
# =============================================================================
#
#      -       4                       3
#      ^   //|-O=======================O -----> 9.375 kN
#      |   //| |   \               /   |
# 0.25 m   //| |       \       /       |
#      |   //| |           O           |
#      v   //| |       /   5   \       |
#      -   //| |   /               \   |
#          //|-O=======================O -----> 9.375 kN
#              1                       2
#
#              |<------ 0.5 m ------>|
#
# =============================================================================
# NODE COORDINATES & LOADS:
# =============================================================================
# Assuming Node 1 is at the origin (0,0) and the unit is meters:
#
#   Node 1 : ( 0.00,  0.000)  -> Fixed Support (Wall)
#   Node 2 : ( 0.50,  0.000)  -> Applied Load: Fx = +9.375 kN
#   Node 3 : ( 0.50,  0.250)  -> Applied Load: Fx = +9.375 kN
#   Node 4 : ( 0.00,  0.250)  -> Fixed Support (Wall)
#   Node 5 : ( 0.25,  0.125)  -> Center Node
#
# ELEMENTS (4 Linear Triangles):
#   Triangle 1 : Nodes 1-2-5
#   Triangle 2 : Nodes 2-3-5
#   Triangle 3 : Nodes 3-4-5
#   Triangle 4 : Nodes 4-1-5
#
# =============================================================================
# Parameters:
#   Material:    E = 210 GPa, ν = 0.3
#   Thickness:   t = 0.025 m
#   Type:        Plane stress (p=1)
#   Loading:     Fx = 9.375 kN at nodes 2 and 3 (right edge)
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at nodes 2, 3, and 5
#   3. Reactions at fixed nodes 1 and 4
#   4. Element stresses (σ_xx, σ_yy, τ_xy)
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
# 5 nodes, 2 DOF per node
x1, y1 = 0.0, 0.0      # Node 1 — fixed
x2, y2 = 0.5, 0.0      # Node 2 — free (loaded)
x3, y3 = 0.5, 0.25     # Node 3 — free (loaded)
x4, y4 = 0.0, 0.25     # Node 4 — fixed
x5, y5 = 0.25, 0.125   # Node 5 — free (center)

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_cst_elementstiffness(E, NU, t, x1, y1, x5, y5, x4, y4, p)  # 1→5→4
k2 = d2_cst_elementstiffness(E, NU, t, x1, y1, x2, y2, x5, y5, p)  # 1→2→5
k3 = d2_cst_elementstiffness(E, NU, t, x3, y3, x4, y4, x5, y5, p)  # 3→4→5
k4 = d2_cst_elementstiffness(E, NU, t, x2, y2, x3, y3, x5, y5, p)  # 2→3→5

println("k1 ="); display(k1)
println("k2 ="); display(k2)
println("k3 ="); display(k3)
println("k4 ="); display(k4)

# ─── Assembly ────────────────────────────────────────────────
# 5 nodes × 2 DOF = 10 DOFs
K = zeros(10, 10)
K = d2_cst_assemble(K, k1, 1, 5, 4)
K = d2_cst_assemble(K, k2, 1, 2, 5)
K = d2_cst_assemble(K, k3, 3, 4, 5)
K = d2_cst_assemble(K, k4, 2, 3, 5)

println("\nK (10×10 global) ="); display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: nodes 2, 3, 5 → DOFs 3:6, 9:10
# Fixed DOFs: nodes 1, 4 → DOFs 1:2, 7:8
k = [K[3:6, 3:6] K[3:6, 9:10]; K[9:10, 3:6] K[9:10, 9:10]]
f = [9.375; 0.0; 9.375; 0.0; 0.0; 0.0]  # Fx at nodes 2 and 3

u = k \ f
U = zeros(10)
U[3:6] = u[1:4]
U[9:10] = u[5:6]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nk (reduced, 6×6) ="); display(k)
println("\nf ="); display(f)
println("\nu (free DOFs: Ux2, Uy2, Ux3, Uy3, Ux5, Uy5) ="); display(u)
println("\nU ="); display(U)
println("\nF ="); display(F)

# ─── Post-processing: element stresses ───────────────────────
# Element 1 (1→5→4): global DOFs 1,2,9,10,7,8
u1 = [U[1]; U[2]; U[9]; U[10]; U[7]; U[8]]
sig1 = d2_cst_elementstress(E, NU, x1, y1, x5, y5, x4, y4, p, u1)

# Element 2 (1→2→5): global DOFs 1,2,3,4,9,10
u2 = [U[1]; U[2]; U[3]; U[4]; U[9]; U[10]]
sig2 = d2_cst_elementstress(E, NU, x1, y1, x2, y2, x5, y5, p, u2)

# Element 3 (3→4→5): global DOFs 5,6,7,8,9,10
u3 = [U[5]; U[6]; U[7]; U[8]; U[9]; U[10]]
sig3 = d2_cst_elementstress(E, NU, x3, y3, x4, y4, x5, y5, p, u3)

# Element 4 (2→3→5): global DOFs 3,4,5,6,9,10
u4 = [U[3]; U[4]; U[5]; U[6]; U[9]; U[10]]
sig4 = d2_cst_elementstress(E, NU, x2, y2, x3, y3, x5, y5, p, u4)

# Principal stresses
s1 = d2_cst_elementpstress(sig1)
s2 = d2_cst_elementpstress(sig2)
s3 = d2_cst_elementpstress(sig3)
s4 = d2_cst_elementpstress(sig4)

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
println("Sum Fx: $(sum(F[1:2:end])) (should = 18.75)")
println("Sum Fy: $(sum(F[2:2:end])) (should = 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values from Kattan's MATLAB/Solutions-Manual output
# Node 2 displacements (×10⁻⁶)
@assert isapprox(u[1], 6.928e-6; rtol=1e-2) "Ux2 mismatch: $(u[1])"
@assert isapprox(u[2], 0.714e-6; rtol=1e-2) "Uy2 mismatch: $(u[2])"

# Node 3 displacements (×10⁻⁶)
@assert isapprox(u[3], 6.928e-6; rtol=1e-2) "Ux3 mismatch: $(u[3])"
@assert isapprox(u[4], -0.714e-6; rtol=1e-2) "Uy3 mismatch: $(u[4])"

# Node 5 (center) displacements (×10⁻⁶)
@assert isapprox(u[5], 3.271e-6; rtol=1e-2) "Ux5 mismatch: $(u[5])"
@assert isapprox(u[6], 0.0; atol=1e-10) "Uy5 mismatch: $(u[6])"

# Reactions at nodes 1 and 4
@assert isapprox(F[1], -9.375; rtol=1e-2) "Fx1 mismatch: $(F[1])"
@assert isapprox(F[2], -3.754; rtol=1e-2) "Fy1 mismatch: $(F[2])"
@assert isapprox(F[7], -9.375; rtol=1e-2) "Fx4 mismatch: $(F[7])"
@assert isapprox(F[8], 3.754; rtol=1e-2) "Fy4 mismatch: $(F[8])"

# Element 1 stresses (left-bottom triangle)
@assert isapprox(sig1[1], 3019.2; rtol=1e-2) "σxx1 mismatch: $(sig1[1])"
@assert isapprox(sig1[2], 905.8; rtol=1e-2) "σyy1 mismatch: $(sig1[2])"

# Element 2 stresses (bottom-right triangle)
@assert isapprox(sig2[1], 3000.0; rtol=1e-2) "σxx2 mismatch: $(sig2[1])"
@assert isapprox(sig2[2], 300.3; rtol=1e-2) "σyy2 mismatch: $(sig2[2])"
@assert isapprox(sig2[3], -9.6; rtol=1e-2) "τxy2 mismatch: $(sig2[3])"

# Element 4 stresses (right-top triangle)
@assert isapprox(sig4[1], 2980.8; rtol=1e-2) "σxx4 mismatch: $(sig4[1])"
@assert isapprox(sig4[2], -305.1; rtol=1e-2) "σyy4 mismatch: $(sig4[2])"

println("\nAll golden assertions passed ✓")
