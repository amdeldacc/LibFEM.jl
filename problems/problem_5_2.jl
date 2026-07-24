#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 5.2 — Plane Truss with a Spring (Fig 5.6)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
#
#            3
#         //|--O
#         //|    \
#            2      \
#         //|--O-----O-------------/\/\/\------------O-----> 10 kN
#         //|       4               k                5
#         //|  1  /
#         //|--O
#
#                    |<----- 4 m ----->|
# ═══════════════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (9×9)
#   2. Displacements at nodes 4 and 5
#   3. Reactions at nodes 1, 2, 3
#   4. Stress in each truss element
#   5. Force in the spring
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 70e6
A = 0.01
k_spring = 3000.0

# ─── Node coordinates ────────────────────────────────────────
# Node 1 (0,0), Node 2 (0,3), Node 3 (0,7), Node 4 (4,3), Node 5 (X,3)
x = [0.0, 0.0, 0.0, 4.0, 4.0]  # Node 5 x-coordinate is same as node 4 for truss-spring junction
y = [0.0, 3.0, 7.0, 3.0, 3.0]

# ─── Truss elements ──────────────────────────────────────────
# Element 1: nodes 1-4, Element 2: nodes 2-4, Element 3: nodes 3-4
L1 = d2_truss_elementlength(x[1], y[1], x[4], y[4])
L2 = d2_truss_elementlength(x[2], y[2], x[4], y[4])
L3 = d2_truss_elementlength(x[3], y[3], x[4], y[4])

theta1 = atan(y[4] - y[1], x[4] - x[1]) * 180 / pi  # atan(3/4)
theta2 = atan(y[4] - y[2], x[4] - x[2]) * 180 / pi  # 0
theta3 = atan(y[4] - y[3], x[4] - x[3]) * 180 / pi  # -atan(4/4) = -45 -> converted to 315

# Convert theta3 to 0-360 range (MATLAB uses 360 - atan(4/4)*180/pi)
if theta3 < 0
    theta3 += 360.0
end

println("L1 = $L1, theta1 = $theta1")
println("L2 = $L2, theta2 = $theta2")
println("L3 = $L3, theta3 = $theta3")

k1 = d2_truss_elementstiffness(E, A, L1, theta1)
k2 = d2_truss_elementstiffness(E, A, L2, theta2)
k3 = d2_truss_elementstiffness(E, A, L3, theta3)

# ─── Spring element ──────────────────────────────────────────
k4 = d1_spring_elementstiffness(k_spring)

println("\nk1 ="); display(k1)
println("\nk2 ="); display(k2)
println("\nk3 ="); display(k3)
println("\nk4 ="); display(k4)

# ─── Assembly ────────────────────────────────────────────────
# DOFs: nodes 1-4 have 2 DOF each (1-8), spring is 1 DOF/node (DOFs 7,9)
# Node 4 (truss) -> DOFs 7,8 ; Node 5 (spring right) -> DOF 9
K = zeros(9, 9)
K = d2_truss_assemble(K, k1, 1, 4)  # nodes 1-4, maps to DOFs 1,2 and 7,8
K = d2_truss_assemble(K, k2, 2, 4)  # nodes 2-4, maps to DOFs 3,4 and 7,8
K = d2_truss_assemble(K, k3, 3, 4)  # nodes 3-4, maps to DOFs 5,6 and 7,8
K = d1_spring_assemble(K, k4, 7, 9)  # MATLAB uses SpringAssemble(K,k4,7,9)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: 7,8,9 (node 4 x,y and node 5 x)
k = K[7:9, 7:9]
f = [0.0; 0.0; 10.0]

u = k \ f
U = [0.0; 0.0; 0.0; 0.0; 0.0; 0.0; u]
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

# ─── Post-processing: truss stresses ─────────────────────────
println("\n=== Truss element stresses ===")
u1_vec = [U[1]; U[2]; U[7]; U[8]]
sigma1 = d2_truss_elementstress(E, L1, theta1, u1_vec)
println("sigma1 = $sigma1")

u2_vec = [U[3]; U[4]; U[7]; U[8]]
sigma2 = d2_truss_elementstress(E, L2, theta2, u2_vec)
println("sigma2 = $sigma2")

u3_vec = [U[5]; U[6]; U[7]; U[8]]
sigma3 = d2_truss_elementstress(E, L3, theta3, u3_vec)
println("sigma3 = $sigma3")

# ─── Post-processing: spring force ───────────────────────────
u4_vec = [U[7]; U[9]]
f4 = d1_spring_elementforce(k4, u4_vec)
println("\nSpring force f4 =")
display(f4)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied force: 10 kN at node 5 (x-direction)")
println("Fx reactions: node1=", F[1], " node2=", F[3], " node3=", F[5])
println("Fy reactions: node1=", F[2], " node2=", F[4], " node3=", F[6])
println("Sum Fx = ", F[1] + F[3] + F[5] + F[7] + F[9], " (should be 10)")
println("Sum Fy = ", F[2] + F[4] + F[6] + F[8], " (should be 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_5_2.m
@assert isapprox(u, [3.065425546488906e-5, -1.4547785990662422e-6, 0.0033639875887982226]; rtol=1e-8) "u mismatch"
@assert isapprox(F[9], 10.0; rtol=1e-10) "F[9] mismatch"
@assert isapprox(sigma1, 331.1075209746011; rtol=1e-8) "sigma1 mismatch"
@assert isapprox(sigma2, 536.4494706355586; rtol=1e-8) "sigma2 mismatch"
@assert isapprox(sigma3, 280.95404805960874; rtol=1e-8) "sigma3 mismatch"
@assert isapprox(f4, [-10.0, 10.0]; rtol=1e-10) "f4 mismatch"
