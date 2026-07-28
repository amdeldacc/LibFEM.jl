#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 7.3 — Beam with a Spring (Fig 7.17)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#                                  10 kN
#                                    |
#                                    v
#             1        E, I         2        E, I         3
#         //|-O======================O======================O
#         //|                        |                      o
#         //|                       /                     -----
#         //|                       \                     /////
#         //|                       /
#                                   \
#                                   |
#                                   O 4
#                                 -----
#                                 /////
#
#             |<------ 3 m ------->|<------ 3 m ------->|
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (7×7)
#   2. Displacements and rotations at nodes 2, 3
#   3. Reactions
#   4. Element forces + spring force
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 70e6       # 70 GPa
I = 40e-6      # m^4
L1 = 3.0
L2 = 3.0
k_spring = 5000.0  # kN/m

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_beam_elementstiffness(E, I, L1)
k2 = d2_beam_elementstiffness(E, I, L2)
k3 = d1_spring_elementstiffness(k_spring)

println("k1 (beam 1-2) ="); display(k1)
println("k2 (beam 2-3) ="); display(k2)
println("k3 (spring) ="); display(k3)

# ─── Assembly ────────────────────────────────────────────────
# DOF numbering:
#   Node 1: 1(v1), 2(theta1) — fixed
#   Node 2: 3(v2), 4(theta2) — free + spring + load
#   Node 3: 5(v3), 6(theta3) — roller (v3=0)
#   Node 4: 7(spring ground) — fixed
K = zeros(7, 7)
K = d2_beam_assemble(K, k1, 1, 2)
K = d2_beam_assemble(K, k2, 2, 3)
K = d1_spring_assemble(K, k3, 3, 7)  # spring connects DOF 3 (v2) to DOF 7 (ground)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: 3(v2), 4(theta2), 6(theta3)
k = vcat(hcat(K[3:4, 3:4], K[3:4, 6:6]), hcat(K[6:6, 3:4], K[6:6, 6:6]))
f = [-10.0; 0.0; 0.0]

u = k \ f
U = [0.0; 0.0; u[1]; u[2]; 0.0; u[3]; 0.0]
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

# ─── Post-processing ─────────────────────────────────────────
u1 = [U[1]; U[2]; U[3]; U[4]]   # beam element 1 (nodes 1-2)
u2 = [U[3]; U[4]; U[5]; U[6]]   # beam element 2 (nodes 2-3)
u3 = [U[3]; U[7]]                # spring element (node 2 v to ground)

f1 = d2_beam_elementforces(k1, u1)
f2 = d2_beam_elementforces(k2, u2)
f3 = d1_spring_elementforce(k3, u3)

println("\nu1 ="); display(u1)
println("f1 (beam 1-2 forces) ="); display(f1)
println("u2 ="); display(u2)
println("f2 (beam 2-3 forces) ="); display(f2)
println("u3 ="); display(u3)
println("f3 (spring force) ="); display(f3)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied force: -10 kN at node 2")
println("F =")
display(F)

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_7_3.m
@assert isapprox(u, [-0.0015570934256055363, -0.00022244191794364802, 0.0008897676717745921]; rtol=1e-8) "u mismatch"
@assert isapprox(F[3], -10.0; rtol=1e-10) "F[3] mismatch"
@assert isapprox(f1, [1.5224913494809695, 2.4913494809688586, -1.5224913494809695, 2.076124567474049]; rtol=1e-8) "f1 mismatch"
@assert isapprox(f2, [-0.6920415224913501, -2.076124567474049, 0.6920415224913501, 0.0]; rtol=1e-8, atol=1e-14) "f2 mismatch"
@assert isapprox(f3, [-7.7854671280276815, 7.7854671280276815]; rtol=1e-8) "f3 mismatch"
