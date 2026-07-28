#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 4.2 — Quadratic Bar with a Spring (Fig. 4.4)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#                             10 kN         5 kN
#                             ---->         ---->
# |/----o---/\/\/\---o=============o=============o
# |/    1           2             3             4
# |/    |<- k=2000 ->|<-- 2m ---->|<-- 2m ----->|
#                    |<--- quadratic bar (E=70GPa, A=0.001m²) -->|
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at nodes 2, 3, and 4
#   3. Reaction at node 1
#   4. Force in the spring
#   5. Quadratic bar element stresses
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 70e6
A = 0.001
L = 4.0
k_spring = 2000.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d1_spring_elementstiffness(k_spring)
k2 = d1_quadraticbar_elementstiffness(E, A, L)

println("k1 (spring) =")
display(k1)
println("k2 (quadratic bar) =")
display(k2)

# ─── Assembly ────────────────────────────────────────────────
# Nodes: 1 (spring left), 2 (spring right / bar left), 3 (bar mid), 4 (bar right)
K = zeros(4, 4)
K = d1_spring_assemble(K, k1, 1, 2)
K = d1_quadraticbar_assemble(K, k2, 2, 4, 3)  # MATLAB: QuadBarAssemble(K,k2,2,4,3)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
k = K[2:4, 2:4]
f = [0.0; 10.0; 5.0]

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

# ─── Post-processing ─────────────────────────────────────────
u1 = [0.0; U[2]]
f1 = d1_spring_elementforce(k1, u1)

# MATLAB: QuadBarElementStresses(k2, [U(2); U(4); U(3)], A)
# i.e. nodes 2, 4, 3 in that order
u2 = [U[2]; U[4]; U[3]]
sigma2 = d1_quadraticbar_elementstress(k2, u2, A)

println("\nu1 =")
display(u1)
println("\nf1 (spring force) =")
display(f1)
println("\nsigma2 (quadratic bar stress) =")
display(sigma2)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied forces: 10 kN at node 3, 5 kN at node 4")
println("Reaction at node 1 (F1): ", F[1])
println("Sum F = ", sum(F), " (should be ", sum(f), ")")

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_4_2.m
@assert isapprox(u, [0.0075, 0.007892857142857201, 0.00807142857142863]; rtol=1e-10) "u mismatch"
@assert isapprox(F, [-15.0, 0.0, 10.0, 5.0]; rtol=1e-10) "F mismatch"
@assert isapprox(f1, [-15.0, 15.0]; rtol=1e-10) "f1 mismatch"
@assert isapprox(sigma2, [-15000.0, 5000.0, 10000.0]; rtol=1e-10) "sigma2 mismatch"
