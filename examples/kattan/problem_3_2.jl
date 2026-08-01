#!/usr/bin/env julia
# ═══════════════════════════════════════════════════════════════
# Problem 3.2 — Tapered Bar with 10 Linear Elements (Fig. 3.6)
# Reference: P. I. Kattan, "MATLAB Guide to Finite Elements:
#   An Interactive Approach" (2nd ed., Springer, 2007)
# ═══════════════════════════════════════════════════════════════
#
#               18 kN
#              <-----
# |/----o======o======o======o======o======o======o======o======o======o======o
# |/    1      2      3      4      5      6      7      8      9     10     11
# |/    |<---------------- 10 elements x 0.3 m -------------------------->|
# |/    x=0 (thin)                                            x=3 (thick)
# |/    A(x) = 0.002 + 0.01x/3  (x measured from the loaded end)
#
# ═══════════════════════════════════════════════════════════════
# Computes:
#   1. Global stiffness matrix K
#   2. Displacements at nodes 1-10
#   3. Reaction at node 11
#   4. Force and stress in each bar
# ═══════════════════════════════════════════════════════════════

using LibFEM
using LinearAlgebra

function main()
    # ─── Parameters ──────────────────────────────────────────
    E = 210e6      # Young's modulus (kN/m²)
    P = 18.0       # applied load (kN), compressive
    L = 3.0        # total bar length (m)
    n = 10         # number of elements
    Le = L / n     # element length (m)

    # Area at each element midpoint, measured from the loaded (thin) end:
    #   A(x) = 0.002 + 0.01*x/3
    Ae = [0.002 + 0.01 * (e - 0.5) * Le / 3 for e in 1:n]

    # ─── Element stiffness matrices ──────────────────────────
    kes = [d1_bar_elementstiffness(E, Ae[e], Le) for e in 1:n]

    println("Element areas:")
    display(Ae)
    println("\nElement stiffness matrices:")
    for e in 1:n
        println("k$e (A = ", Ae[e], ") =")
        display(kes[e])
    end

    # ─── Assembly ────────────────────────────────────────────
    K = zeros(n + 1, n + 1)
    for e in 1:n
        K = d1_bar_assemble(K, kes[e], e, e + 1)
    end

    println("\nK =")
    display(K)

    # ─── Solve ───────────────────────────────────────────────
    # Node 1 (x=0, thin end) is free with F1 = -18; node 11 (x=3) is fixed.
    k = K[1:n, 1:n]
    f = zeros(n)
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

    # ─── Post-processing: element forces and stresses ────────
    println("\n--- Element forces and stresses ---")
    for e in 1:n
        ue = [U[e]; U[e + 1]]
        fe = d1_bar_elementforces(kes[e], ue)
        sigma = d1_bar_elementstress(kes[e], ue, Ae[e])
        println("elem $e: f = ", fe, "  sigma = ", sigma)
    end

    # ─── Equilibrium check ───────────────────────────────────
    println("\n--- Equilibrium check ---")
    println("Applied load: P = -", P, " (node 1)")
    println("Reaction at node 11 (F11): ", F[end])
    println("Sum F = ", sum(F), " (should be 0)")

    # ─── Self-validation ─────────────────────────────────────
    # Expected values from Kattan's Problem 3.2 solution (u listed free-end-first;
    # book values rounded to 4 significant figures, so use absolute tolerance;
    # vector isapprox uses the norm, so allow atol=1e-7 for 10 entries).
    u_book = 1e-4 * [-0.4582, -0.3554, -0.2819, -0.2248, -0.1780, -0.1385,
                      -0.1042, -0.0739, -0.0469, -0.0224]
    @assert isapprox(u, u_book; atol=1e-7) "u mismatch"
    @assert isapprox(U[end], 0.0; atol=1e-12) "fixed node displacement mismatch"
    @assert isapprox(F[end], P; rtol=1e-10) "reaction mismatch"
    for e in 1:n
        ue = [U[e]; U[e + 1]]
        fe = d1_bar_elementforces(kes[e], ue)
        @assert isapprox(fe, [-P, P]; rtol=1e-10) "elem $e force mismatch"
    end
    println("\n✓ Problem 3.2 self-validation passed")
end

main()
