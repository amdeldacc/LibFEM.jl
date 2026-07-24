#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 3.3 — Linear Bar with a Spring (Fig. 3.6)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#                                  P
#                  E, A          ----->         k
# |/----o========================o---------/\/\/\-----o----\|
# |/    1                        2                    3    \|
# |/    <-------- 2 m --------->                           \|
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacement at node 2
#   3. Reactions at nodes 1 and 3
#   4. Stress in the bar
#   5. Force in the spring
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 200e6
A = 0.01
L = 2.0
k_spring = 1000.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d1_truss_elementstiffness(E, A, L)
k2 = d1_spring_elementstiffness(k_spring)

println("k1 (bar) =")
display(k1)
println("k2 (spring) =")
display(k2)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(3, 3)
K = d1_truss_assemble(K, k1, 1, 2)
K = d1_spring_assemble(K, k2, 2, 3)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
k = K[2:2, 2:2]
f = [25.0]

u = k \ f
U = [0.0; u; 0.0]
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

# ─── Post-processing ─────────────────────────────────────────
u1 = [0.0; u]
sigma1 = d1_truss_elementstress(k1, u1, A)

u2 = [u; 0.0]
f_spring = d1_spring_elementforce(k2, u2)

println("\nsigma1 =")
display(sigma1)
println("\nf_spring =")
display(f_spring)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied force P: 25.0")
println("Reaction at node 1 (F1): ", F[1])
println("Reaction at node 3 (F3): ", F[3])
println("Sum F (should be 0): ", sum(F))

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_3_3.m
@assert isapprox(u, [2.4975024975024975e-5]; rtol=1e-10) "u mismatch"
@assert isapprox(F, [-24.975024975024976, 25.0, -0.024975024975024976]; rtol=1e-10) "F mismatch"
@assert isapprox(sigma1, [-2497.5024975024976, 2497.5024975024976]; rtol=1e-10) "sigma1 mismatch"
@assert isapprox(f_spring, [0.024975024975024976, -0.024975024975024976]; rtol=1e-10) "f_spring mismatch"
