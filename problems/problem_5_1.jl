#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 5.1 — Plane Truss (Fig 5.5)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
#
#                           2           4
#               20 kN       O-----------O
#               --------->/ | \         | \
#                       /   |   \       |   \
#                     /     |     \     |     \
#                   /       |       \   |       \
#                 /         |         \ |         \
#               /           |           \           \
#               O-----------O-----------O-----------O
#               1           3           5           6
#              / \                                 / \
#             ////                                ////
#
#               |<-- 5 m -->|<-- 5 m -->|<-- 5 m -->|
# ═══════════════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (12×12)
#   2. Displacements at nodes 2-5
#   3. Reactions at nodes 1 and 6
#   4. Stress in each of the 9 elements
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6
A = 0.005

# ─── Node coordinates ────────────────────────────────────────
# Node 1 (0,0) pinned, Node 6 (15,0) pinned/roller
# Nodes: 1(0,0), 2(5,7), 3(5,0), 4(10,7), 5(10,0), 6(15,0)
x = [0.0, 5.0, 5.0, 10.0, 10.0, 15.0]
y = [0.0, 7.0, 0.0, 7.0, 0.0, 0.0]

# ─── Element data ────────────────────────────────────────────
# Format: (node_i, node_j)
elements = [
    (1, 2),  # 1
    (1, 3),  # 2
    (2, 3),  # 3
    (3, 5),  # 4
    (2, 5),  # 5
    (2, 4),  # 6
    (4, 5),  # 7
    (5, 6),  # 8
    (4, 6),  # 9
]

# ─── Element stiffness matrices ──────────────────────────────
println("=== Element stiffness matrices ===")
L_vals = Float64[]
theta_vals = Float64[]
k_vals = []

for (i, (n1, n2)) in enumerate(elements)
    dx = x[n2] - x[n1]
    dy = y[n2] - y[n1]
    L = sqrt(dx^2 + dy^2)
    theta = atan(dy, dx) * 180 / pi
    push!(L_vals, L)
    push!(theta_vals, theta)
    k = d2_truss_elementstiffness(E, A, L, theta)
    push!(k_vals, k)
    println("k$i (nodes $n1-$n2, L=$L, theta=$theta) =")
    display(k)
end

# ─── Assembly ────────────────────────────────────────────────
K = zeros(12, 12)
for (idx, (n1, n2)) in enumerate(elements)
    d2_truss_assemble(K, k_vals[idx], n1, n2)  # modifies K in-place via _assemble!
end

println("\nK =")
display(K)

# ─── Solve (free DOFs = 3:10, nodes 2-5 × 2 DOF) ────────────
k = K[3:10, 3:10]
f = [20.0; 0.0; zeros(6)...]  # 20 kN at node 2 in x-direction

u = k \ f
# Full displacement: nodes 1 (1,2)=0, nodes 2-5 (3:10)=u, node 6 (11,12)=0
U = [0.0; 0.0; u; 0.0; 0.0]
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

# ─── Post-processing: stresses ───────────────────────────────
println("\n=== Element stresses ===")
sigmas = Float64[]
for (idx, (n1, n2)) in enumerate(elements)
    u_elem = [U[2*n1-1]; U[2*n1]; U[2*n2-1]; U[2*n2]]
    sigma = d2_truss_elementstress(E, L_vals[idx], theta_vals[idx], u_elem)
    push!(sigmas, sigma)
    println("sigma$idx (nodes $n1-$n2) = ", sigma)
end

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied force: 20 kN at node 2 (x-direction)")
println("Reaction at node 1 (F1,F2): ", F[1], ", ", F[2])
println("Reaction at node 6 (F11,F12): ", F[11], ", ", F[12])
println("Sum Fx = ", sum(F[1:2:end]), " (should be 20)")
println("Sum Fy = ", sum(F[2:2:end]), " (should be 0)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_5_1.m
K_expected = [
    251236.0   57731.1   -41236.5   -57731.1  -210000.0        0.0        0.0        0.0        0.0        0.0        0.0       0.0
     57731.1   80823.5   -57731.1   -80823.5        0.0        0.0        0.0        0.0        0.0        0.0        0.0       0.0
    -41236.5  -57731.1   292473.0        0.0        0.0        0.0  -210000.0        0.0   -41236.5    57731.1        0.0       0.0
    -57731.1  -80823.5        0.0   311647.0        0.0  -150000.0        0.0        0.0    57731.1   -80823.5        0.0       0.0
   -210000.0       0.0        0.0        0.0   420000.0        0.0        0.0        0.0  -210000.0        0.0        0.0       0.0
         0.0       0.0        0.0  -150000.0        0.0   150000.0        0.0        0.0        0.0        0.0        0.0       0.0
         0.0       0.0  -210000.0        0.0        0.0        0.0   251236.0   -57731.1        0.0        0.0   -41236.5   57731.1
         0.0       0.0        0.0        0.0        0.0        0.0   -57731.1   230824.0        0.0  -150000.0    57731.1  -80823.5
         0.0       0.0   -41236.5    57731.1  -210000.0        0.0        0.0        0.0   461236.0   -57731.1  -210000.0      0.0
         0.0       0.0    57731.1   -80823.5        0.0        0.0        0.0  -150000.0   -57731.1   230824.0        0.0       0.0
         0.0       0.0        0.0        0.0        0.0        0.0   -41236.5    57731.1  -210000.0        0.0   251236.0  -57731.1
         0.0       0.0        0.0        0.0        0.0        0.0    57731.1   -80823.5        0.0        0.0   -57731.1   80823.5
]
@assert isapprox(K, K_expected; rtol=1e-8, atol=1e-10) "K mismatch"
@assert isapprox(u, [0.00020834281842258584, -3.3338372385991406e-5, 1.0582010582010574e-5, -3.333837238599142e-5, 0.0001765967866765541, 1.0662635424540202e-5, 2.1164021164021147e-5, -5.155958679768199e-5]; rtol=1e-8) "u mismatch"
@assert isapprox(F[1], -8.888888888888882; rtol=1e-10) "F[1] mismatch"
@assert isapprox(F[2], -9.333333333333329; rtol=1e-10) "F[2] mismatch"
@assert isapprox(F[3], 20.0; rtol=1e-10) "F[3] mismatch"
@assert isapprox(F[11], -11.1111111111111; rtol=1e-10) "F[11] mismatch"
@assert isapprox(F[12], 9.333333333333323; rtol=1e-10) "F[12] mismatch"
@assert isapprox(sigmas[1], 2293.953404544699; rtol=1e-8) "sigma1 mismatch"
@assert isapprox(sigmas[5], -2293.953404544699; rtol=1e-8) "sigma5 mismatch"
@assert isapprox(sigmas[2], 444.4444444444441; rtol=1e-8) "sigma2 mismatch"
@assert isapprox(sigmas[3], 0.0; rtol=1e-8, atol=1e-12) "sigma3 mismatch"
@assert isapprox(sigmas[4], 444.4444444444441; rtol=1e-8) "sigma4 mismatch"
@assert isapprox(sigmas[6], -1333.3333333333335; rtol=1e-8) "sigma6 mismatch"
@assert isapprox(sigmas[7], 1866.6666666666665; rtol=1e-8) "sigma7 mismatch"
@assert isapprox(sigmas[8], -888.8888888888882; rtol=1e-8) "sigma8 mismatch"
@assert isapprox(sigmas[9], -2293.953404544698; rtol=1e-8) "sigma9 mismatch"
