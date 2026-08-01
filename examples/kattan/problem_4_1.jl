#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 4.1 — Tapered Bar with 2 Quadratic Bar Elements
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#              18 kN
#             <-----
# |/----o======o======o======o======o
# |/    1      2      3      4      5
# |/    |<--1.5m-->|<--1.5m--->|
# |/    x=0 (thin)  x=3 (thick)
# |/    A(x) = 0.002 + 0.01x/3  (x measured from the loaded end)
# |/    elem 1: nodes (1,3,2), A = A(0.75) = 0.0045
# |/    elem 2: nodes (3,5,4), A = A(2.25) = 0.0095
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at nodes 1-4
#   3. Reaction at node 5
#   4. Force and stress in each quadratic bar
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Parameters ──────────────────────────────────────────────
E = 210e6      # Young's modulus (kN/m²)
P = 18.0       # applied load (kN), compressive
L = 1.5        # element length (m)

# Area at each element midpoint, measured from the loaded (thin) end:
#   A(x) = 0.002 + 0.01*x/3
A1 = 0.002 + 0.01 * 0.75 / 3   # elem 1 midpoint x = 0.75
A2 = 0.002 + 0.01 * 2.25 / 3   # elem 2 midpoint x = 2.25

# ─── Element stiffness matrices ──────────────────────────────
k1 = d1_quadraticbar_elementstiffness(E, A1, L)
k2 = d1_quadraticbar_elementstiffness(E, A2, L)

println("A1 = ", A1, "  A2 = ", A2)
println("\nk1 =")
display(k1)
println("\nk2 =")
display(k2)

# ─── Assembly ────────────────────────────────────────────────
# Nodes: 1 (x=0), 2 (x=0.75), 3 (x=1.5), 4 (x=2.25), 5 (x=3)
# elem 1 spans x=0..1.5 with mid node 2: MATLAB QuadBarAssemble(K,k1,1,3,2)
# elem 2 spans x=1.5..3 with mid node 4: MATLAB QuadBarAssemble(K,k2,3,5,4)
K = zeros(5, 5)
K = d1_quadraticbar_assemble(K, k1, 1, 3, 2)
K = d1_quadraticbar_assemble(K, k2, 3, 5, 4)

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Node 1 (x=0, thin end) is free with F1 = -18; node 5 (x=3) is fixed.
k = K[1:4, 1:4]
f = zeros(4)
f[1] = -P

u = k \ f
U = [u; 0.0]
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

# ─── Post-processing: element forces and stresses ────────────
# elem 1 nodes (1,3,2): ue = [U1; U3; U2]  (MATLAB element-order convention)
# elem 2 nodes (3,5,4): ue = [U3; U5; U4]
ue1 = [U[1]; U[3]; U[2]]
ue2 = [U[3]; U[5]; U[4]]

fe1 = d1_quadraticbar_elementforces(k1, ue1)
fe2 = d1_quadraticbar_elementforces(k2, ue2)
sigma1 = d1_quadraticbar_elementstress(k1, ue1, A1)
sigma2 = d1_quadraticbar_elementstress(k2, ue2, A2)

println("\nue1 =")
display(ue1)
println("\nue2 =")
display(ue2)
println("\nfe1 =")
display(fe1)
println("\nfe2 =")
display(fe2)
println("\nsigma1 =")
display(sigma1)
println("\nsigma2 =")
display(sigma2)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("Applied load: P = -", P, " (node 1)")
println("Reaction at node 5 (F5): ", F[end])
println("Sum F = ", sum(F), " (should be 0)")

    # ─── Self-validation ─────────────────────────────────────────
    # Expected values from Kattan's Problem 4.1 solution (u listed free-end-first;
    # book values rounded to 4 significant figures, so use absolute tolerance).
    u_book = 1e-4 * [-0.4211, -0.2782, -0.1353, -0.0677]
    @assert isapprox(u, u_book; atol=1e-8) "u mismatch"
@assert isapprox(U[end], 0.0; atol=1e-12) "fixed node displacement mismatch"
@assert isapprox(F[end], P; rtol=1e-10) "reaction mismatch"
@assert isapprox(fe1, [-P, P, 0.0]; rtol=1e-10) "fe1 mismatch"
@assert isapprox(fe2, [-P, P, 0.0]; rtol=1e-10) "fe2 mismatch"
println("\n✓ Problem 4.1 self-validation passed")
