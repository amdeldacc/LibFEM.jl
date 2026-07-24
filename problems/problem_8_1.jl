#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 8.1 — Plane Frame with Two Elements (Fig 8.21)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
#
#               15 kN.m
#                .---.
#              v '   |
#                    2                       3           20 kN
#          -         O=======================O----------->
#          ^         |                       o
#          |         |                     -----
#         4 m        |                     /////
#          |         |
#          |         |
#          v         1
#          -         O
#                  -----
#                  /////
#
#                    |<-------- 4 m -------->|
# ═══════════════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (9×9)
#   2. Displacements at nodes 2 and 3
#   3. Reactions at all nodes
#   4. Element forces for each plane frame element
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6
A = 4e-2
I = 4e-6
L = 4.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_planeframe_elementstiffness(E, A, I, L, 90.0)  # vertical element
k2 = d2_planeframe_elementstiffness(E, A, I, L, 0.0)   # horizontal element

println("k1 (vertical, theta=90) ="); display(k1)
println("k2 (horizontal, theta=0) ="); display(k2)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(9, 9)
K = d2_planeframe_assemble(K, k1, 1, 2)  # nodes 1-2
K = d2_planeframe_assemble(K, k2, 2, 3)  # nodes 2-3

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: node 2 (4,5,6), node 3 (7,8,9) but node 3 roller = DOF 9 (rotation) only
# Actually: node 2: DOFs 4,5,6 (ux, uy, theta); node 3: DOFs 7,8,9 but uy=0 (roller)
# Free: DOFs 4,5,6,7,9
k = vcat(hcat(K[4:7, 4:7], K[4:7, 9:9]), hcat(K[9:9, 4:7], K[9:9, 9:9]))
f = [0.0; 0.0; 15.0; 20.0; 0.0]

u = k \ f
U = [0.0; 0.0; 0.0; u[1:4]; 0.0; u[5]]
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

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
u1 = [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]]
f1 = d2_planeframe_elementforces(E, A, I, L, 90.0, u1)

u2 = [U[4]; U[5]; U[6]; U[7]; U[8]; U[9]]
f2 = d2_planeframe_elementforces(E, A, I, L, 0.0, u2)

println("\nu1 ="); display(u1)
println("f1 ="); display(f1)
println("u2 ="); display(u2)
println("f2 ="); display(f2)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("F =")
display(F)

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_8_1.m
@assert isapprox(u, [0.18650877355691653, 2.23213239400011e-6, -0.02976232328658555, 0.1865182973664403, 0.014880324593645022]; rtol=1e-8) "u mismatch"
@assert isapprox(F[6], 15.0; rtol=1e-10) "F[6] mismatch"
@assert isapprox(F[7], 20.0; rtol=1e-10) "F[7] mismatch"
@assert isapprox(f1, [-4.687478027424214, 19.999999999939906, 46.25008789006278, 4.687478027424214, -19.999999999939906, 33.74991210969685]; rtol=1e-8) "f1 mismatch"
@assert isapprox(f2, [-19.999999999941792, -4.687478027424212, -18.749912109696844, 19.999999999941792, 4.687478027424212, 0.0]; rtol=1e-8, atol=1e-14) "f2 mismatch"
