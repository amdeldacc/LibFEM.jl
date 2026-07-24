#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 2.1 — Two-Element Spring System (Fig. 2.4)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#                             P
#               k1          ----->         k2
# |/----o-----/\/\/\----------o---------/\/\/\-----o----\|
# |/    1                     2                    3    \|
# |/                                                    \|
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacement at node 2
#   3. Forces (reactions at 1,3 and internal spring forces)
#   4. Equilibrium check
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
k1_val = 200.0
k2_val = 250.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d1_spring_elementstiffness(k1_val)
k2 = d1_spring_elementstiffness(k2_val)

println("k1 =")
display(k1)
println("k2 =")
display(k2)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(3, 3)
K = d1_spring_assemble(K, k1, 1, 2)
K = d1_spring_assemble(K, k2, 2, 3)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
k = K[2:2, 2:2]
f = [10.0]

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

# ─── Post-processing: element forces ─────────────────────────
u1 = [0.0; u]
f1 = d1_spring_elementforce(k1, u1)

u2 = [u; 0.0]
f2 = d1_spring_elementforce(k2, u2)

println("\nu1 =")
display(u1)
println("\nf1 =")
display(f1)
println("\nu2 =")
display(u2)
println("\nf2 =")
display(f2)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Sum of reactions: ", sum(F[1:3:end]))
println("Applied force P: 10.0")
println("Reacted force at node 1 (F1): ", F[1])
println("Reacted force at node 3 (F3): ", F[3])
println("Spring force f1: ", f1)
println("Spring force f2: ", f2)
println("Sum F1 + F3 = ", F[1] + F[3], " (should equal -10.0)")
println("Equilibrium satisfied (round-trip): ", abs(F[1] + F[3] + 10.0) < 1e-10)

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_2_1.m
@assert isapprox(K, [200 -200 0; -200 450 -250; 0 -250 250]; rtol=1e-10) "K mismatch"
@assert isapprox(k, [450.0]; rtol=1e-10) "k mismatch"
@assert isapprox(f, [10.0]; rtol=1e-10) "f mismatch"
@assert isapprox(u, [0.022222222222222223]; rtol=1e-10) "u mismatch"
@assert isapprox(U, [0.0; 0.022222222222222223; 0.0]; rtol=1e-10) "U mismatch"
@assert isapprox(F, [-4.444444444444445; 10.0; -5.555555555555555]; rtol=1e-10) "F mismatch"
@assert isapprox(f1, [-4.444444444444445; 4.444444444444445]; rtol=1e-10) "f1 mismatch"
@assert isapprox(f2, [5.555555555555555; -5.555555555555555]; rtol=1e-10) "f2 mismatch"
