#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 7.1 — Two-Span Beam with Three Supports (Fig. 7.5)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#     Node 1 (fixed v)   Node 2 (fixed v, -15 kN-m)   Node 3 (fixed v)
#        O====================O============================O
#               L1 = 3.5 m               L2 = 2 m
#
#     E = 200 GPa, I = 70e-5 m^4
#     Load: -15 kN-m applied at node 2 (rotation DOF)
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Rotations at nodes 1, 2, and 3
#   3. Reactions (shear and moment at each node)
#   4. Element forces for each beam element
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 200e6
I = 70e-5
L1 = 3.5
L2 = 2.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_beam_elementstiffness(E, I, L1)
k2 = d2_beam_elementstiffness(E, I, L2)

println("k1 =")
display(k1)
println("k2 =")
display(k2)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(6, 6)
K = d2_beam_assemble(K, k1, 1, 2)
K = d2_beam_assemble(K, k2, 2, 3)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: rotations at nodes 1, 2, 3 = DOFs 2, 4, 6 (even-numbered)
k = K[[2, 4, 6], [2, 4, 6]]
f = [0.0; -15.0; 0.0]

u = k \ f
U = zeros(6)
U[[2, 4, 6]] = u
F = K * U

println("\nk (reduced) =")
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
u1 = [U[1]; U[2]; U[3]; U[4]]
f1 = d2_beam_elementforces(k1, u1)

u2 = [U[3]; U[4]; U[5]; U[6]]
f2 = d2_beam_elementforces(k2, u2)

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
println("Applied moment at node 2: -15 kN-m")
println("F (reactions) =")
display(F)
println("Sum F (should be ~0): ", sum(F))

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_7_1.m
@assert isapprox(u, [2.272727272727273e-5, -4.545454545454546e-5, 2.2727272727272733e-5]; rtol=1e-8) "u mismatch"
@assert isapprox(F[4], -15.0; rtol=1e-10) "F[4] mismatch"
@assert isapprox(f1, [-1.5584415584415587, 0.0, 1.5584415584415587, -5.454545454545455]; rtol=1e-8, atol=1e-14) "f1 mismatch"
@assert isapprox(f2, [-4.7727272727272725, -9.545454545454545, 4.7727272727272725, 0.0]; rtol=1e-8, atol=1e-14) "f2 mismatch"

# ─── Diagrams (optional, uncomment if Plots works) ──────────
# using Plots
# d2_beam_elementsheardiagram(f1, L1)
# d2_beam_elementsheardiagram(f2, L2)
# d2_beam_elementmomentdiagram(f1, L1)
# d2_beam_elementmomentdiagram(f2, L2)
