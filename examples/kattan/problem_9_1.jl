#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════════════
# Problem 9.1 — L-Shaped Grid (Out-of-Plane Bending + Torsion)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════════════
# =============================================================================
# PROBLEM OVERVIEW: GRID WITH TWO ELEMENTS
# =============================================================================
# 3D perspective (simplified for plain text readability):
#
#                                                       3
#                                                   /// O
#                                                   ///   *
#                                                     .     *
#                                                      .     *
#                                                       .      *
#                                                        .      *
#                                                         .       *
#                                                          .       *
#                                                           .        *
#                                         Y                  .         *
#                                         ^                   .         *
#                                         |                    .          *
#                                         |                     .         1
#                                         + - - - - - - - - - - - - - - - O ----> X
#                                        /  Origin                      *   |
#                                       /                           *       |
#                                      /                        *           v
#                                     /                     *             10 kN
#                                    /                  *
#                                   /               *
#                                  2            *
#                              /// O        *
#                              ///  \
#                                    v Z
#
# =============================================================================
# NODE COORDINATES & LOADS (in the code: elements in XY-plane, Z out-of-plane):
# =============================================================================
# Node 1 : (4,  0) → free node, 10 kN load in negative Z
# Node 2 : (0,  3) → fixed support
# Node 3 : (0, -3) → fixed support
#
# Element 1 : Node 1→2, L = √(4²+3²) = 5 m, θ₁ = 180+atan(3/4) ≈ 216.87°
# Element 2 : Node 1→3, L = √(4²+3²) = 5 m, θ₂ = 180-atan(3/4) ≈ 143.13°
#
# Note: The 3D diagram uses Y as the out-of-plane axis. In our 2-D grid
# formulation (per Kattan Ch9), elements lie in the XY-plane, out-of-plane
# displacement is UZ. The coordinates are physically the same arrangement
# with swapped Y↔Z axis labels.
# =============================================================================
# Computes:
#   1. Global stiffness matrix K (9×9)
#   2. Displacements and rotations at node 1
#   3. Reactions at nodes 2 and 3
#   4. Forces and moments in each element
# ═══════════════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

# ─── Nodes ──────────────────────────────────────────────────
x1, y1 = 4.0, 0.0   # node 1: free (load point)
x2, y2 = 0.0, 3.0   # node 2: fixed support
x3, y3 = 0.0, -3.0  # node 3: fixed support

# ─── Parameters ──────────────────────────────────────────────
E = 210e6   # 210 GPa → kPa
G = 84e6    # 84 GPa → kPa
I = 20e-5   # m^4
J = 5e-5    # m^4

# Element lengths and angles (matching Kattan Solutions Manual)
L1 = d2_grid_elementlength(x1, y1, x2, y2)   # 5.0 m
L2 = d2_grid_elementlength(x1, y1, x3, y3)   # 5.0 m
θ1 = 180 + atan(3 / 4) * 180 / π              # 216.8699°
θ2 = 180 - atan(3 / 4) * 180 / π              # 143.1301°

# ─── Element stiffness matrices ──────────────────────────────
k1 = d2_grid_elementstiffness(E, G, I, J, L1, θ1)   # elem 1→2
k2 = d2_grid_elementstiffness(E, G, I, J, L2, θ2)   # elem 1→3

println("k1 (nodes 1→2, L=5, θ₁=216.87°) =")
display(k1)
println("k2 (nodes 1→3, L=5, θ₂=143.13°) =")
display(k2)

# ─── Assembly ────────────────────────────────────────────────
# DOF map: node → (UZ, RX, RY)
# Node 1: DOFs 1,2,3 | Node 2: DOFs 4,5,6 | Node 3: DOFs 7,8,9
K = zeros(9, 9)
K = d2_grid_assemble(K, k1, 1, 2)  # element 1: nodes 1→2 (per Kattan)
K = d2_grid_assemble(K, k2, 1, 3)  # element 2: nodes 1→3

println("\nK =")
display(K)

# ─── Solve ───────────────────────────────────────────────────
# Free DOFs: node 1 = 1, 2, 3
# Fixed DOFs: node 2 = 4,5,6, node 3 = 7,8,9
k = K[1:3, 1:3]
f = [-10.0; 0.0; 0.0]  # 10 kN in negative Z → DOF 1 (UZ)

u = k \ f
U = zeros(9)
U[1:3] = u
F = K * U

# Zero near-zero entries
F[abs.(F) .< 1e-10] .= 0.0

println("\nk (reduced) =")
display(k)
println("\nf =")
display(f)
println("\nu (node 1: UZ, RX, RY) =")
display(u)
println("\nU =")
display(U)
println("\nF =")
display(F)

# ─── Post-processing: element forces ─────────────────────────
# Element 1: nodes 1→2 → element DOFs [UZ₁,RX₁,RY₁, UZ₂,RX₂,RY₂]
u1 = [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]]
f1 = d2_grid_elementforces(E, G, I, J, L1, θ1, u1)

# Element 2: nodes 1→3 → element DOFs [UZ₁,RX₁,RY₁, UZ₃,RX₃,RY₃]
u2 = [U[1]; U[2]; U[3]; U[7]; U[8]; U[9]]
f2 = d2_grid_elementforces(E, G, I, J, L2, θ2, u2)

println("\nu1 (element 1, local) =")
display(u1)
println("f1 (element 1, local) =")
display(f1)
println("u2 (element 2, local) =")
display(u2)
println("f2 (element 2, local) =")
display(f2)

# ─── Equilibrium check ───────────────────────────────────────
println("\n--- Equilibrium check ---")
println("F (reactions) =")
display(F)
println("Sum Fz (should be ~0): ", sum(F[1:3:end]))  # sum Z-forces only

# ─── Self-validation ─────────────────────────────────────────
# Expected values from Kattan's MATLAB/Solutions-Manual output
@assert isapprox(u, [-0.0048, 0.0, -0.0018]; rtol=5e-2) "u mismatch at node 1: $(u)"
@assert isapprox(F[1], -10.0; rtol=1e-2) "Fz₁ mismatch: $(F[1])"
@assert isapprox(F[4], 5.0; rtol=1e-2) "Fz₂ mismatch: $(F[4])"
@assert isapprox(F[5], -13.8905; rtol=1e-2) "Mx₂ mismatch: $(F[5])"
@assert isapprox(F[6], 20.0; rtol=1e-2) "My₂ mismatch: $(F[6])"
@assert isapprox(F[7], 5.0; rtol=1e-2) "Fz₃ mismatch: $(F[7])"
@assert isapprox(F[8], 13.8905; rtol=1e-2) "Mx₃ mismatch: $(F[8])"
@assert isapprox(F[9], 20.0; rtol=1e-2) "My₃ mismatch: $(F[9])"
