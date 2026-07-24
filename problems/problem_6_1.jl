#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 6.1 — 3D Space Truss (Fig 6.3)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
#
# Node 5 (0,5,0) — free, loaded with 15 kN in +X, -20 kN in Z
# Nodes 1-4 fixed at ground plane
#
# Node coordinates (X, Y, Z):
#   Node 1: ( 0,  0, -3)  fixed
#   Node 2: (-3,  0,  0)  fixed
#   Node 3: ( 0,  0,  3)  fixed
#   Node 4: ( 4,  0,  0)  fixed
#   Node 5: ( 0,  5,  0)  free
#
# ═══════════════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K (15×15)
#   2. Displacements at node 5
#   3. Reactions at nodes 1-4
#   4. Stress in each of the 4 truss elements
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 200e6
A = 0.003

# ─── Node coordinates ────────────────────────────────────────
# (x, y, z) in meters
nodes = [
    (0.0,  0.0, -3.0),   # node 1 — fixed
    (-3.0, 0.0,  0.0),   # node 2 — fixed
    (0.0,  0.0,  3.0),   # node 3 — fixed
    (4.0,  0.0,  0.0),   # node 4 — fixed
    (0.0,  5.0,  0.0),   # node 5 — free
]

# ─── Element data (all connect to node 5) ────────────────────
elem_pairs = [(1, 5), (2, 5), (3, 5), (4, 5)]

println("=== Element lengths and angles ===")
L_vals = Float64[]
theta_x = Float64[]
theta_y = Float64[]
theta_z = Float64[]
k_vals = []

for (n1, n2) in elem_pairs
    x1, y1, z1 = nodes[n1]
    x2, y2, z2 = nodes[n2]

    L = d3_truss_elementlength(x1, y1, z1, x2, y2, z2)
    push!(L_vals, L)

    # Direction cosines -> angles in degrees
    tx = acos((x2 - x1) / L) * 180 / pi
    ty = acos((y2 - y1) / L) * 180 / pi
    tz = acos((z2 - z1) / L) * 180 / pi
    push!(theta_x, tx)
    push!(theta_y, ty)
    push!(theta_z, tz)

    k = d3_truss_elementstiffness(E, A, L, tx, ty, tz)
    push!(k_vals, k)

    println("Element $n1-$n2: L=$L, thetax=$tx, thetay=$ty, thetaz=$tz")
end

# ─── Assembly ────────────────────────────────────────────────
K = zeros(15, 15)
for (idx, (n1, n2)) in enumerate(elem_pairs)
    d3_truss_assemble(K, k_vals[idx], n1, n2)  # modifies K in-place via _assemble!
end

println("\nK =")
display(K)

# ─── Solve (free DOFs = 13:15, node 5) ──────────────────────
k = K[13:15, 13:15]
f = [15.0; 0.0; -20.0]

u = k \ f
U = [zeros(12); u]
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

# ─── Post-processing: stresses ───────────────────────────────
println("\n=== Element stresses ===")
sigmas = Float64[]
for (idx, (n1, n2)) in enumerate(elem_pairs)
    u_elem = [U[3*n1-2]; U[3*n1-1]; U[3*n1]; U[3*n2-2]; U[3*n2-1]; U[3*n2]]
    sigma = d3_truss_elementstress(E, L_vals[idx], theta_x[idx], theta_y[idx], theta_z[idx], u_elem)
    push!(sigmas, sigma)
    println("sigma$idx (nodes $n1-$n2) = $sigma")
end

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied forces: Fx=15, Fy=0, Fz=-20 at node 5")
println("Sum Fx = ", sum(F[1:3:end]), " (should be 15)")
println("Sum Fy = ", sum(F[2:3:end]), " (should be 0)")
println("Sum Fz = ", sum(F[3:3:end]), " (should be -20)")

# ─── Self-validation ─────────────────────────────────────────
# Expected values verified against Octave execution of Kattan's problem_6_1.m
@assert isapprox(u, [0.00023509062547027082, 2.587463432376072e-7, -0.00036713400819396355]; rtol=1e-8) "u mismatch"
@assert isapprox(F[13], 15.0; rtol=1e-10) "F[13] mismatch"
@assert isapprox(F[15], -20.0; rtol=1e-10) "F[15] mismatch"
@assert isapprox(sigmas[1], -6471.22525215119; rtol=1e-8) "sigma1 mismatch"
@assert isapprox(sigmas[2], 4156.268283100001; rtol=1e-8) "sigma2 mismatch"
@assert isapprox(sigmas[3], 6486.445625282813; rtol=1e-8) "sigma3 mismatch"
@assert isapprox(sigmas[4], -4580.823269097052; rtol=1e-8) "sigma4 mismatch"
