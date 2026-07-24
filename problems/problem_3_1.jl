#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 3.1 — Three-Bar Structure (Fig. 3.5)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#                   P1
#                 <-----
# |/----o==============o=============================o==============o-----> P2
# |/    1              2                             3              4
# |/    |<--- 1 m ---->|<----------- 2 m ----------->|<---- 1 m --->|
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at nodes 2, 3, and 4
#   3. Reaction at node 1
#   4. Stress in each bar
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 70e6
A = 0.005
L1 = 1.0
L2 = 2.0
L3 = 1.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d1_truss_elementstiffness(E, A, L1)
k2 = d1_truss_elementstiffness(E, A, L2)
k3 = d1_truss_elementstiffness(E, A, L3)

println("k1 =")
display(k1)
println("k2 =")
display(k2)
println("k3 =")
display(k3)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(4, 4)
K = d1_truss_assemble(K, k1, 1, 2)
K = d1_truss_assemble(K, k2, 2, 3)
K = d1_truss_assemble(K, k3, 3, 4)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
k = K[2:4, 2:4]
f = [-10.0; 0.0; 15.0]

u = k \ f
U = [0.0; u]
F = K * U

println("\nk =")
display(k)
println("\nf =")
display(f)
println("\nu =")
display(u)
println("\nU =")
display(U)
println("\nF =")
display(F)

# ─── Post-processing: stresses ───────────────────────────────
u1 = [0.0; U[2]]
sigma1 = d1_truss_elementstress(k1, u1, A)

u2 = [U[2]; U[3]]
sigma2 = d1_truss_elementstress(k2, u2, A)

u3 = [U[3]; U[4]]
sigma3 = d1_truss_elementstress(k3, u3, A)

println("\nsigma1 =")
display(sigma1)
println("\nsigma2 =")
display(sigma2)
println("\nsigma3 =")
display(sigma3)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied forces: P1 = -10 (node 2), P2 = 15 (node 4)")
println("Reaction at node 1 (F1): ", F[1])
println("Sum of forces = ", F[1] + f[1] + f[3], " (should be 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_3_1.m
@assert isapprox(u, [1.4285714285714285e-5, 0.0001, 0.00014285714285714287]; rtol=1e-10) "u mismatch"
@assert isapprox(F, [-5.0, -10.0, 0.0, 15.0]; rtol=1e-10) "F mismatch"
@assert isapprox(sigma1, [-1000.0, 1000.0]; rtol=1e-10) "sigma1 mismatch"
@assert isapprox(sigma2, [-3000.0, 3000.0]; rtol=1e-10) "sigma2 mismatch"
@assert isapprox(sigma3, [-3000.0, 3000.0]; rtol=1e-10) "sigma3 mismatch"
