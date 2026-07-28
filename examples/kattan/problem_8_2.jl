#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 8.2 — Plane Frame with Distributed Load (Fig 8.22)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
#
#                      5 kN/m
#                      +---+---+---+---+---+
#                      |   |   |   |   |   |
#                      v   v   v   v   v   v
#                      2                   3
#          20 kN ----->O===================O
#                     /                     \
#                    /                       \
#                  1/                         \4
#                  O                           O
#                -----                       -----
#                /////                       /////
#
#              |<-2m->|<--------5m-------->|<-2m->|
# ═══════════════════════════════════════════════════════════════════════
# Computes:
#   1. Element lengths and stiffness matrices
#   2. Global stiffness matrix K (12×12)
#   3. Displacements at nodes 2 and 3
#   4. Reactions at all nodes
#   5. Element forces
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6
A = 1e-2
I = 9e-5

# ─── Node coordinates ────────────────────────────────────────
# Node 1 (0,0), Node 2 (2,3), Node 3 (7,3), Node 4 (9,0)
x = [0.0, 2.0, 7.0, 9.0]
y = [0.0, 3.0, 3.0, 0.0]

# ─── Element data ────────────────────────────────────────────
L1 = d2_planeframe_elementlength(x[1], y[1], x[2], y[2])
L2 = d2_planeframe_elementlength(x[2], y[2], x[3], y[3])
L3 = d2_planeframe_elementlength(x[3], y[3], x[4], y[4])

theta1 = atan(y[2] - y[1], x[2] - x[1]) * 180 / pi  # atan(3/2)
theta2 = 0.0
theta3 = 360.0 - theta1  # symmetric

println("L1=$L1, theta1=$theta1")
println("L2=$L2, theta2=$theta2")
println("L3=$L3, theta3=$theta3")

k1 = d2_planeframe_elementstiffness(E, A, I, L1, theta1)
k2 = d2_planeframe_elementstiffness(E, A, I, L2, theta2)
k3 = d2_planeframe_elementstiffness(E, A, I, L3, theta3)

println("\nk1 ="); display(k1)
println("k2 ="); display(k2)
println("k3 ="); display(k3)

# ─── Assembly ────────────────────────────────────────────────
K = zeros(12, 12)
K = d2_planeframe_assemble(K, k1, 1, 2)
K = d2_planeframe_assemble(K, k2, 2, 3)
K = d2_planeframe_assemble(K, k3, 3, 4)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: nodes 2 and 3 = DOFs 4:9
k = K[4:9, 4:9]
f = [20.0; -12.5; -10.417; 0.0; -12.5; 10.417]  # fixed-end forces adjusted

u = k \ f
U = [0.0; 0.0; 0.0; u; 0.0; 0.0; 0.0]
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
f1 = d2_planeframe_elementforces(E, A, I, L1, theta1, u1)

u2 = [U[4]; U[5]; U[6]; U[7]; U[8]; U[9]]
f2 = d2_planeframe_elementforces(E, A, I, L2, theta2, u2)
f2 = f2 - [0.0; -12.5; -10.417; 0.0; -12.5; 10.417]  # subtract fixed-end forces

u3 = [U[7]; U[8]; U[9]; U[10]; U[11]; U[12]]
f3 = d2_planeframe_elementforces(E, A, I, L3, theta3, u3)

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
# Expected values verified against Octave execution of Kattan's problem_8_2.m
@assert isapprox(u, [0.001266805055356551, -0.0008612904923449313, -0.0005086369150586481, 0.0012143567179613013, 0.0007558660483844769, 0.0002528970796484738]; rtol=1e-8) "u mismatch"
@assert isapprox(F[4], 20.0; rtol=1e-10) "F[4] mismatch"
@assert isapprox(F[5], -12.5; rtol=1e-8) "F[5] mismatch"
@assert isapprox(F[6], -10.417; rtol=1e-8) "F[6] mismatch"
@assert isapprox(f1, [8.119143790427122, 2.9750472592473303, 8.029575137851968, -8.119143790427122, -2.9750472592473303, 2.6971103022928897]; rtol=1e-8) "f1 mismatch"
@assert isapprox(f2, [22.02830170600481, 8.405795279080012, -2.697110302292895, -22.02830170600481, 16.59420472091999, -17.77391330230705]; rtol=1e-8) "f2 mismatch"
@assert isapprox(f3, [26.026316201173262, 9.123846303348216, 17.77391330230705, -26.026316201173262, -9.123846303348216, 15.12258237386751]; rtol=1e-8) "f3 mismatch"
