#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 8.3 — Plane Frame with a Spring (Fig 8.23)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
#
#                                       |//
#                                      3|//
#                                      O|//
#                                    /  |//
#                                  \    |//
#                                /      |//
#                              \        |//
#                       k   /           |//
#                         \             |//
#                       /               |//
#                     \                 |//
#                  /                    |//
#              1 \                     2|//
#              O=======================O|//
#              |                        |//
#              v                        |//
#            10 kN
#
#              |<-------- 4 m -------->|
# ═══════════════════════════════════════════════════════════════════════
# Mixed element types: PlaneFrame (3 DOF/node) + PlaneTruss (2 DOF/node)
# Global K is 8×8.
# ═══════════════════════════════════════════════════════════════════════
# Computes:
#   1. Element stiffness matrices (frame 6×6, spring/truss 4×4)
#   2. Global stiffness matrix K (8×8)
#   3. Reduced system and displacements
#   4. Reactions at all nodes
#   5. Element forces for both elements
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E1 = 70e6       # Frame Young's modulus
A1 = 1e-2       # Frame cross-sectional area
I = 1e-5        # Frame moment of inertia

# Spring modeled as equivalent truss: keq = E2*A2/L2 = 5000
E2 = 2500.0     # Equivalent truss E
A2 = 10.0       # Equivalent truss A
L2 = 5.0        # Spring/truss length

L1 = 4.0        # Frame length

theta1 = 0.0    # Frame orientation (horizontal)
theta2 = atan(3.0, 4.0) * 180 / pi  # Spring/truss orientation

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_planeframe_elementstiffness(E1, A1, I, L1, theta1)  # 6×6 frame
k2 = d2_truss_elementstiffness(E2, A2, L2, theta2)          # 4×4 truss (spring)

println("k1 (frame) ="); display(k1)
println("k2 (truss/spring) ="); display(k2)

# ─── Assembly (mixed DOF types) ──────────────────────────────
# DOF mapping:
#   Frame node 1: DOFs 1(ux), 2(uy), 3(theta)  — free + load
#   Frame node 2: DOFs 4(ux), 5(uy), 6(theta)  — fixed
#   Truss node 3: DOFs 7(ux), 8(uy)            — fixed
# Truss node 1 shares frame node 1 → DOFs 1,2 (truss has no rotation DOF)
K = zeros(8, 8)
K = d2_planeframe_assemble(K, k1, 1, 2)  # frame element (nodes 1-2)
K = d2_truss_assemble(K, k2, 1, 3)       # truss/spring element (nodes 1-3)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: node 1 (ux, uy, theta) = DOFs 1,2,3
k = K[1:3, 1:3]
f = [0.0; -10.0; 0.0]

u = k \ f
U = [u; 0.0; 0.0; 0.0; 0.0; 0.0]
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
u1 = [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]]  # frame element displacements (6 DOF)
f1 = d2_planeframe_elementforces(E1, A1, I, L1, theta1, u1)

u2 = [U[1]; U[2]; U[7]; U[8]]               # truss element displacements (4 DOF, ux, uy at each node)
f2 = d2_truss_elementforces(E2, A2, L2, theta2, u2)

println("\nu1 ="); display(u1)
println("f1 (frame forces) ="); display(f1)
println("u2 ="); display(u2)
println("f2 (spring/truss force) = $f2")

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied force: -10 kN at node 1 (vertical)")
println("F =")
display(F)
println("Sum F = ", sum(F), " (should be -10)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_8_3.m
# (see Doc/Kattan/Solutions-Manual/problem_8_3.m)
@assert isapprox(u, [7.48019647203546e-5, -0.005554045880486329, 0.002082767205182374]; rtol=1e-8) "u mismatch"
@assert isapprox(F[2], -10.0; rtol=1e-10) "F[2] mismatch"
@assert isapprox(f2, 16.36292978257757; rtol=1e-8) "f2 mismatch"
@assert isapprox(f1, [13.090343826062055, -0.1822421304534576, 0.0, -13.090343826062055, 0.1822421304534576, -0.7289685218138305]; rtol=1e-8, atol=1e-14) "f1 mismatch"
@assert isapprox(F[4], -13.090343826062055; rtol=1e-8) "F[4] mismatch"
@assert isapprox(F[5], 13.272585956515513; rtol=1e-8) "F[5] mismatch"
@assert isapprox(F[6], 9.088789347732712; rtol=1e-8) "F[6] mismatch"
