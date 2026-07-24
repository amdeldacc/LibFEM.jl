#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 7.2 — Beam with Distributed Load (Fig 7.16)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
#
#            10 kN/m                                         30 kN
#            +--+--+--+--+--+--+                             |
#            |  |  |  |  |  |  |                             v
#            v  v  v  v  v  v  v
#            1                 2                 3                       4
#        //|-O=================O=================O=======================O
#        //|                   o                 o                       o
#        //|                 -----             -----                   -----
#        //|                 /////             /////                   /////
#
#            |<----- 3 m ----->|<----- 3 m ----->|<-- 2 m -->|<-- 2 m -->|
# ═══════════════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (8×8)
#   2. Rotations at nodes 2, 3, 4
#   3. Reactions at all supports
#   4. Element forces
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6
I = 50e-6
L1 = 3.0
L2 = 3.0
L3 = 4.0

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_beam_elementstiffness(E, I, L1)
k2 = d2_beam_elementstiffness(E, I, L2)
k3 = d2_beam_elementstiffness(E, I, L3)

println("k1 ="); display(k1)
println("k2 ="); display(k2)
println("k3 ="); display(k3)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(8, 8)
K = d2_beam_assemble(K, k1, 1, 2)
K = d2_beam_assemble(K, k2, 2, 3)
K = d2_beam_assemble(K, k3, 3, 4)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: rotations at nodes 2, 3, 4 = DOFs 4, 6, 8
k = K[[4, 6, 8], [4, 6, 8]]
f = [7.5; -15.0; 15.0]  # fixed-end reaction adjustments from MATLAB

u = k \ f
U = zeros(8)
U[[4, 6, 8]] = u
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
f1 = f1 - [-15.0; -7.5; -15.0; 7.5]  # subtract fixed-end forces for distributed load

u2 = [U[3]; U[4]; U[5]; U[6]]
f2 = d2_beam_elementforces(k2, u2)

u3 = [U[5]; U[6]; U[7]; U[8]]
f3 = d2_beam_elementforces(k3, u3)
f3 = f3 - [-15.0; -15.0; -15.0; 15.0]  # subtract fixed-end forces for point load

println("\nu1 ="); display(u1)
println("f1 ="); display(f1)
println("u2 ="); display(u2)
println("f2 ="); display(f2)
println("u3 ="); display(u3)
println("f3 ="); display(f3)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("F =")
display(F)

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_7_2.m
@assert isapprox(u, [0.0005706521739130435, -0.0012111801242236026, 0.0020341614906832298]; rtol=1e-8) "u mismatch"
@assert isapprox(F[4], 7.5; rtol=1e-10) "F[4] mismatch"
@assert isapprox(F[8], 15.0; rtol=1e-10) "F[8] mismatch"
@assert isapprox(f1, [18.994565217391305, 11.494565217391305, 11.005434782608695, 0.4891304347826093]; rtol=1e-8) "f1 mismatch"
@assert isapprox(f2, [-4.483695652173914, -0.489130434782609, 4.483695652173914, -12.961956521739133]; rtol=1e-8) "f2 mismatch"
@assert isapprox(f3, [18.24048913043478, 12.961956521739129, 11.759510869565219, 0.0]; rtol=1e-8, atol=1e-14) "f3 mismatch"
