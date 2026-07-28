#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 2.2 — Four-Element Spring System (Fig. 2.5)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#                                k
#                         +---/\/\/\---+
# |/           k          |            |           k
# |/----o----/\/\/\-------o            o-------/\/\/\----o---> P
# |/    1                 2            3                 4
#                         |            |
#                         +---/\/\/\---+
#                                k
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at nodes 2, 3, and 4
#   3. Reaction at node 1
#   4. Force in each spring
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
k_val = 170.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d1_spring_elementstiffness(k_val)
k2 = d1_spring_elementstiffness(k_val)
k3 = d1_spring_elementstiffness(k_val)
k4 = d1_spring_elementstiffness(k_val)

println("k1 =")
display(k1)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(4, 4)
K = d1_spring_assemble(K, k1, 1, 2)
K = d1_spring_assemble(K, k2, 2, 3)
K = d1_spring_assemble(K, k3, 2, 3)
K = d1_spring_assemble(K, k4, 3, 4)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
k = K[2:4, 2:4]
f = [0.0; 0.0; 25.0]

u = k \ f
U = [0.0; u]

F = K * U
# Zero out near-zero entries (same as MATLAB's abs(F) < 1e-10 → 0)
F[abs.(F) .< 1e-10] .= 0.0

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
u1 = [0.0; U[2]]
f1 = d1_spring_elementforce(k1, u1)

u2 = [U[2]; U[3]]
f2 = d1_spring_elementforce(k2, u2)

u3 = [U[2]; U[3]]
f3 = d1_spring_elementforce(k3, u3)

u4 = [U[3]; U[4]]
f4 = d1_spring_elementforce(k4, u4)

println("\nu1 =")
display(u1)
println("\nf1 =")
display(f1)
println("\nu2 =")
display(u2)
println("\nf2 =")
display(f2)
println("\nu3 =")
display(u3)
println("\nf3 =")
display(f3)
println("\nu4 =")
display(u4)
println("\nf4 =")
display(f4)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied force P: 25.0 at node 4")
println("Reaction at node 1 (F1): ", F[1])
println("Sum F (should be [25? 0 0 0?]): ", sum(F))
println("Spring force f1: ", f1)
println("Spring force f2: ", f2)
println("Spring force f3: ", f3)
println("Spring force f4: ", f4)

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_2_2.m
@assert isapprox(K, [170 -170 0 0; -170 510 -340 0; 0 -340 510 -170; 0 0 -170 170]; rtol=1e-10) "K mismatch"
@assert isapprox(k, [510 -340 0; -340 510 -170; 0 -170 170]; rtol=1e-10) "k mismatch"
@assert isapprox(f, [0.0; 0.0; 25.0]; rtol=1e-10) "f mismatch"
@assert isapprox(u, [0.14705882352941177; 0.22058823529411764; 0.36764705882352944]; rtol=1e-10) "u mismatch"
@assert isapprox(U, [0.0; 0.14705882352941177; 0.22058823529411764; 0.36764705882352944]; rtol=1e-10) "U mismatch"
@assert isapprox(F, [-25.0; 0.0; 0.0; 25.0]; rtol=1e-10) "F mismatch"
@assert isapprox(f1, [-25.0, 25.0]; rtol=1e-10) "f1 mismatch"
@assert isapprox(f2, [-12.5, 12.5]; rtol=1e-10) "f2 mismatch"
@assert isapprox(f3, [-12.5, 12.5]; rtol=1e-10) "f3 mismatch"
@assert isapprox(f4, [-25.0, 25.0]; rtol=1e-10) "f4 mismatch"
