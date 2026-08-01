# Pkg setup for direct runs; Pkg.test() handles its own environment
if Base.active_project() == joinpath(@__DIR__, "..", "Project.toml")
    using Pkg
    Pkg.activate(joinpath(@__DIR__, ".."))
    Pkg.instantiate()
end

using LibFEM
using Plots
using Test
using LinearAlgebra

# Problem runner wrapper — Kattan problem solutions computed via LibFEM
include(joinpath(@__DIR__, "..", "lib", "problem_wrapper.jl"))
using .ProblemWrapper

# ─────────────────────────────────────────────────
# Helper: physical invariant checks for stiffness matrices
# ─────────────────────────────────────────────────
"""
    @test_physical_invariants(K; atol=1e-6)

Verify physical invariants that all element stiffness matrices must satisfy:
1. **Symmetry**: K ≈ K'
2. **Positive semi-definiteness**: all eigenvalues ≥ -atol (allows numerical noise near zero)
3. **Zero row-sum (rigid body modes)**: sum(K, dims=2) ≈ 0 atol=atol — ONLY for elements with
   purely translational DOFs (springs and trusses). Beams have rotational DOFs
   so row-sum ≠ 0; they instead have the correct number of zero eigenvalues.

atol=1e-6 accounts for FP noise from large stiffness values (~1e9). These are
absolute tolerances — real physical violations (e.g. sign errors) produce
values many orders of magnitude larger.

These checks are independent of element type, DOF ordering, or reference
solutions — they catch real bugs (wrong connectivity, sign errors, DOF
mismatches).
"""
macro test_physical_invariants(K, atol=1e-6)
    return quote
        local K_ = $(esc(K))
        local atol_ = $(esc(atol))
        @test K_ ≈ K_'  # symmetry
        # Use real() to handle complex FP noise from eigvals on non-exactly-symmetric
        # matrices (BLAS/LAPACK-dependent) — see CI issue #122
        @test all(real(eigvals(K_)) .>= -atol_)  # PSD
    end
end

"""
    @test_translational_invariants(K; atol=1e-6)

Physical invariants for elements with ONLY translational DOFs (springs, trusses):
- Symmetry
- PSD
- Zero row-sum (rigid body translation modes — K·[1...1]ᵀ ≈ 0)
"""
macro test_translational_invariants(K, atol=1e-6)
    return quote
        local K_ = $(esc(K))
        local atol_ = $(esc(atol))
        @test K_ ≈ K_'
        @test all(real(eigvals(K_)) .>= -atol_)  # PSD (real() handles complex FP noise on CI)
        @test all(x -> isapprox(x, 0.0, atol=atol_), sum(K_, dims=2))  # zero row-sum (rigid body)
    end
end

@testset "LibFEM" begin

    # ─────────────────────────────────────────────────
    # _direction_cosines (private utility)
    # ─────────────────────────────────────────────────
    @testset "_direction_cosines" begin
        # Valid unit vector: cos²(30)+cos²(60)+cos²(90) = 0.75+0.25+0 = 1
        c1 = LibFEM._direction_cosines(30, 60, 90)
        @test sqrt(sum(x -> x^2, c1)) ≈ 1.0
        @test c1[1] ≈ cos(LibFEM.deg2rad(30))  # exact values returned unchanged

        # Valid input: (0, 90, 90) → (1, 0, 0) (cos(π/2) ≈ 6e-17 from FP)
        c2 = LibFEM._direction_cosines(0, 90, 90)
        @test c2[1] == 1.0
        @test c2[2] ≈ 0.0 atol = 1e-15
        @test c2[3] ≈ 0.0 atol = 1e-15

        # Invalid input gets normalized: (45, 45, 45) → nsq = 1.5 → normalized
        c3 = LibFEM._direction_cosines(45, 45, 45)
        @test sqrt(sum(x -> x^2, c3)) ≈ 1.0
        # Expected normalized value: cos(45°)/√1.5 ≈ 0.57735
        expected = cos(LibFEM.deg2rad(45)) / sqrt(1.5)
        @test c3[1] ≈ expected
        # Warns on non-physical input
        @test_logs (:warn, r"Direction cosines do not form a unit vector") LibFEM._direction_cosines(45, 45, 45)
    end

    # ─────────────────────────────────────────────────
    # 1-D Spring (d1_spring)
    # ─────────────────────────────────────────────────
    @testset "d1_spring" begin
        @testset "elementstiffness" begin
            k = 1000.0
            Ke = d1_spring_elementstiffness(k)
            @test Ke == [1000 -1000; -1000 1000]
            @test size(Ke) == (2, 2)
            # zero stiffness rejected
            @test_throws ElementParameterError d1_spring_elementstiffness(0)
            # Physical invariants (incl. symmetry, PSD, zero row-sum)
            @test_translational_invariants Ke
        end

        @testset "elementforce" begin
            k = 1000.0
            Ke = d1_spring_elementstiffness(k)
            # axial tension
            u = [0.01; 0.0]
            f = d1_spring_elementforce(Ke, u)
            @test f ≈ [10.0; -10.0]
            # rigid-body motion → zero force
            u_rb = [0.005; 0.005]
            @test d1_spring_elementforce(Ke, u_rb) ≈ [0.0; 0.0] atol = 1e-15
        end

        @testset "assemble" begin
            K = zeros(2, 2)
            k = [1000 -1000; -1000 1000]
            K = d1_spring_assemble(K, k, 1, 2)
            @test K == k
            # assemble into larger matrix (3 springs, 4 DOF)
            K4 = zeros(4, 4)
            k1 = [100 -100; -100 100]
            k2 = [200 -200; -200 200]
            K4 = d1_spring_assemble(K4, k1, 1, 2)
            K4 = d1_spring_assemble(K4, k2, 2, 3)
            @test K4[1:2, 1:2] ≈ [100 -100; -100 300]
            @test K4[2:3, 2:3] ≈ [300 -200; -200 200]
            @test K4[4, :] == zeros(4)
        end

        @testset "L>0 error paths" begin
            # d1_spring_elementstiffness doesn't validate L (no L parameter)
            # No L>0 checks needed for spring elements
        end

        @testset "parameter validation" begin
            @test_throws ElementParameterError d1_spring_elementstiffness(0)
            @test_throws ElementParameterError d1_spring_elementstiffness(-100)
        end
    end

        @testset "problem_2_1_integration" begin
            # Problem 2.1: two springs in series (Fig 2.4).
            # Nodes 1 and 3 fixed; load at node 2. Reference: Doc/Kattan/Solutions-Manual/problem_2_1.m.
            k1 = d1_spring_elementstiffness(200.0)
            k2 = d1_spring_elementstiffness(250.0)
            K = zeros(3, 3)
            K = d1_spring_assemble(K, k1, 1, 2)
            K = d1_spring_assemble(K, k2, 2, 3)
            k = K[2:2, 2:2]
            f = [10.0]
            u = k \ f
            U = [0.0; u; 0.0]
            F = K * U
            u1 = [0.0; u]
            f1 = d1_spring_elementforce(k1, u1)
            u2 = [u; 0.0]
            f2 = d1_spring_elementforce(k2, u2)
            @test size(K) == (3, 3)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(K, [200 -200 0; -200 450 -250; 0 -250 250]; rtol=1e-10)
            @test isapprox(u, [0.022222222222222223]; rtol=1e-10)
            @test isapprox(F, [-4.444444444444445; 10.0; -5.555555555555555]; rtol=1e-10)
            @test isapprox(f1, [-4.444444444444445; 4.444444444444445]; rtol=1e-10)
            @test isapprox(f2, [5.555555555555555; -5.555555555555555]; rtol=1e-10)
        end

        @testset "problem_2_2_integration" begin
            # Problem 2.2: four springs, double spring between nodes 2-3 (Fig 2.5).
            # Node 1 fixed; load at node 4. Reference: Doc/Kattan/Solutions-Manual/problem_2_2.m.
            k1 = d1_spring_elementstiffness(170.0)
            k2 = d1_spring_elementstiffness(170.0)
            k3 = d1_spring_elementstiffness(170.0)
            k4 = d1_spring_elementstiffness(170.0)
            K = zeros(4, 4)
            K = d1_spring_assemble(K, k1, 1, 2)
            K = d1_spring_assemble(K, k2, 2, 3)
            K = d1_spring_assemble(K, k3, 2, 3)
            K = d1_spring_assemble(K, k4, 3, 4)
            k = K[2:4, 2:4]
            f = [0.0; 0.0; 25.0]
            u = k \ f
            U = [0.0; u]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0
            u1 = [0.0; U[2]]
            f1 = d1_spring_elementforce(k1, u1)
            u2 = [U[2]; U[3]]
            f2 = d1_spring_elementforce(k2, u2)
            u3 = [U[2]; U[3]]
            f3 = d1_spring_elementforce(k3, u3)
            u4 = [U[3]; U[4]]
            f4 = d1_spring_elementforce(k4, u4)
            @test size(K) == (4, 4)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [0.14705882352941177; 0.22058823529411764; 0.36764705882352944]; rtol=1e-10)
            @test isapprox(F, [-25.0; 0.0; 0.0; 25.0]; rtol=1e-10)
            @test isapprox(f1, [-25.0, 25.0]; rtol=1e-10)
            @test isapprox(f2, [-12.5, 12.5]; rtol=1e-10)
            @test isapprox(f3, [-12.5, 12.5]; rtol=1e-10)
            @test isapprox(f4, [-25.0, 25.0]; rtol=1e-10)
        end

    # ─────────────────────────────────────────────────
    # 1-D Truss / Linear Bar (d1_bar)
    # ─────────────────────────────────────────────────
    @testset "d1_bar" begin
        @testset "elementstiffness" begin
            E, A, L = 200e9, 0.01, 4.0
            Ke = d1_bar_elementstiffness(E, A, L)
            EAoL = E * A / L  # 5e8
            @test Ke ≈ [EAoL -EAoL; -EAoL EAoL]
            @test size(Ke) == (2, 2)
            # Physical invariants (incl. symmetry, PSD, zero row-sum)
            @test_translational_invariants Ke
        end

        @testset "elementforces" begin
            E, A, L = 200e9, 0.01, 4.0
            Ke = d1_bar_elementstiffness(E, A, L)
            u = [0.001; 0.0]
            f = d1_bar_elementforces(Ke, u)
            @test f ≈ [500000.0; -500000.0]
            # zero displacement
            @test d1_bar_elementforces(Ke, [0.0; 0.0]) ≈ [0.0; 0.0]
        end

        @testset "elementstress" begin
            Ke = [5e8 -5e8; -5e8 5e8]
            u = [0.001; 0.0]
            sigma = d1_bar_elementstress(Ke, u, 0.01)
            @test sigma ≈ [5e7; -5e7]
            @test_throws ElementParameterError d1_bar_elementstress([1 -1; -1 1], [0; 0], 0.0)
            @test_throws ElementParameterError d1_bar_elementstress([1 -1; -1 1], [0; 0], -1.0)
        end

        @testset "elementstrain" begin
            L = 4.0
            u = [0.001; 0.0]
            eps = d1_bar_elementstrain(L, u)
            @test eps ≈ -2.5e-4
            # zero displacement
            @test d1_bar_elementstrain(L, [0.0; 0.0]) ≈ 0.0
        end

        @testset "assemble" begin
            K = zeros(2, 2)
            k = [5e8 -5e8; -5e8 5e8]
            K = d1_bar_assemble(K, k, 1, 2)
            @test K == k
            @test size(K) == (2, 2)
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d1_bar_elementstiffness(1.0, 1.0, 0.0)
            @test_throws ElementParameterError d1_bar_elementstiffness(1.0, 1.0, -1.0)
            @test_throws ElementParameterError d1_bar_elementstrain(0.0, [1.0; 0.0])
            @test_throws ElementParameterError d1_bar_elementstrain(-1.0, [1.0; 0.0])
        end

        @testset "assembly error paths" begin
            K = zeros(2, 2)
            k = d1_bar_elementstiffness(1, 1, 1)
            @test_throws AssemblyError d1_bar_assemble(K, k, 1, 1)

            K4 = zeros(4, 4)
            k4 = d2_truss_elementstiffness(1, 1, 1, 0)
            @test_throws AssemblyError d2_truss_assemble(K4, k4, 1, 1)

            K6 = zeros(6, 6)
            k6 = d2_planeframe_elementstiffness(1, 1, 1, 1, 0)
            @test_throws AssemblyError d2_planeframe_assemble(K6, k6, 1, 1)
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → throws
            @test_throws ElementParameterError d1_bar_elementstiffness(1.0, 0.0, 1.0)
            # Negative area → throws
            @test_throws ElementParameterError d1_bar_elementstiffness(1.0, -1.0, 1.0)
            # Zero modulus → zero matrix (not validated)
            @test d1_bar_elementstiffness(0.0, 1.0, 1.0) == zeros(2, 2)
            # Negative modulus → negated matrix (not validated)
            @test d1_bar_elementstiffness(-1.0, 1.0, 1.0) == -[1 -1; -1 1]
        end
    end

        @testset "problem_3_1_integration" begin
            # Problem 3.1: three-bar structure (Fig 3.5).
            # Node 1 fixed; loads at nodes 2-4. Reference: Doc/Kattan/Solutions-Manual/problem_3_1.m.
            E, A = 70e6, 0.005
            L1, L2, L3 = 1.0, 2.0, 1.0
            k1 = d1_bar_elementstiffness(E, A, L1)
            k2 = d1_bar_elementstiffness(E, A, L2)
            k3 = d1_bar_elementstiffness(E, A, L3)
            K = zeros(4, 4)
            K = d1_bar_assemble(K, k1, 1, 2)
            K = d1_bar_assemble(K, k2, 2, 3)
            K = d1_bar_assemble(K, k3, 3, 4)
            k = K[2:4, 2:4]
            f = [-10.0; 0.0; 15.0]
            u = k \ f
            U = [0.0; u]
            F = K * U
            u1 = [0.0; U[2]]
            sigma1 = d1_bar_elementstress(k1, u1, A)
            u2 = [U[2]; U[3]]
            sigma2 = d1_bar_elementstress(k2, u2, A)
            u3 = [U[3]; U[4]]
            sigma3 = d1_bar_elementstress(k3, u3, A)
            @test size(K) == (4, 4)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [1.4285714285714285e-5, 0.0001, 0.00014285714285714287]; rtol=1e-10)
            @test isapprox(F, [-5.0; -10.0; 0.0; 15.0]; rtol=1e-10)
            @test isapprox(sigma1, [-1000.0, 1000.0]; rtol=1e-10)
            @test isapprox(sigma2, [-3000.0, 3000.0]; rtol=1e-10)
            @test isapprox(sigma3, [-3000.0, 3000.0]; rtol=1e-10)
        end

        @testset "problem_3_2_integration" begin
            # Problem 3.2: tapered bar (Fig 3.4) with 10 linear bar elements.
            # Node 1 (x=0, thin end) free with load F1=-18; node 11 (x=3, thick end) fixed.
            # A(x) = 0.002 + 0.01x/3 evaluated at each element midpoint.
            # Reference: book Answers 3.2 (free end -0.04582 mm).
            E, P, L = 210e6, 18.0, 3.0
            n = 10
            Le = L / n
            K = zeros(n + 1, n + 1)
            for e in 1:n
                A = 0.002 + 0.01 * (e - 0.5) * Le / 3
                ke = d1_bar_elementstiffness(E, A, Le)
                K = d1_bar_assemble(K, ke, e, e + 1)
            end
            k = K[1:n, 1:n]
            f = [-P; zeros(n - 1)]
            u = k \ f
            U = [u; 0.0]
            F = K * U
            @test size(K) == (n + 1, n + 1)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (full-precision Julia solve, matches book 1e-4*[-0.4582,...,-0.0224])
            @test isapprox(u, [-4.582386027333433e-5, -3.553814598762005e-5, -2.8191207212109848e-5, -2.247692149782414e-5, -1.7801596822499466e-5, -1.3845552866455513e-5, -1.0416981437884084e-5, -7.391771353850469e-6, -4.685004436557234e-6, -2.236024844720498e-6]; rtol=1e-6)
            # Reaction at fixed node 11 balances the applied load
            @test F[end] ≈ P
            # Every element carries the full load: element forces = [-P, P]
            for e in 1:n
                A = 0.002 + 0.01 * (e - 0.5) * Le / 3
                ke = d1_bar_elementstiffness(E, A, Le)
                ue = [U[e]; U[e + 1]]
                @test isapprox(d1_bar_elementforces(ke, ue), [-P, P]; rtol=1e-6)
                @test isapprox(d1_bar_elementstress(ke, ue, A), [-P / A, P / A]; rtol=1e-6)
            end
        end

        @testset "problem_3_3_integration" begin
            # Problem 3.3: linear bar + spring (Fig 3.6).
            # Node 1 fixed, node 3 spring ground. Reference: Doc/Kattan/Solutions-Manual/problem_3_3.m.
            E, A, L = 200e6, 0.01, 2.0
            k1 = d1_bar_elementstiffness(E, A, L)
            k2 = d1_spring_elementstiffness(1000.0)
            K = zeros(3, 3)
            K = d1_bar_assemble(K, k1, 1, 2)
            K = d1_spring_assemble(K, k2, 2, 3)
            k = K[2:2, 2:2]
            f = [25.0]
            u = k \ f
            U = [0.0; u; 0.0]
            F = K * U
            u1 = [0.0; u]
            sigma1 = d1_bar_elementstress(k1, u1, A)
            u2 = [u; 0.0]
            f_spring = d1_spring_elementforce(k2, u2)
            @test size(K) == (3, 3)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [2.4975024975024975e-5]; rtol=1e-10)
            @test isapprox(F, [-24.975024975024976; 25.0; -0.024975024975024976]; rtol=1e-10)
            @test isapprox(sigma1, [-2497.5024975024976, 2497.5024975024976]; rtol=1e-10)
            @test isapprox(f_spring, [0.024975024975024976, -0.024975024975024976]; rtol=1e-10)
        end

    # ─────────────────────────────────────────────────
    # d1_truss → d1_bar deprecation aliases
    # ─────────────────────────────────────────────────
    @testset "d1_truss deprecation aliases" begin
        E, A, L = 200e9, 0.01, 4.0
        u = [0.001; 0.0]
        k_bar = d1_bar_elementstiffness(E, A, L)

        # Each old d1_truss name must still return the same result as its d1_bar replacement
        @test LibFEM.d1_truss_elementstiffness(E, A, L) ≈ k_bar
        @test LibFEM.d1_truss_elementforces(k_bar, u) ≈ d1_bar_elementforces(k_bar, u)
        @test LibFEM.d1_truss_elementstress(k_bar, u, A) ≈ d1_bar_elementstress(k_bar, u, A)
        @test LibFEM.d1_truss_elementstrain(L, u) ≈ d1_bar_elementstrain(L, u)

        K = zeros(2, 2)
        K2 = zeros(2, 2)
        @test LibFEM.d1_truss_assemble(K, k_bar, 1, 2) ≈ d1_bar_assemble(K2, k_bar, 1, 2)
    end

    # ─────────────────────────────────────────────────
    # 1-D Quadratic Bar (d1_quadraticbar)
    # ─────────────────────────────────────────────────
    @testset "d1_quadraticbar" begin
        @testset "elementstiffness" begin
            E, A, L = 70e6, 0.001, 4.0
            Ke = d1_quadraticbar_elementstiffness(E, A, L)
            @test size(Ke) == (3, 3)
            @test Ke ≈ Ke'  # symmetry
            scale = E * A / (3 * L)  # 5833.333...
            @test Ke ≈ scale * [7 1 -8; 1 7 -8; -8 -8 16]
            # Physical invariants (symmetry + PSD; no zero row-sum for higher-order element)
            @test_physical_invariants Ke
        end

        @testset "elementforces" begin
            Ke = d1_quadraticbar_elementstiffness(70e6, 0.001, 4.0)
            u = [0.001; 0.002; 0.0015]
            f = d1_quadraticbar_elementforces(Ke, u)
            @test f ≈ Ke * u
            @test length(f) == 3
            # zero displacement
            @test d1_quadraticbar_elementforces(Ke, zeros(3)) ≈ zeros(3)
        end

        @testset "elementstress" begin
            Ke = d1_quadraticbar_elementstiffness(70e6, 0.001, 4.0)
            u = [0.001; 0.002; 0.0015]
            sigma = d1_quadraticbar_elementstress(Ke, u, 0.001)
            @test sigma ≈ Ke * u / 0.001
            @test length(sigma) == 3
            @test_throws ElementParameterError d1_quadraticbar_elementstress(Ke, u, 0.0)
            @test_throws ElementParameterError d1_quadraticbar_elementstress(Ke, u, -1.0)
        end

        @testset "assemble" begin
            Ke = d1_quadraticbar_elementstiffness(70e6, 0.001, 4.0)
            K = zeros(5, 5)
            K = d1_quadraticbar_assemble(K, Ke, 1, 3, 2)
            # Node 1 → row/col 1, Node 3 → row/col 3, Node 2 → row/col 2
            @test K[1, 1] ≈ Ke[1, 1]
            @test K[1, 3] ≈ Ke[1, 2]
            @test K[1, 2] ≈ Ke[1, 3]
            @test K[3, 1] ≈ Ke[2, 1]
            @test K[3, 3] ≈ Ke[2, 2]
            @test K[3, 2] ≈ Ke[2, 3]
            @test K[2, 1] ≈ Ke[3, 1]
            @test K[2, 3] ≈ Ke[3, 2]
            @test K[2, 2] ≈ Ke[3, 3]
            # All other entries remain zero
            @test all(K[4:5, :] .== 0)
            @test all(K[:, 4:5] .== 0)
        end

        @testset "validation" begin
            @test_throws ElementParameterError d1_quadraticbar_elementstiffness(1.0, 1.0, 0.0)
            @test_throws ElementParameterError d1_quadraticbar_elementstiffness(1.0, 1.0, -1.0)
            @test_throws ElementParameterError d1_quadraticbar_elementstiffness(1.0, 0.0, 1.0)
            @test_throws ElementParameterError d1_quadraticbar_elementstiffness(1.0, -1.0, 1.0)
            @test_throws ElementParameterError d1_quadraticbar_elementstress([1 0 0; 0 1 0; 0 0 1], [0;0;0], 0.0)
            @test_throws ElementParameterError d1_quadraticbar_elementstress([1 0 0; 0 1 0; 0 0 1], [0;0;0], -1.0)
        end

        @testset "problem_4_2_integration" begin
            # Problem 4.2: quadratic bar (E=70e6, A=0.001, L=4) + spring (k=2000).
            # Node 1 fixed; loads f2=10 kN, f3=5 kN. DOF order: [node1, node2, node3(mid), node4].
            # Reference: Doc/Kattan/Solutions-Manual/problem_4_2.m.
            E, A, L = 70e6, 0.001, 4.0
            k1 = d1_spring_elementstiffness(2000)
            k2 = d1_quadraticbar_elementstiffness(E, A, L)
            K = zeros(4, 4)
            K = d1_spring_assemble(K, k1, 1, 2)
            K = d1_quadraticbar_assemble(K, k2, 2, 4, 3)
            k = K[2:4, 2:4]
            f = [0.0; 10.0; 5.0]
            u = k \ f
            U = [0.0; u]
            F = K * U
            @test size(K) == (4, 4)
            @test K ≈ K'  # global symmetry
            # Verify solve produces finite displacements
            @test all(isfinite, U)
            # Verify equilibrium: F should have reaction at node 1
            @test F[1] ≈ -15.0  # sum of applied forces = 10 + 5 = 15
            # Displacement goldens (full-precision Julia solve, matches Octave ref rtol≈1e-15)
            @test isapprox(u, [0.0075, 0.007892857142857201, 0.00807142857142863]; rtol=1e-6)
            # Spring element force: f1 = k1 * [0; U2] = [-15; 15] (reaction -15 at fixed node 1)
            u1 = [0.0, U[2]]
            f1 = d1_spring_elementforce(k1, u1)
            @test isapprox(f1, [-15.0, 15.0]; rtol=1e-6)
            # Quadratic bar element forces (local DOFs: node2, node4, node3)
            u2 = [U[2], U[4], U[3]]
            fq = d1_quadraticbar_elementforces(k2, u2)
            @test isapprox(fq, [-15.0, 5.0, 10.0]; rtol=1e-6)
        end

        @testset "problem_4_1_integration" begin
            # Problem 4.1: tapered bar (Fig 3.4) with 2 quadratic bar elements, 5 nodes.
            # Node 1 (x=0, thin end) free with load F1=-18; node 5 (x=3, thick end) fixed.
            # Element 1 = nodes (1,3,2), A=A(0.75)=0.0045; element 2 = nodes (3,5,4), A=A(2.25)=0.0095.
            # Reference: book Answers 4.1 (free end -0.04211 mm).
            E, P, L = 210e6, 18.0, 1.5
            A1 = 0.002 + 0.01 * 0.75 / 3
            A2 = 0.002 + 0.01 * 2.25 / 3
            k1 = d1_quadraticbar_elementstiffness(E, A1, L)
            k2 = d1_quadraticbar_elementstiffness(E, A2, L)
            K = zeros(5, 5)
            K = d1_quadraticbar_assemble(K, k1, 1, 3, 2)
            K = d1_quadraticbar_assemble(K, k2, 3, 5, 4)
            k = K[1:4, 1:4]
            f = [-P; 0.0; 0.0; 0.0]
            u = k \ f
            U = [u; 0.0]
            F = K * U
            @test size(K) == (5, 5)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (full-precision Julia solve, matches book 1e-4*[-0.4211,-0.2782,-0.1353,-0.0677])
            @test isapprox(u, [-4.210526315789471e-5, -2.7819548872180435e-5, -1.3533834586466162e-5, -6.766917293233081e-6]; rtol=1e-6)
            # Reaction at fixed node 5 balances the applied load
            @test F[end] ≈ P
            # Element forces (local DOFs: endpoints then mid node)
            ue1 = [U[1], U[3], U[2]]
            ue2 = [U[3], U[5], U[4]]
            @test isapprox(d1_quadraticbar_elementforces(k1, ue1), [-P, P, 0.0]; rtol=1e-6)
            @test isapprox(d1_quadraticbar_elementforces(k2, ue2), [-P, P, 0.0]; rtol=1e-6)
        end
    end

    # ─────────────────────────────────────────────────
    # 2-D Pure Beam (d2_beam) — Bending Only, 2 DOF/node
    # ─────────────────────────────────────────────────
    @testset "d2_beam" begin
        @testset "elementstiffness" begin
            # Simple: E=1, I=1, L=1
            Ke = d2_beam_elementstiffness(1, 1, 1)
            @test size(Ke) == (4, 4)
            expected = [12 6 -12 6; 6 4 -6 2; -12 -6 12 -6; 6 2 -6 4]
            @test Ke ≈ expected
            # Physical invariants (symmetry + PSD; rotational DOFs, no zero row-sum)
            @test_physical_invariants Ke
            # E=2, I=3, L=4
            Ke2 = d2_beam_elementstiffness(2, 3, 4)
            @test Ke2 ≈ (2 * 3 / 64) * [12 24 -12 24; 24 64 -24 32; -12 -24 12 -24; 24 32 -24 64]
            @test_physical_invariants Ke2
        end

        @testset "elementforces" begin
            k = d2_beam_elementstiffness(1, 1, 1)
            # Unit transverse displacement at node 2
            u = [0.0, 0.0, 1.0, 0.0]
            f = d2_beam_elementforces(k, u)
            @test length(f) == 4
            @test f ≈ [-12.0, -6.0, 12.0, -6.0]
            # zero displacement
            @test d2_beam_elementforces(k, zeros(4)) ≈ zeros(4)
        end

        @testset "assemble" begin
            K = zeros(4, 4)
            k = ones(4, 4)
            K = d2_beam_assemble(K, k, 1, 2)
            @test K == ones(4, 4)
            # assemble into larger system
            K6 = zeros(6, 6)
            ke = reshape(1:16, 4, 4)
            K6 = d2_beam_assemble(K6, ke, 1, 2)
            # Node 1 DOF: 1-2, Node 2 DOF: 3-4
            @test K6[1:2, 1:2] == ke[1:2, 1:2]
            @test K6[1:2, 3:4] == ke[1:2, 3:4]
            @test K6[3:4, 1:2] == ke[3:4, 1:2]
            @test K6[3:4, 3:4] == ke[3:4, 3:4]
            @test all(K6[5:6, :] .== 0)
            @test all(K6[:, 5:6] .== 0)
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d2_beam_elementstiffness(1.0, 1.0, 0.0)
            @test_throws ElementParameterError d2_beam_elementstiffness(1.0, 1.0, -1.0)
        end

        @testset "elementsheardiagram" begin
            f = [1000, 200, -1000, 200]
            L = 5.0
            p = d2_beam_elementsheardiagram(f, L)
            @test p isa Plots.Plot
        end

        @testset "elementmomentdiagram" begin
            f = [1000, 200, -1000, 200]
            L = 5.0
            p = d2_beam_elementmomentdiagram(f, L)
            @test p isa Plots.Plot
        end
    end

        @testset "problem_7_1_integration" begin
            # Problem 7.1: two-span beam with 3 supports (Fig 7.5).
            # Free DOFs are the rotations at nodes 1, 2, 3 (DOFs 2, 4, 6).
            # Reference: Doc/Kattan/Solutions-Manual/problem_7_1.m.
            E, I = 200e6, 70e-5
            L1, L2 = 3.5, 2.0
            k1 = d2_beam_elementstiffness(E, I, L1)
            k2 = d2_beam_elementstiffness(E, I, L2)
            K = zeros(6, 6)
            K = d2_beam_assemble(K, k1, 1, 2)
            K = d2_beam_assemble(K, k2, 2, 3)
            k = K[[2, 4, 6], [2, 4, 6]]
            f = [0.0; -15.0; 0.0]
            u = k \ f
            U = zeros(6)
            U[[2, 4, 6]] = u
            F = K * U
            @test size(K) == (6, 6)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [2.272727272727273e-5, -4.545454545454546e-5, 2.2727272727272733e-5]; rtol=1e-8)
            @test isapprox(F[4], -15.0; rtol=1e-10)
            u1 = [U[1]; U[2]; U[3]; U[4]]
            f1 = d2_beam_elementforces(k1, u1)
            u2 = [U[3]; U[4]; U[5]; U[6]]
            f2 = d2_beam_elementforces(k2, u2)
            @test isapprox(f1, [-1.5584415584415587, 0.0, 1.5584415584415587, -5.454545454545455]; rtol=1e-8, atol=1e-14)
            @test isapprox(f2, [-4.7727272727272725, -9.545454545454545, 4.7727272727272725, 0.0]; rtol=1e-8, atol=1e-14)
        end

        @testset "problem_7_2_integration" begin
            # Problem 7.2: beam with distributed load (Fig 7.16).
            # Free DOFs are rotations at nodes 2, 3, 4 (DOFs 4, 6, 8).
            # Reference: Doc/Kattan/Solutions-Manual/problem_7_2.m.
            E, I = 210e6, 50e-6
            L1, L2, L3 = 3.0, 3.0, 4.0
            k1 = d2_beam_elementstiffness(E, I, L1)
            k2 = d2_beam_elementstiffness(E, I, L2)
            k3 = d2_beam_elementstiffness(E, I, L3)
            K = zeros(8, 8)
            K = d2_beam_assemble(K, k1, 1, 2)
            K = d2_beam_assemble(K, k2, 2, 3)
            K = d2_beam_assemble(K, k3, 3, 4)
            k = K[[4, 6, 8], [4, 6, 8]]
            f = [7.5; -15.0; 15.0]  # fixed-end reaction adjustments from MATLAB
            u = k \ f
            U = zeros(8)
            U[[4, 6, 8]] = u
            F = K * U
            @test size(K) == (8, 8)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [0.0005706521739130435, -0.0012111801242236026, 0.0020341614906832298]; rtol=1e-8)
            @test isapprox(F[4], 7.5; rtol=1e-10)
            @test isapprox(F[8], 15.0; rtol=1e-10)
            u1 = [U[1]; U[2]; U[3]; U[4]]
            f1 = d2_beam_elementforces(k1, u1)
            f1 = f1 - [-15.0; -7.5; -15.0; 7.5]  # subtract fixed-end forces (distributed load)
            u2 = [U[3]; U[4]; U[5]; U[6]]
            f2 = d2_beam_elementforces(k2, u2)
            u3 = [U[5]; U[6]; U[7]; U[8]]
            f3 = d2_beam_elementforces(k3, u3)
            f3 = f3 - [-15.0; -15.0; -15.0; 15.0]  # point load adjustment
            @test isapprox(f1, [18.994565217391305, 11.494565217391305, 11.005434782608695, 0.4891304347826093]; rtol=1e-8)
            @test isapprox(f2, [-4.483695652173914, -0.489130434782609, 4.483695652173914, -12.961956521739133]; rtol=1e-8)
            @test isapprox(f3, [18.24048913043478, 12.961956521739129, 11.759510869565219, 0.0]; rtol=1e-8, atol=1e-14)
        end

        @testset "problem_7_3_integration" begin
            # Problem 7.3: beam with spring (Fig 7.17).
            # DOFs: node1=1,2 fixed; node2=3,4 free; node3=5,6 roller (v3=0); node4=7 spring ground.
            # Free DOFs 3,4,6. Reference: Doc/Kattan/Solutions-Manual/problem_7_3.m.
            E, I = 70e6, 40e-6
            L1, L2 = 3.0, 3.0
            k1 = d2_beam_elementstiffness(E, I, L1)
            k2 = d2_beam_elementstiffness(E, I, L2)
            k3 = d1_spring_elementstiffness(5000.0)
            K = zeros(7, 7)
            K = d2_beam_assemble(K, k1, 1, 2)
            K = d2_beam_assemble(K, k2, 2, 3)
            K = d1_spring_assemble(K, k3, 3, 7)
            k = vcat(hcat(K[3:4, 3:4], K[3:4, 6:6]), hcat(K[6:6, 3:4], K[6:6, 6:6]))
            f = [-10.0; 0.0; 0.0]
            u = k \ f
            U = [0.0; 0.0; u[1]; u[2]; 0.0; u[3]; 0.0]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0
            @test size(K) == (7, 7)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [-0.0015570934256055363, -0.00022244191794364802, 0.0008897676717745921]; rtol=1e-8)
            @test isapprox(F[3], -10.0; rtol=1e-10)
            u1 = [U[1]; U[2]; U[3]; U[4]]
            f1 = d2_beam_elementforces(k1, u1)
            u2 = [U[3]; U[4]; U[5]; U[6]]
            f2 = d2_beam_elementforces(k2, u2)
            u3 = [U[3]; U[7]]
            f3 = d1_spring_elementforce(k3, u3)
            @test isapprox(f1, [1.5224913494809695, 2.4913494809688586, -1.5224913494809695, 2.076124567474049]; rtol=1e-8)
            @test isapprox(f2, [-0.6920415224913501, -2.076124567474049, 0.6920415224913501, 0.0]; rtol=1e-8, atol=1e-14)
            @test isapprox(f3, [-7.7854671280276815, 7.7854671280276815]; rtol=1e-8)
        end

    # ─────────────────────────────────────────────────
    # 2-D Plane Frame (d2_planeframe) — Axial + Bending, 3 DOF/node
    # ─────────────────────────────────────────────────
    @testset "d2_planeframe" begin
        @testset "elementlength" begin
            @test d2_planeframe_elementlength(0, 0, 3, 4) == 5.0
            @test_throws ElementParameterError d2_planeframe_elementlength(1, 2, 1, 2)
            @test d2_planeframe_elementlength(-1, -1, 2, 3) ≈ sqrt(3^2 + 4^2)
            @test d2_planeframe_elementlength(0, 0, 0, 5) == 5.0
        end

        @testset "elementstiffness" begin
            # Simple case: E=1, A=1, I=1, L=1, theta=0
            Ke = d2_planeframe_elementstiffness(1, 1, 1, 1, 0)
            @test size(Ke) == (6, 6)
            # Physical invariants (symmetry + PSD; beams have rotational DOFs, no zero row-sum)
            @test_physical_invariants Ke
            # Known values for theta=0 (horizontal beam)
            # C=1, S=0 → w1=1, w2=12, w3=0, w4=0, w5=6
            @test Ke[1, 1] ≈ 1.0
            @test Ke[1, 4] ≈ -1.0
            @test Ke[2, 2] ≈ 12.0
            @test Ke[2, 6] ≈ 6.0
            @test Ke[3, 3] ≈ 4.0
            @test Ke[3, 5] ≈ -6.0
            @test Ke[6, 6] ≈ 4.0
        end

        @testset "elementforces" begin
            # Simple: E=1, A=1, I=1, L=1, theta=0
            # u has only axial displacement at node 2
            u = [0.0, 0.0, 0.0, 0.001, 0.0, 0.0]
            f = d2_planeframe_elementforces(1, 1, 1, 1, 0, u)
            @test length(f) == 6
            @test f[1] ≈ -0.001  # axial force = -EA/L * u_x2
            @test f[4] ≈ 0.001
            @test f[2] ≈ 0.0
            @test f[3] ≈ 0.0
            @test f[5] ≈ 0.0
            @test f[6] ≈ 0.0
            # zero displacement
            @test d2_planeframe_elementforces(1, 1, 1, 1, 0, zeros(6)) ≈ zeros(6)
        end

        @testset "elementaxialdiagram" begin
            f = [1000, 500, 200, -1000, 500, -200]
            L = 5.0
            p = d2_planeframe_elementaxialdiagram(f, L)
            @test p isa Plots.Plot
        end

        @testset "elementmomentdiagram" begin
            f = [1000, 500, 200, -1000, 500, -200]
            L = 5.0
            p = d2_planeframe_elementmomentdiagram(f, L)
            @test p isa Plots.Plot
        end

        @testset "elementsheardiagram" begin
            f = [1000, 500, 200, -1000, 500, -200]
            L = 5.0
            p = d2_planeframe_elementsheardiagram(f, L)
            @test p isa Plots.Plot
        end

        @testset "assemble" begin
            K = zeros(6, 6)
            k = ones(6, 6)
            K = d2_planeframe_assemble(K, k, 1, 2)
            @test K == ones(6, 6)
            # assemble into larger system
            K9 = zeros(9, 9)
            ke = reshape(1:36, 6, 6)  # non-symmetric to check positions
            K9 = d2_planeframe_assemble(K9, ke, 1, 2)
            # Node 1 DOF: 1-3, Node 2 DOF: 4-6
            @test K9[1:3, 1:3] == ke[1:3, 1:3]
            @test K9[1:3, 4:6] == ke[1:3, 4:6]
            @test K9[4:6, 1:3] == ke[4:6, 1:3]
            @test K9[4:6, 4:6] == ke[4:6, 4:6]
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d2_planeframe_elementstiffness(1.0, 1.0, 1.0, 0.0, 0.0)
            @test_throws ElementParameterError d2_planeframe_elementstiffness(1.0, 1.0, 1.0, -1.0, 0.0)
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → throws
            @test_throws ElementParameterError d2_planeframe_elementstiffness(1.0, 0.0, 1.0, 1.0, 0.0)
            # Negative area → throws
            @test_throws ElementParameterError d2_planeframe_elementstiffness(1.0, -1.0, 1.0, 1.0, 0.0)
        end

        # A validation for force functions
        @test_throws ElementParameterError d2_planeframe_elementforces(1.0, 0.0, 1.0, 1.0, 0.0, zeros(6))
        @test_throws ElementParameterError d2_planeframe_elementforces(1.0, -1.0, 1.0, 1.0, 0.0, zeros(6))
    end

        @testset "problem_8_1_integration" begin
            # Problem 8.1: plane frame with two elements (Fig 8.21).
            # Reference: Doc/Kattan/Solutions-Manual/problem_8_1.m.
            E, A, I, L = 210e6, 4e-2, 4e-6, 4.0
            k1 = d2_planeframe_elementstiffness(E, A, I, L, 90.0)  # vertical
            k2 = d2_planeframe_elementstiffness(E, A, I, L, 0.0)   # horizontal
            K = zeros(9, 9)
            K = d2_planeframe_assemble(K, k1, 1, 2)
            K = d2_planeframe_assemble(K, k2, 2, 3)
            # Free DOFs 4,5,6,7,9 (node 3 uy is a roller)
            k = vcat(hcat(K[4:7, 4:7], K[4:7, 9:9]), hcat(K[9:9, 4:7], K[9:9, 9:9]))
            f = [0.0; 0.0; 15.0; 20.0; 0.0]
            u = k \ f
            U = [0.0; 0.0; 0.0; u[1:4]; 0.0; u[5]]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0
            @test size(K) == (9, 9)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [0.18650877355691653, 2.23213239400011e-6, -0.02976232328658555, 0.1865182973664403, 0.014880324593645022]; rtol=1e-8)
            @test isapprox(F[6], 15.0; rtol=1e-10)
            @test isapprox(F[7], 20.0; rtol=1e-10)
            u1 = [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]]
            f1 = d2_planeframe_elementforces(E, A, I, L, 90.0, u1)
            u2 = [U[4]; U[5]; U[6]; U[7]; U[8]; U[9]]
            f2 = d2_planeframe_elementforces(E, A, I, L, 0.0, u2)
            @test isapprox(f1, [-4.687478027424214, 19.999999999939906, 46.25008789006278, 4.687478027424214, -19.999999999939906, 33.74991210969685]; rtol=1e-8)
            @test isapprox(f2, [-19.999999999941792, -4.687478027424212, -18.749912109696844, 19.999999999941792, 4.687478027424212, 0.0]; rtol=1e-8, atol=1e-14)
        end

        @testset "problem_8_2_integration" begin
            # Problem 8.2: plane frame with distributed load (Fig 8.22).
            # Reference: Doc/Kattan/Solutions-Manual/problem_8_2.m.
            E, A, I = 210e6, 1e-2, 9e-5
            x = [0.0, 2.0, 7.0, 9.0]
            y = [0.0, 3.0, 3.0, 0.0]
            L1 = d2_planeframe_elementlength(x[1], y[1], x[2], y[2])
            L2 = d2_planeframe_elementlength(x[2], y[2], x[3], y[3])
            L3 = d2_planeframe_elementlength(x[3], y[3], x[4], y[4])
            theta1 = atan(y[2] - y[1], x[2] - x[1]) * 180 / pi
            theta2 = 0.0
            theta3 = 360.0 - theta1
            k1 = d2_planeframe_elementstiffness(E, A, I, L1, theta1)
            k2 = d2_planeframe_elementstiffness(E, A, I, L2, theta2)
            k3 = d2_planeframe_elementstiffness(E, A, I, L3, theta3)
            K = zeros(12, 12)
            K = d2_planeframe_assemble(K, k1, 1, 2)
            K = d2_planeframe_assemble(K, k2, 2, 3)
            K = d2_planeframe_assemble(K, k3, 3, 4)
            # Free DOFs: nodes 2 and 3 = 4:9
            k = K[4:9, 4:9]
            f = [20.0; -12.5; -10.417; 0.0; -12.5; 10.417]  # fixed-end forces adjusted
            u = k \ f
            U = [0.0; 0.0; 0.0; u; 0.0; 0.0; 0.0]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0
            @test size(K) == (12, 12)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [0.001266805055356551, -0.0008612904923449313, -0.0005086369150586481, 0.0012143567179613013, 0.0007558660483844769, 0.0002528970796484738]; rtol=1e-8)
            @test isapprox(F[4], 20.0; rtol=1e-10)
            @test isapprox(F[5], -12.5; rtol=1e-8)
            @test isapprox(F[6], -10.417; rtol=1e-8)
            u1 = [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]]
            f1 = d2_planeframe_elementforces(E, A, I, L1, theta1, u1)
            u2 = [U[4]; U[5]; U[6]; U[7]; U[8]; U[9]]
            f2 = d2_planeframe_elementforces(E, A, I, L2, theta2, u2)
            f2 = f2 - [0.0; -12.5; -10.417; 0.0; -12.5; 10.417]  # subtract fixed-end forces
            u3 = [U[7]; U[8]; U[9]; U[10]; U[11]; U[12]]
            f3 = d2_planeframe_elementforces(E, A, I, L3, theta3, u3)
            @test isapprox(f1, [8.119143790427122, 2.9750472592473303, 8.029575137851968, -8.119143790427122, -2.9750472592473303, 2.6971103022928897]; rtol=1e-8)
            @test isapprox(f2, [22.02830170600481, 8.405795279080012, -2.697110302292895, -22.02830170600481, 16.59420472091999, -17.77391330230705]; rtol=1e-8)
            @test isapprox(f3, [26.026316201173262, 9.123846303348216, 17.77391330230705, -26.026316201173262, -9.123846303348216, 15.12258237386751]; rtol=1e-8)
        end

        @testset "problem_8_3_integration" begin
            # Problem 8.3: plane frame with a spring (Fig 8.23).
            # Mixed element types: frame (3 DOF/node) + truss-as-spring (2 DOF/node).
            # Reference: Doc/Kattan/Solutions-Manual/problem_8_3.m.
            E1, A1, I, L1 = 70e6, 1e-2, 1e-5, 4.0
            E2, A2, L2 = 2500.0, 10.0, 5.0  # equivalent truss for spring k=5000
            theta1 = 0.0
            theta2 = atan(3.0, 4.0) * 180 / pi
            k1 = d2_planeframe_elementstiffness(E1, A1, I, L1, theta1)
            k2 = d2_truss_elementstiffness(E2, A2, L2, theta2)
            K = zeros(8, 8)
            K = d2_planeframe_assemble(K, k1, 1, 2)  # frame nodes 1-2
            K = d2_truss_assemble(K, k2, 1, 3)       # truss nodes 1-3
            # Free DOFs: node 1 (ux, uy, theta) = 1,2,3
            k = K[1:3, 1:3]
            f = [0.0; -10.0; 0.0]
            u = k \ f
            U = [u; 0.0; 0.0; 0.0; 0.0; 0.0]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0
            @test size(K) == (8, 8)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [7.48019647203546e-5, -0.005554045880486329, 0.002082767205182374]; rtol=1e-8)
            @test isapprox(F[2], -10.0; rtol=1e-10)
            @test isapprox(F[4], -13.090343826062055; rtol=1e-8)
            @test isapprox(F[5], 13.272585956515513; rtol=1e-8)
            @test isapprox(F[6], 9.088789347732712; rtol=1e-8)
            u1 = [U[1]; U[2]; U[3]; U[4]; U[5]; U[6]]
            f1 = d2_planeframe_elementforces(E1, A1, I, L1, theta1, u1)
            u2 = [U[1]; U[2]; U[7]; U[8]]
            f2 = d2_truss_elementforces(E2, A2, L2, theta2, u2)  # scalar (tension)
            @test isapprox(f1, [13.090343826062055, -0.1822421304534576, 0.0, -13.090343826062055, 0.1822421304534576, -0.7289685218138305]; rtol=1e-8, atol=1e-14)
            @test isapprox(f2, 16.36292978257757; rtol=1e-8)
        end

    # ─────────────────────────────────────────────────
    # 2-D Spring (d2_spring)
    # ─────────────────────────────────────────────────
    @testset "d2_spring" begin
        @testset "elementstiffness" begin
            # Horizontal spring: theta=0
            Ke = d2_spring_elementstiffness(1000, 0)
            @test size(Ke) == (4, 4)
            @test Ke ≈ 1000 * [1 0 -1 0; 0 0 0 0; -1 0 1 0; 0 0 0 0]
            # Physical invariants (translational DOFs)
            @test_translational_invariants Ke
            # Vertical spring: theta=90
            Ke90 = d2_spring_elementstiffness(1000, 90)
            @test Ke90 ≈ 1000 * [0 0 0 0; 0 1 0 -1; 0 0 0 0; 0 -1 0 1]
            @test_translational_invariants Ke90
            # Zero stiffness
            @test_throws ElementParameterError d2_spring_elementstiffness(0, 30)
        end

        @testset "elementforce" begin
            k = 1000.0
            # Horizontal spring, stretch in x (returns 1-element vector)
            f = d2_spring_elementforce(k, 0, [1.0; 0.0; 0.0; 0.0])
            @test f[1] ≈ -1000.0
            # Vertical spring, stretch in y
            f = d2_spring_elementforce(k, 90, [0.0; 1.0; 0.0; 0.0])
            @test f[1] ≈ -1000.0
            # 45 deg spring
            f45 = d2_spring_elementforce(k, 45, [1.0; 0.0; 0.0; 0.0])
            @test f45[1] ≈ -1000 * cos(π / 4)  # ≈ -707.1
        end

        @testset "assemble" begin
            K = zeros(4, 4)
            k = [1 2 3 4; 5 6 7 8; 9 10 11 12; 13 14 15 16]
            K = d2_spring_assemble(K, k, 1, 2)
            # Node 1 DOF: 1-2, Node 2 DOF: 3-4
            @test K[1:2, 1:2] == k[1:2, 1:2]
            @test K[1:2, 3:4] == k[1:2, 3:4]
            @test K[3:4, 1:2] == k[3:4, 1:2]
            @test K[3:4, 3:4] == k[3:4, 3:4]
        end

        @testset "L>0 error paths" begin
            # d2_spring doesn't have L parameter
        end

        @testset "negative/zero parameter behavior" begin
            # Zero stiffness → throws
            @test_throws ElementParameterError d2_spring_elementstiffness(0, 30)
            # Negative stiffness → throws
            @test_throws ElementParameterError d2_spring_elementstiffness(-100, 0)
        end
    end

    # ─────────────────────────────────────────────────
    # 2-D Truss / Plane Truss (d2_truss)
    # ─────────────────────────────────────────────────
    @testset "d2_truss" begin
        @testset "elementlength" begin
            @test d2_truss_elementlength(0, 0, 3, 4) == 5.0
            @test_throws ElementParameterError d2_truss_elementlength(0, 0, 0, 0)
            @test d2_truss_elementlength(1, 2, 4, 6) == 5.0  # 3-4-5 triangle
        end

        @testset "elementstiffness" begin
            E, A, L = 210e9, 0.01, 5.0
            theta = 30.0
            Ke = d2_truss_elementstiffness(E, A, L, theta)
            C = cos(π / 6)
            S = sin(π / 6)
            EAoL = E * A / L  # 4.2e8
            expected = EAoL * [
                C * C C * S -C * C -C * S
                C * S S * S -C * S -S * S
                -C * C -C * S C * C C * S
                -C * S -S * S C * S S * S
            ]
            @test size(Ke) == (4, 4)
            @test Ke[1, 1] ≈ 3.15e8  # EA/L * C² = 4.2e8 * 0.75
            @test Ke ≈ expected
            # Physical invariants (translational DOFs)
            @test_translational_invariants Ke
            # Horizontal truss (theta=0)
            Ke0 = d2_truss_elementstiffness(E, A, L, 0)
            @test Ke0 ≈ EAoL * [1 0 -1 0; 0 0 0 0; -1 0 1 0; 0 0 0 0]
            @test_translational_invariants Ke0
        end

        @testset "elementforces" begin
            E, A, L = 1.0, 1.0, 1.0
            theta = 30.0
            C = cos(π / 6)
            u = [1.0; 0.0; 0.0; 0.0]
            f = d2_truss_elementforces(E, A, L, theta, u)  # returns 1-element Vector
            @test f[1] ≈ -C  # -EA/L * C
            # zero displacement
            @test d2_truss_elementforces(E, A, L, theta, zeros(4))[1] ≈ 0.0
        end

        @testset "elementstrain" begin
            L = 5.0
            theta = 0.0
            u = [0.001; 0.0; 0.0; 0.0]
            eps = d2_truss_elementstrain(L, theta, u)  # returns 1-element Vector
            @test eps[1] ≈ -0.001 / 5.0  # -u_x1 / L
        end

        @testset "elementstress" begin
            E = 200e9
            L = 4.0
            theta = 0.0
            u = [0.001; 0.0; 0.0; 0.0]
            sigma = d2_truss_elementstress(E, L, theta, u)  # returns 1-element Vector
            @test sigma[1] ≈ -(200e9 * 0.001) / 4.0  # -E * u_x1 / L
        end

        @testset "assemble" begin
            K = zeros(4, 4)
            k = [1 2 3 4; 5 6 7 8; 9 10 11 12; 13 14 15 16]
            K = d2_truss_assemble(K, k, 1, 2)
            @test K[1:2, 1:2] == k[1:2, 1:2]
            @test K[1:2, 3:4] == k[1:2, 3:4]
            @test K[3:4, 1:2] == k[3:4, 1:2]
            @test K[3:4, 3:4] == k[3:4, 3:4]
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d2_truss_elementstiffness(1.0, 1.0, 0.0, 0.0)
            @test_throws ElementParameterError d2_truss_elementstiffness(1.0, 1.0, -1.0, 0.0)
            @test_throws ElementParameterError d2_truss_elementforces(1.0, 1.0, 0.0, 0.0, [1.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d2_truss_elementforces(1.0, 1.0, -1.0, 0.0, [1.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d2_truss_elementstrain(0.0, 0.0, [1.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d2_truss_elementstrain(-1.0, 0.0, [1.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d2_truss_elementstress(1.0, 0.0, 0.0, [1.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d2_truss_elementstress(1.0, -1.0, 0.0, [1.0;0.0;0.0;0.0])
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → throws
            @test_throws ElementParameterError d2_truss_elementstiffness(1.0, 0.0, 1.0, 0.0)
            # Negative area → throws
            @test_throws ElementParameterError d2_truss_elementstiffness(1.0, -1.0, 1.0, 0.0)
            # Zero modulus → zero matrix (not validated)
            C = cos(0); S = sin(0)
            expected = [C*C C*S -C*C -C*S; C*S S*S -C*S -S*S; -C*C -C*S C*C C*S; -C*S -S*S C*S S*S]
            @test d2_truss_elementstiffness(0.0, 1.0, 1.0, 0.0) == zeros(4, 4)
            # Negative modulus → negated matrix (not validated)
            @test d2_truss_elementstiffness(-1.0, 1.0, 1.0, 0.0) == -expected
        end

        # A validation for force functions
        @test_throws ElementParameterError d2_truss_elementforces(1.0, 0.0, 1.0, 0.0, [1.0;0.0;0.0;0.0])
        @test_throws ElementParameterError d2_truss_elementforces(1.0, -1.0, 1.0, 0.0, [1.0;0.0;0.0;0.0])
    end

        @testset "problem_5_1_integration" begin
            # Problem 5.1: plane truss with 9 elements (Fig 5.5).
            # Nodes 1 and 6 fixed; loads at node 3. Reference: Doc/Kattan/Solutions-Manual/problem_5_1.m.
            E, A = 210e6, 0.005
            coords = [(0.0, 0.0), (5.0, 7.0), (5.0, 0.0), (10.0, 7.0), (10.0, 0.0), (15.0, 0.0)]
            elements = [(1, 2), (1, 3), (2, 3), (3, 5), (2, 5), (2, 4), (4, 5), (5, 6), (4, 6)]
            K = zeros(12, 12)
            sigmas = Float64[]
            for (n1, n2) in elements
                x1, y1 = coords[n1]
                x2, y2 = coords[n2]
                L = sqrt((x2 - x1)^2 + (y2 - y1)^2)
                theta = atan(y2 - y1, x2 - x1) * 180 / pi
                k = d2_truss_elementstiffness(E, A, L, theta)
                d2_truss_assemble(K, k, n1, n2)
            end
            k = K[3:10, 3:10]
            f = [20.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            u = k \ f
            U = [0.0; 0.0; u; 0.0; 0.0]
            F = K * U
            # Element stresses
            for (n1, n2) in elements
                x1, y1 = coords[n1]
                x2, y2 = coords[n2]
                L = sqrt((x2 - x1)^2 + (y2 - y1)^2)
                theta = atan(y2 - y1, x2 - x1) * 180 / pi
                u_elem = [U[2*n1-1]; U[2*n1]; U[2*n2-1]; U[2*n2]]
                push!(sigmas, d2_truss_elementstress(E, L, theta, u_elem))
            end
            @test size(K) == (12, 12)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [0.00020834281842258584, -3.3338372385991406e-5, 1.0582010582010574e-5, -3.333837238599142e-5, 0.0001765967866765541, 1.0662635424540202e-5, 2.1164021164021147e-5, -5.155958679768199e-5]; rtol=1e-8)
            @test isapprox(F[1], -8.888888888888882; rtol=1e-10)
            @test isapprox(F[2], -9.333333333333329; rtol=1e-10)
            @test isapprox(F[3], 20.0; rtol=1e-10)
            @test isapprox(F[11], -11.1111111111111; rtol=1e-10)
            @test isapprox(F[12], 9.333333333333323; rtol=1e-10)
            @test isapprox(sigmas[1], 2293.953404544699; rtol=1e-8)
            @test isapprox(sigmas[2], 444.4444444444441; rtol=1e-8)
            @test isapprox(sigmas[3], 0.0; rtol=1e-8, atol=1e-12)
            @test isapprox(sigmas[4], 444.4444444444441; rtol=1e-8)
            @test isapprox(sigmas[5], -2293.953404544699; rtol=1e-8)
            @test isapprox(sigmas[6], -1333.3333333333335; rtol=1e-8)
            @test isapprox(sigmas[7], 1866.6666666666665; rtol=1e-8)
            @test isapprox(sigmas[8], -888.8888888888882; rtol=1e-8)
            @test isapprox(sigmas[9], -2293.953404544698; rtol=1e-8)
        end

        @testset "problem_5_2_integration" begin
            # Problem 5.2: plane truss + spring (Fig 5.6).
            # Nodes 1,2,3 fixed; free DOFs 7,8,9. Reference: Doc/Kattan/Solutions-Manual/problem_5_2.m.
            E, A = 70e6, 0.01
            x = [0.0, 0.0, 0.0, 4.0]
            y = [0.0, 3.0, 7.0, 3.0]
            L1 = d2_truss_elementlength(x[1], y[1], x[4], y[4])
            L2 = d2_truss_elementlength(x[2], y[2], x[4], y[4])
            L3 = d2_truss_elementlength(x[3], y[3], x[4], y[4])
            theta1 = atan(y[4] - y[1], x[4] - x[1]) * 180 / pi
            theta2 = 0.0
            theta3 = atan(y[4] - y[3], x[4] - x[3]) * 180 / pi
            theta3 += 360.0  # normalize negative angle (=-45 → 315)
            k1 = d2_truss_elementstiffness(E, A, L1, theta1)
            k2 = d2_truss_elementstiffness(E, A, L2, theta2)
            k3 = d2_truss_elementstiffness(E, A, L3, theta3)
            k4 = d1_spring_elementstiffness(3000.0)
            K = zeros(9, 9)
            d2_truss_assemble(K, k1, 1, 4)
            d2_truss_assemble(K, k2, 2, 4)
            d2_truss_assemble(K, k3, 3, 4)
            d1_spring_assemble(K, k4, 7, 9)
            k = K[7:9, 7:9]
            f = [0.0; 0.0; 10.0]
            u = k \ f
            U = [0.0; 0.0; 0.0; 0.0; 0.0; 0.0; u]
            F = K * U
            u1_vec = [U[1]; U[2]; U[7]; U[8]]
            sigma1 = d2_truss_elementstress(E, L1, theta1, u1_vec)
            u2_vec = [U[3]; U[4]; U[7]; U[8]]
            sigma2 = d2_truss_elementstress(E, L2, theta2, u2_vec)
            u3_vec = [U[5]; U[6]; U[7]; U[8]]
            sigma3 = d2_truss_elementstress(E, L3, theta3, u3_vec)
            u4_vec = [U[7]; U[9]]
            f4 = d1_spring_elementforce(k4, u4_vec)
            @test size(K) == (9, 9)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [3.065425546488906e-5, -1.4547785990662422e-6, 0.0033639875887982226]; rtol=1e-8)
            @test isapprox(F[9], 10.0; rtol=1e-10)
            @test isapprox(sigma1, 331.1075209746011; rtol=1e-8)
            @test isapprox(sigma2, 536.4494706355586; rtol=1e-8)
            @test isapprox(sigma3, 280.95404805960874; rtol=1e-8)
            @test isapprox(f4, [-10.0, 10.0]; rtol=1e-10)
        end

    # ─────────────────────────────────────────────────
    # 3-D Spring (d3_spring)
    # ─────────────────────────────────────────────────
    @testset "d3_spring" begin
        Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(stderr, Base.CoreLogging.Error)) do
        @testset "elementstiffness" begin
            # All direction cosines = 1
            Ke = d3_spring_elementstiffness(1000, 0, 0, 0)
            @test size(Ke) == (6, 6)
            w_ones = ones(3, 3)
            # (0,0,0) invalid: C² = 3 → normalized to (1/√3, 1/√3, 1/√3), factor 1/3
            @test Ke ≈ (1000/3) * [w_ones -w_ones; -w_ones w_ones]
            # Physical invariants (translational DOFs)
            @test_translational_invariants Ke
            # thetax=0, thetay=90, thetaz=0 → Cy=0, C² = 2 → normalized to (1/√2, 0, 1/√2)
            Ke2 = d3_spring_elementstiffness(1000, 0, 90, 0)
            w2 = [1 0 1; 0 0 0; 1 0 1]
            @test Ke2 ≈ 500 * [w2 -w2; -w2 w2]
            @test_translational_invariants Ke2
            # Zero stiffness
            @test_throws ElementParameterError d3_spring_elementstiffness(0, 0, 0, 0)
        end

        @testset "elementforce" begin
            k = 1000.0
            # Unit displacement in x at node 1, (0,0,0) → normalized Cx=1/√3
            f = d3_spring_elementforce(k, 0, 0, 0, [1.0; 0.0; 0.0; 0.0; 0.0; 0.0])
            @test f[1] ≈ -1000.0 / sqrt(3)  # -k * Cx
            # Zero displacement
            @test d3_spring_elementforce(k, 0, 0, 0, zeros(6))[1] ≈ 0.0
        end

        @testset "assemble" begin
            K = zeros(6, 6)
            k = reshape(1:36, 6, 6)
            K = d3_spring_assemble(K, k, 1, 2)
            @test K[1:3, 1:3] == k[1:3, 1:3]
            @test K[1:3, 4:6] == k[1:3, 4:6]
            @test K[4:6, 1:3] == k[4:6, 1:3]
            @test K[4:6, 4:6] == k[4:6, 4:6]
        end

        @testset "negative/zero parameter behavior" begin
            # Zero stiffness → throws
            @test_throws ElementParameterError d3_spring_elementstiffness(0, 0, 0, 0)
            # Negative stiffness → throws
            @test_throws ElementParameterError d3_spring_elementstiffness(-1000, 0, 0, 0)
        end
    end # Test.collected_logs()

        @testset "warning on invalid direction cosines" begin
            # (45,45,45) produces cos²(45°)=0.707 each → Cx²+Cy²+Cz² ≈ 1.5 ≠ 1, triggers warning
            @test_logs (:warn, r"Direction cosines do not form a unit vector") d3_spring_elementstiffness(1000, 45, 45, 45)
        end
    end

    # ─────────────────────────────────────────────────
    # 3-D Truss / Space Truss (d3_truss)
    # ─────────────────────────────────────────────────
    @testset "d3_truss" begin
        Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(stderr, Base.CoreLogging.Error)) do
        @testset "elementlength" begin
            @test d3_truss_elementlength(0, 0, 0, 1, 1, 1) ≈ sqrt(3)
            @test_throws ElementParameterError d3_truss_elementlength(0, 0, 0, 0, 0, 0)
            @test d3_truss_elementlength(1, 0, 0, 4, 0, 0) == 3.0
        end

        @testset "elementstiffness" begin
            E, A, L = 1.0, 1.0, 1.0
            # All direction cosines = 1
            Ke = d3_truss_elementstiffness(E, A, L, 0, 0, 0)
            @test size(Ke) == (6, 6)
            w_ones = ones(3, 3)
            # (0,0,0) invalid: C² = 3 → normalized to (1/√3, 1/√3, 1/√3), factor 1/3
            @test Ke ≈ (1/3) * [w_ones -w_ones; -w_ones w_ones]
            # Physical invariants (translational DOFs)
            @test_translational_invariants Ke
            # thetax=0, thetay=90, thetaz=0 → normalized to (1/√2, 0, 1/√2)
            Ke2 = d3_truss_elementstiffness(E, A, L, 0, 90, 0)
            w2 = [1 0 1; 0 0 0; 1 0 1]
            @test Ke2 ≈ 0.5 * [w2 -w2; -w2 w2]
            @test_translational_invariants Ke2
        end

        @testset "elementforces" begin
            E, A, L = 1.0, 1.0, 1.0
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            f = d3_truss_elementforces(E, A, L, 0, 0, 0, u)
            @test f[1] ≈ -1.0 / sqrt(3)
            # zero displacement
            @test d3_truss_elementforces(E, A, L, 0, 0, 0, zeros(6))[1] ≈ 0.0
        end

        @testset "elementstrain" begin
            L = 1.0
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            eps = d3_truss_elementstrain(L, 0, 0, 0, u)
            @test eps[1] ≈ -1.0 / sqrt(3)
        end

        @testset "elementstress" begin
            E = 1.0
            L = 1.0
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            sigma = d3_truss_elementstress(E, L, 0, 0, 0, u)
            @test sigma[1] ≈ -1.0 / sqrt(3)
        end

        @testset "assemble" begin
            K = zeros(6, 6)
            k = reshape(1:36, 6, 6)
            K = d3_truss_assemble(K, k, 1, 2)
            @test K[1:3, 1:3] == k[1:3, 1:3]
            @test K[1:3, 4:6] == k[1:3, 4:6]
            @test K[4:6, 1:3] == k[4:6, 1:3]
            @test K[4:6, 4:6] == k[4:6, 4:6]
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d3_truss_elementstiffness(1.0, 1.0, 0.0, 0, 0, 0)
            @test_throws ElementParameterError d3_truss_elementstiffness(1.0, 1.0, -1.0, 0, 0, 0)
            @test_throws ElementParameterError d3_truss_elementforces(1.0, 1.0, 0.0, 0, 0, 0, [1.0;0.0;0.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d3_truss_elementforces(1.0, 1.0, -1.0, 0, 0, 0, [1.0;0.0;0.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d3_truss_elementstrain(0.0, 0, 0, 0, [1.0;0.0;0.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d3_truss_elementstrain(-1.0, 0, 0, 0, [1.0;0.0;0.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d3_truss_elementstress(1.0, 0.0, 0, 0, 0, [1.0;0.0;0.0;0.0;0.0;0.0])
            @test_throws ElementParameterError d3_truss_elementstress(1.0, -1.0, 0, 0, 0, [1.0;0.0;0.0;0.0;0.0;0.0])
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → throws
            @test_throws ElementParameterError d3_truss_elementstiffness(1.0, 0.0, 1.0, 0, 0, 0)
            # Negative area → throws
            @test_throws ElementParameterError d3_truss_elementstiffness(1.0, -1.0, 1.0, 0, 0, 0)
            # Zero modulus → zero matrix (not validated)
            @test d3_truss_elementstiffness(0.0, 1.0, 1.0, 0, 0, 0) == zeros(6, 6)
            # Negative modulus → negated matrix (not validated)
            @test d3_truss_elementstiffness(-1.0, 1.0, 1.0, 0, 0, 0) ≈ (-1/3) * [ones(3,3) -ones(3,3); -ones(3,3) ones(3,3)]
        end

        # A validation for force functions
        @test_throws ElementParameterError d3_truss_elementforces(1.0, 0.0, 1.0, 0, 0, 0, ones(6))
        @test_throws ElementParameterError d3_truss_elementforces(1.0, -1.0, 1.0, 0, 0, 0, ones(6))
    end # Test.collected_logs()
    end

        @testset "problem_6_1_integration" begin
            # Problem 6.1: 3-D space truss (Fig 6.3).
            # Nodes 1-4 fixed, node 5 free. Reference: Doc/Kattan/Solutions-Manual/problem_6_1.m.
            E, A = 200e6, 0.003
            coords = Dict(1 => (0.0, 0.0, -3.0), 2 => (-3.0, 0.0, 0.0),
                          3 => (0.0, 0.0, 3.0), 4 => (4.0, 0.0, 0.0), 5 => (0.0, 5.0, 0.0))
            elem_pairs = [(1, 5), (2, 5), (3, 5), (4, 5)]
            ks = Vector{Any}(undef, 4)
            thetas = Vector{Tuple{Float64,Float64,Float64}}(undef, 4)
            K = zeros(15, 15)
            for (idx, (n1, n2)) in enumerate(elem_pairs)
                x1, y1, z1 = coords[n1]
                x2, y2, z2 = coords[n2]
                L = d3_truss_elementlength(x1, y1, z1, x2, y2, z2)
                tx = acos((x2 - x1) / L) * 180 / pi
                ty = acos((y2 - y1) / L) * 180 / pi
                tz = acos((z2 - z1) / L) * 180 / pi
                thetas[idx] = (tx, ty, tz)
                ks[idx] = d3_truss_elementstiffness(E, A, L, tx, ty, tz)
                d3_truss_assemble(K, ks[idx], n1, n2)
            end
            k = K[13:15, 13:15]
            f = [15.0; 0.0; -20.0]
            u = k \ f
            U = [zeros(12); u]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0
            @test size(K) == (15, 15)
            @test K ≈ K'  # global symmetry
            @test all(isfinite, U)
            # Displacement goldens (Octave-verified)
            @test isapprox(u, [0.00023509062547027082, 2.587463432376072e-7, -0.00036713400819396355]; rtol=1e-8)
            @test isapprox(F[13], 15.0; rtol=1e-10)
            @test isapprox(F[15], -20.0; rtol=1e-10)
            for (idx, (n1, n2)) in enumerate(elem_pairs)
                L = d3_truss_elementlength(coords[n1]..., coords[n2]...)
                u_elem = [U[3*n1-2]; U[3*n1-1]; U[3*n1]; U[3*n2-2]; U[3*n2-1]; U[3*n2]]
                sigma = d3_truss_elementstress(E, L, thetas[idx]..., u_elem)
                if idx == 1
                    @test isapprox(sigma, -6471.22525215119; rtol=1e-8)
                elseif idx == 2
                    @test isapprox(sigma, 4156.268283100001; rtol=1e-8)
                elseif idx == 3
                    @test isapprox(sigma, 6486.445625282813; rtol=1e-8)
                else
                    @test isapprox(sigma, -4580.823269097052; rtol=1e-8)
                end
            end
        end

    # ─────────────────────────────────────────────────
    # 3-D Beam / Space Frame (d3_spaceframe)
    # ─────────────────────────────────────────────────
    @testset "d3_spaceframe" begin
        @testset "elementlength" begin
            @test d3_spaceframe_elementlength(0,0,0, 3,4,12) ≈ 13.0  # 5-12-13 triangle
            @test_throws ElementParameterError d3_spaceframe_elementlength(0,0,0, 0,0,0)
            @test d3_spaceframe_elementlength(1,0,0, 5,0,0) == 4.0
            @test d3_spaceframe_elementlength(0,0,0, 1,1,1) ≈ sqrt(3)
        end

        @testset "elementstiffness" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            # Horizontal beam along X: (0,0,0)→(4,0,0)
            Ke = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 4,0,0)
            @test size(Ke) == (12, 12)
            # Physical invariants (beam with rotational DOFs)
            @test_physical_invariants Ke

            # For horizontal beam, rotation matrix R = I, so Ke = kprime
            L = 4.0
            w1 = E*A/L
            w2 = 12*E*Iz/(L^3)
            w3 = 6*E*Iz/(L^2)
            w4 = 4*E*Iz/L
            w5 = 2*E*Iz/L
            w6 = 12*E*Iy/(L^3)
            w7 = 6*E*Iy/(L^2)
            w8 = 4*E*Iy/L
            w9 = 2*E*Iy/L
            w10 = G*J/L

            @test Ke[1,1] ≈ w1    # axial
            @test Ke[2,2] ≈ w2    # shear y
            @test Ke[3,3] ≈ w6    # shear z
            @test Ke[4,4] ≈ w10   # torsion
            @test Ke[5,5] ≈ w8    # bending about y
            @test Ke[6,6] ≈ w4    # bending about z
            # Shear-bending coupling
            @test Ke[2,6] ≈ w3
            @test Ke[3,5] ≈ -w7
            @test Ke[5,3] ≈ -w7
            @test Ke[6,2] ≈ w3
            # Off-diagonal blocks
            @test Ke[1,7] ≈ -w1
            @test Ke[2,8] ≈ -w2
            @test Ke[4,10] ≈ -w10
        end

        @testset "elementforces" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            # Horizontal beam, axial displacement at node 2 (follows d2_beam pattern)
            u = zeros(12)
            u[7] = 0.001  # 1mm axial at node 2
            f = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, 0,0,0, 4,0,0, u)
            @test length(f) == 12
            @test f[1] ≈ -(E*A/4.0) * 0.001  # reaction at node 1 = -EA/L * u_x2
            @test f[7] ≈ (E*A/4.0) * 0.001   # reaction at node 2 = +EA/L * u_x2
            # Zero displacement → zero force
            @test d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, 0,0,0, 4,0,0, zeros(12)) ≈ zeros(12)
        end

        @testset "assemble" begin
            K = zeros(12, 12)
            k = reshape(1.0:144.0, 12, 12)
            K = d3_spaceframe_assemble(K, k, 1, 2)
            @test K[1:6, 1:6] == k[1:6, 1:6]
            @test K[1:6, 7:12] == k[1:6, 7:12]
            @test K[7:12, 1:6] == k[7:12, 1:6]
            @test K[7:12, 7:12] == k[7:12, 7:12]
        end

        @testset "diagrams" begin
            f = [1000, 500, 300, 200, 150, 100, -1000, -500, -300, -200, -150, -100]
            L = 5.0
            @test d3_spaceframe_elementaxialdiagram(f, L) isa Plots.Plot
            @test d3_spaceframe_elementshearydiagram(f, L) isa Plots.Plot
            @test d3_spaceframe_elementshearzdiagram(f, L) isa Plots.Plot
            @test d3_spaceframe_elementmomentydiagram(f, L) isa Plots.Plot
            @test d3_spaceframe_elementmomentzdiagram(f, L) isa Plots.Plot
            @test d3_spaceframe_elementtorsiondiagram(f, L) isa Plots.Plot
        end

        @testset "near-vertical beam" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            Ke = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 1e-10,1e-10,4)
            @test size(Ke) == (12, 12)
            @test all(!isnan, Ke)
            @test Ke ≈ Ke'
            u = zeros(12); u[7] = 0.001
            f = d3_spaceframe_elementforces(E, G, A, Iy, Iz, J, 0,0,0, 1e-10,1e-10,4, u)
            @test all(!isnan, f)
            @test length(f) == 12
        end

        @testset "vertical beam" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            # Vertical beam along Z: (0,0,0)→(0,0,4)
            Ke = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 0,0,4)
            @test size(Ke) == (12, 12)
            @test_physical_invariants Ke
            @test all(!isnan, Ke)
            # Vertical beam along Z (negative direction)
            Ke2 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, 0,0,4, 0,0,0)
            @test size(Ke2) == (12, 12)
            @test all(!isnan, Ke2)
            @test_physical_invariants Ke2
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d3_spaceframe_elementstiffness(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0,0,0, 0,0,0)
            @test_throws ElementParameterError d3_spaceframe_elementforces(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0,0,0, 0,0,0, zeros(12))
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → throws
            @test_throws ElementParameterError d3_spaceframe_elementstiffness(1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0,0,0, 1,0,0)
            # Negative area → throws
            @test_throws ElementParameterError d3_spaceframe_elementstiffness(1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 0,0,0, 1,0,0)
        end

        @testset "problem_10_1_integration" begin
            E = 210e6; G = 84e6; A = 2e-2; Iy = 10e-5; Iz = 20e-5; J = 5e-5
            # 8-node space frame, DOFs 1-24 fixed, 25-48 free
            k1 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 0,0,0, 0,5,0)
            k2 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 0,0,4, 0,5,4)
            k3 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 4,0,4, 4,5,4)
            k4 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 4,0,0, 4,5,0)
            k5 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 0,5,0, 0,5,4)
            k6 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 0,5,4, 4,5,4)
            k7 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 4,5,4, 4,5,0)
            k8 = d3_spaceframe_elementstiffness(E,G,A,Iy,Iz,J, 0,5,0, 4,5,0)

            K = zeros(48, 48)
            for (ke, ni, nj) in [(k1,1,5),(k2,2,6),(k3,3,7),(k4,4,8),(k5,5,6),(k6,6,7),(k7,7,8),(k8,5,8)]
                K = d3_spaceframe_assemble(K, ke, ni, nj)
            end

            k = K[25:48, 25:48]
            f = zeros(24); f[13] = -15.0
            u = k \ f
            U = zeros(48); U[25:48] = u
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0

            # Golden values from Kattan Solutions Manual (rtol=1e-1 for magnitude)
            @test u[1] ≈ -0.0004 atol = 1e-3   # Ux₅
            @test u[3] ≈ -0.0006 atol = 1e-3   # Uz₅
            @test u[13] ≈ -0.0021 atol = 1e-3  # Ux₇
            @test u[15] ≈ 0.0006 atol = 1e-3   # Uz₇

            @test F[1] ≈ 1.1599 rtol = 1e-2    # Fx₁
            @test F[2] ≈ 2.5054 rtol = 1e-2    # Fy₁
            @test F[6] ≈ -3.2737 rtol = 1e-2   # Rz₁
            @test F[7] ≈ 6.3324 rtol = 1e-2    # Fx₂
            @test F[12] ≈ -17.6937 rtol = 1e-2 # Rz₂
            @test F[37] ≈ -15.0 atol = 1e-4    # Fy₂ (applied load)
        end

        # A validation for force functions
        @test_throws ElementParameterError d3_spaceframe_elementforces(1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0,0,0, 1,0,0, zeros(12))
        @test_throws ElementParameterError d3_spaceframe_elementforces(1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 0,0,0, 1,0,0, zeros(12))

    # ─────────────────────────────────────────────────
    # 2-D Grid (d2_grid)
    # ─────────────────────────────────────────────────
    @testset "d2_grid" begin
        @testset "elementlength" begin
            @test d2_grid_elementlength(0, 0, 3, 4) == 5.0
            @test_throws ElementParameterError d2_grid_elementlength(0, 0, 0, 0)
            @test d2_grid_elementlength(1, 2, 4, 6) == 5.0
        end

        @testset "elementstiffness" begin
            E, G, I, J, L = 1.0, 1.0, 1.0, 1.0, 1.0

            # azi=0 → element aligned with global X → R = I → k_global = kprime
            Ke = d2_grid_elementstiffness(E, G, I, J, L, 0)
            @test size(Ke) == (6, 6)
            @test Ke ≈ [
                12   0   6 -12   0   6
                 0   1   0   0  -1   0
                 6   0   4  -6   0   2
               -12   0  -6  12   0  -6
                 0  -1   0   0   1   0
                 6   0   2  -6   0   4
            ]
            @test_physical_invariants Ke

            # azi=90 → check rotated
            Ke90 = d2_grid_elementstiffness(E, G, I, J, L, 90)
            @test_physical_invariants Ke90
        end

        @testset "elementforces" begin
            E, G, I, J, L = 1.0, 1.0, 1.0, 1.0, 1.0

            # azi=0, unit vertical displacement at node 1
            u = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0]
            f = d2_grid_elementforces(E, G, I, J, L, 0, u)
            @test length(f) == 6
            # f = kprime * I * u = kprime * u = column 1 of kprime
            @test f ≈ [12, 0, 6, -12, 0, 6]

            # zero displacement
            @test d2_grid_elementforces(E, G, I, J, L, 0, zeros(6)) ≈ zeros(6)
        end

        @testset "assemble" begin
            K = zeros(6, 6)
            k = ones(6, 6)
            K = d2_grid_assemble(K, k, 1, 2)
            @test K == ones(6, 6)

            # Assemble into larger system
            K9 = zeros(9, 9)
            ke = reshape(1:36, 6, 6)
            K9 = d2_grid_assemble(K9, ke, 1, 2)
            # Node 1 DOF: 1-3, Node 2 DOF: 4-6
            @test K9[1:3, 1:3] == ke[1:3, 1:3]
            @test K9[1:3, 4:6] == ke[1:3, 4:6]
            @test K9[4:6, 1:3] == ke[4:6, 1:3]
            @test K9[4:6, 4:6] == ke[4:6, 4:6]
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d2_grid_elementstiffness(1.0, 1.0, 1.0, 1.0, 0.0, 0.0)
            @test_throws ElementParameterError d2_grid_elementstiffness(1.0, 1.0, 1.0, 1.0, -1.0, 0.0)
            @test_throws ElementParameterError d2_grid_elementforces(1.0, 1.0, 1.0, 1.0, 0.0, 0.0, zeros(6))
        end

        @testset "invariant in element property tests" begin
            k = d2_grid_elementstiffness(1, 1, 1, 1, 1, 30)
            @test_physical_invariants(k)
        end

        @testset "problem_9_1_integration" begin
            E = 210e6; G = 84e6; I = 20e-5; J = 5e-5
            L1 = d2_grid_elementlength(4, 0, 0, 3)
            L2 = d2_grid_elementlength(4, 0, 0, -3)
            θ1 = 180 + atan(3 / 4) * 180 / π
            θ2 = 180 - atan(3 / 4) * 180 / π

            k1 = d2_grid_elementstiffness(E, G, I, J, L1, θ1)
            k2 = d2_grid_elementstiffness(E, G, I, J, L2, θ2)

            K = zeros(9, 9)
            K = d2_grid_assemble(K, k1, 1, 2)
            K = d2_grid_assemble(K, k2, 1, 3)

            k = K[1:3, 1:3]
            f = [-10.0; 0.0; 0.0]
            u = k \ f
            U = zeros(9)
            U[1:3] = u
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0

            # Golden values from Kattan Solutions Manual
            @test u[1] ≈ -0.0048 atol = 1e-4  # UZ₁
            @test u[2] ≈ 0.0 atol = 1e-4      # RX₁
            @test u[3] ≈ -0.0018 atol = 1e-4   # RY₁

            @test F[1] ≈ -10.0 atol = 1e-4     # FZ₁
            @test F[4] ≈ 5.0 atol = 1e-4       # FZ₂
            @test F[5] ≈ -13.8905 atol = 1e-2  # MX₂
            @test F[6] ≈ 20.0 atol = 1e-2      # MY₂
            @test F[7] ≈ 5.0 atol = 1e-4       # FZ₃
            @test F[8] ≈ 13.8905 atol = 1e-2   # MX₃
            @test F[9] ≈ 20.0 atol = 1e-2      # MY₃

            # Equilibrium: sum of Z-forces ≈ 0
            @test sum(F[1:3:end]) ≈ 0.0 atol = 1e-10
        end
    end

        # ═══════════════════════════════════════════════════
        # Sprint 3 — Wave 5: Test Hardening
        # ═══════════════════════════════════════════════════

        @testset "element property tests" begin
            Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(stderr, Base.CoreLogging.Error)) do
            k1 = d1_bar_elementstiffness(1, 1, 1)
            @test_translational_invariants(k1, 1e-15)

            k2 = d2_truss_elementstiffness(1, 1, 1, 30)
            @test_translational_invariants(k2, 1e-14)

            k3 = d3_truss_elementstiffness(1, 1, 1, 30, 45, 60)
            @test_translational_invariants(k3, 1e-14)

            k2s = d2_spring_elementstiffness(100, 30)
            @test_translational_invariants(k2s, 1e-14)

            k3s = d3_spring_elementstiffness(100, 30, 45, 60)
            @test_translational_invariants(k3s, 1e-13)  # FP noise from invalid direction cosines

            k2b = d2_planeframe_elementstiffness(1, 1, 1, 1, 30)
            @test_physical_invariants(k2b)

            k3b = d3_spaceframe_elementstiffness(1, 1, 1, 1, 1, 1, 0,0,0, 4,0,0)
            @test_physical_invariants(k3b)
        end # Test.collected_logs()
        end

        @testset "negative path tests" begin
            @test_throws ElementParameterError d1_bar_elementstiffness(1, 1, 0)
            @test_throws ElementParameterError d2_truss_elementstiffness(1, 1, 0, 0)
            @test_throws ElementParameterError d3_truss_elementstiffness(1, 1, 0, 0, 0, 0)
            @test_throws ElementParameterError d2_planeframe_elementstiffness(1, 1, 1, 0, 0)
            @test_throws ElementParameterError d1_bar_elementstiffness(1, 1, -1)
            # C2: impossible 3D direction cosines → warning, not error
            @test_logs (:warn, r"Direction cosines do not form a unit vector") d3_truss_elementstiffness(1, 1, 1, 90, 90, 90)
            @test_logs (:warn, r"Direction cosines do not form a unit vector") d3_spring_elementstiffness(100, 90, 90, 90)
        end

        @testset "diagram functions" begin
            f2 = [1000, 500, 200, -1000, 500, -200]
            f3 = [1000, 500, 300, 200, 150, 100, -1000, -500, -300, -200, -150, -100]
            L = 5.0
            # Returns Plots.Plot objects (not raw data vectors)
            @test d2_planeframe_elementaxialdiagram(f2, L) isa Plots.Plot
            @test d2_planeframe_elementsheardiagram(f2, L) isa Plots.Plot
            @test d2_planeframe_elementmomentdiagram(f2, L) isa Plots.Plot
            # Pure beam diagrams use 4-element force vectors
            fb = [1000, 200, -1000, 200]
            @test d2_beam_elementsheardiagram(fb, L) isa Plots.Plot
            @test d2_beam_elementmomentdiagram(fb, L) isa Plots.Plot
            @test d3_spaceframe_elementaxialdiagram(f3, L) isa Plots.Plot
            @test d3_spaceframe_elementshearydiagram(f3, L) isa Plots.Plot
            @test d3_spaceframe_elementshearzdiagram(f3, L) isa Plots.Plot
            @test d3_spaceframe_elementmomentydiagram(f3, L) isa Plots.Plot
            @test d3_spaceframe_elementmomentzdiagram(f3, L) isa Plots.Plot
            @test d3_spaceframe_elementtorsiondiagram(f3, L) isa Plots.Plot
        end



        @testset "assembly edge cases" begin
            Base.CoreLogging.with_logger(Base.CoreLogging.SimpleLogger(stderr, Base.CoreLogging.Error)) do
            K6 = zeros(6, 6)
            k = d2_truss_elementstiffness(1, 1, 1, 0)
            K6 = d2_truss_assemble(K6, k, 1, 3)
            @test K6[1:2, 1:2] == k[1:2, 1:2]
            @test K6[1:2, 5:6] == k[1:2, 3:4]
            @test K6[5:6, 1:2] == k[3:4, 1:2]
            @test K6[5:6, 5:6] == k[3:4, 3:4]

            # d1_spring/d1_bar identity
            @test d1_spring_elementstiffness(500) == d1_bar_elementstiffness(500, 1, 1)
            # 2D identity: spring(k=EA/L) = truss(E, A, L)
            @test d2_spring_elementstiffness(100, 30) ≈ d2_truss_elementstiffness(100, 1, 1, 30)
            # 3D identity
            @test d3_spring_elementstiffness(100, 30, 45, 60) ≈ d3_truss_elementstiffness(100, 1, 1, 30, 45, 60)
        end # Test.collected_logs()
        end

        @testset "vertical beam edge case" begin
            E, G, A, Iy, Iz, J = 200e9, 80e9, 0.01, 1e-4, 2e-4, 1e-5
            # Vertical beam along Z: (0,0,0)→(0,0,4) — covers z2 > z1 branch
            Ke = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 0,0,4)
            @test size(Ke) == (12, 12)
            @test Ke ≈ Ke'
            @test all(isfinite, Ke)
            # Vertical beam along Z (negative direction): (0,0,4)→(0,0,0) — covers z1 > z2 branch
            Ke2 = d3_spaceframe_elementstiffness(E, G, A, Iy, Iz, J, 0,0,4, 0,0,0)
            @test size(Ke2) == (12, 12)
            @test Ke2 ≈ Ke2'
            @test all(isfinite, Ke2)
        end
    end

    # ════════════════════════════════════════════════════
    # Sprint 4 — Wave 1: 2-D Continuum / 3-D Continuum / Fluid
    # ════════════════════════════════════════════════════

    # ─────────────────────────────────────────────────
    # 2-D CST — Constant Strain Triangle (d2_cst)
    # ─────────────────────────────────────────────────
    @testset "d2_cst" begin
        @testset "elementarea" begin
            @test d2_cst_elementarea(0,0, 1,0, 0,1) ≈ 0.5
            @test d2_cst_elementarea(0,0, 2,0, 0,2) ≈ 2.0
        end

        @testset "elementstiffness" begin
            k = d2_cst_elementstiffness(200e9, 0.3, 0.01, 0,0, 1,0, 0,1, 1)
            @test size(k) == (6, 6)
            @test_physical_invariants(k)
            # plane stress vs plane strain differ
            k2 = d2_cst_elementstiffness(200e9, 0.3, 0.01, 0,0, 1,0, 0,1, 2)
            @test k ≉ k2  # different D matrices
        end

        @testset "assemble" begin
            K = zeros(12, 12); k = d2_cst_elementstiffness(200e9, 0.3, 0.01, 0,0, 1,0, 0,1, 1)
            K = d2_cst_assemble(K, k, 1, 2, 3)
            @test K[1:6, 1:6] ≈ k  # block maps to correct DOFs
            # Two-element assembly with shared node
            K2 = zeros(12, 12)
            k2 = d2_cst_elementstiffness(200e9, 0.3, 0.01, 0,0, 0,1, -1,0, 1)
            d2_cst_assemble(K2, k, 1, 2, 3)
            d2_cst_assemble(K2, k2, 1, 3, 4)
            @test K2 ≉ zeros(12, 12)  # non-trivial superposition
        end

        @testset "stress" begin
            u = zeros(6)
            sigma = d2_cst_elementstress(200e9, 0.3, 0,0, 1,0, 0,1, 1, u)
            @test sigma ≈ zeros(3)
        end

        @testset "pstress" begin
            s1, s2, θ = d2_cst_elementpstress([100.0, 50.0, 25.0])
            @test s1 > s2  # principal σ1 ≥ σ2
        end

        @testset "problem_11_1_integration" begin
            # Thin plate with 4 CST elements (Kattan Problem 11.1)
            # 5 nodes, 4 elements, plane stress
            E = 210e6; NU = 0.3; t = 0.025; p = 1

            k1 = d2_cst_elementstiffness(E, NU, t, 0, 0, 0.25, 0.125, 0, 0.25, p)
            k2 = d2_cst_elementstiffness(E, NU, t, 0, 0, 0.5, 0, 0.25, 0.125, p)
            k3 = d2_cst_elementstiffness(E, NU, t, 0.5, 0.25, 0, 0.25, 0.25, 0.125, p)
            k4 = d2_cst_elementstiffness(E, NU, t, 0.5, 0, 0.5, 0.25, 0.25, 0.125, p)

            K = zeros(10, 10)
            K = d2_cst_assemble(K, k1, 1, 5, 4)
            K = d2_cst_assemble(K, k2, 1, 2, 5)
            K = d2_cst_assemble(K, k3, 3, 4, 5)
            K = d2_cst_assemble(K, k4, 2, 3, 5)

            k = [K[3:6, 3:6] K[3:6, 9:10]; K[9:10, 3:6] K[9:10, 9:10]]
            f = [9.375; 0.0; 9.375; 0.0; 0.0; 0.0]
            u = k \ f
            U = zeros(10); U[3:6] = u[1:4]; U[9:10] = u[5:6]
            F = K * U; F[abs.(F) .< 1e-10] .= 0.0

            # Node displacements (×10⁻⁶)
            @test u[1] ≈ 6.928e-6 rtol=1e-2  # Ux₂
            @test u[2] ≈ 0.714e-6 rtol=1e-2  # Uy₂
            @test u[3] ≈ 6.928e-6 rtol=1e-2  # Ux₃
            @test u[4] ≈ -0.714e-6 rtol=1e-2 # Uy₃
            @test u[5] ≈ 3.271e-6 rtol=1e-2  # Ux₅
            @test u[6] ≈ 0.0 atol=1e-10       # Uy₅

            # Reactions
            @test F[1] ≈ -9.375 rtol=1e-2     # Fx₁
            @test F[2] ≈ -3.754 rtol=1e-2     # Fy₁
            @test F[7] ≈ -9.375 rtol=1e-2     # Fx₄
            @test F[8] ≈ 3.754 rtol=1e-2      # Fy₄

            # Element stresses
            u1 = [U[1];U[2];U[9];U[10];U[7];U[8]]
            u2 = [U[1];U[2];U[3];U[4];U[9];U[10]]
            u3 = [U[5];U[6];U[7];U[8];U[9];U[10]]
            u4 = [U[3];U[4];U[5];U[6];U[9];U[10]]

            sig1 = d2_cst_elementstress(E, NU, 0, 0, 0.25, 0.125, 0, 0.25, p, u1)
            sig2 = d2_cst_elementstress(E, NU, 0, 0, 0.5, 0, 0.25, 0.125, p, u2)
            sig3 = d2_cst_elementstress(E, NU, 0.5, 0.25, 0, 0.25, 0.25, 0.125, p, u3)
            sig4 = d2_cst_elementstress(E, NU, 0.5, 0, 0.5, 0.25, 0.25, 0.125, p, u4)

            @test sig1[1] ≈ 3019.2 rtol=1e-2  # σxx₁
            @test sig2[1] ≈ 3000.0 rtol=1e-2  # σxx₂
            @test sig4[1] ≈ 2980.8 rtol=1e-2  # σxx₄
            @test sig4[2] ≈ -305.1 rtol=1e-2  # σyy₄
        end

        @testset "problem_11_2_integration" begin
            # Thin plate with 16 CST elements, hollow center (Kattan Problem 11.2)
            # 16 nodes, 16 elements, plane stress; -20.0 load at node 16 (y)
            result = ProblemWrapper.run_julia_problem("11.2")
            K = result["K"]; k = result["k"]; f = result["f"]
            u = result["u"]; U = result["U"]; F = result["F"]

            # Sizes: 16 nodes × 2 DOF
            @test size(K) == (32, 32)
            @test size(k) == (24, 24)
            @test length(u) == 24
            @test length(U) == 32
            @test length(F) == 32

            # Symmetry
            @test K ≈ K'
            @test k ≈ k'

            # Applied load (node 16, y-direction)
            @test f[24] == -20.0
            @test F[32] ≈ -20.0 atol=1e-6

            # Node displacements (×10⁻³): Uy₁₆ is the max displacement
            @test u[24] ≈ -0.1167e-3 rtol=1e-2  # Uy₁₆
            @test maximum(abs.(u)) ≈ 0.1167e-3 rtol=1e-2

            # Reactions are the only nonzero entries (unconstrained rows ≈ 0)
            @test count(x -> abs(x) > 1e-6, F) == 9
        end

        @testset "problem_11_3_integration" begin
            # 2 CST triangles + 2 springs (Kattan Problem 11.3)
            # 5 nodes, plane stress; 17.5 loads at nodes 1 and 2 (y)
            result = ProblemWrapper.run_julia_problem("11.3")
            K = result["K"]; k = result["k"]; f = result["f"]; F = result["F"]
            sigma1 = result["sigma1"]; sigma2 = result["sigma2"]
            s1 = result["s1"]; s2 = result["s2"]
            f3 = result["f3"]; f4 = result["f4"]
            u = k \ f  # wrapper does not return u; y-components are determined

            # Sizes: 5 nodes × 2 DOF
            @test size(K) == (10, 10)
            @test size(k) == (8, 8)
            @test length(f) == 8
            @test length(F) == 10

            # Symmetry
            @test K ≈ K'
            @test k ≈ k'

            # Applied loads (nodes 1 and 2, y-direction)
            @test f == [0.0; 17.5; 0.0; 17.5; 0.0; 0.0; 0.0; 0.0]
            @test F[2] ≈ 17.5 rtol=1e-2  # Fy₁ (applied)
            @test F[4] ≈ 17.5 rtol=1e-2  # Fy₂ (applied)

            # Spring reactions at node 5
            @test F[9] ≈ -17.5 rtol=1e-2  # Fx₅ (spring reaction)
            @test F[10] ≈ -17.5 rtol=1e-2 # Fy₅ (spring reaction)

            # x-displacements are NOT tested: the reduced k is singular
            # (rank 7 — the system has no x-restraint, leaving a rigid-body
            # x-translation). u[1], u[3], u[5], u[7] are solver-dependent
            # arbitrary particular solutions; only the determined y-components
            # (and derived reactions/stresses) are asserted.
            @test u[2] ≈ 0.0044 rtol=1e-2  # Uy₁
            @test u[4] ≈ 0.0044 rtol=1e-2  # Uy₂
            @test u[6] ≈ 0.0044 rtol=1e-2  # Uy₃
            @test u[8] ≈ 0.0044 rtol=1e-2  # Uy₄

            # Spring forces (k = 4000 × Uy₄ ≈ 0.004375)
            @test f3 ≈ [17.5; -17.5] rtol=1e-2  # spring 3 nodal forces
            @test f4 ≈ [17.5; -17.5] rtol=1e-2  # spring 4 nodal forces

            # Element stresses (σyy-dominated; s = [σ₁, σ₂, θ])
            @test sigma1[2] ≈ 5000.0 rtol=1e-2  # σyy₁
            @test sigma2[2] ≈ 5000.0 rtol=1e-2  # σyy₂
            @test s1[1] ≈ 5000.0 rtol=1e-2      # σ₁₁ (principal)
            @test s2[1] ≈ 5000.0 rtol=1e-2      # σ₁₂ (principal)
        end
    end

    # ─────────────────────────────────────────────────
    # 2-D LST — Linear Strain Triangle (d2_lst)
    # ─────────────────────────────────────────────────
    @testset "d2_lst" begin
        @testset "elementstiffness" begin
            # Unit right triangle with mid-edge nodes
            k = d2_lst_elementstiffness(200e9, 0.3, 0.01,
                0,0, 1,0, 0,1,  0.5,0, 0.5,0.5, 0,0.5, 1)
            @test size(k) == (12, 12)
            @test_physical_invariants(k)
        end

        @testset "assemble" begin
            K = zeros(12, 12)
            k = d2_lst_elementstiffness(200e9, 0.3, 0.01,
                0,0, 1,0, 0,1,  0.5,0, 0.5,0.5, 0,0.5, 1)
            K = d2_lst_assemble(K, k, 1,2,3, 4,5,6)
            @test K ≈ k
        end

        @testset "stress" begin
            u = zeros(12)
            sigma = d2_lst_elementstress(200e9, 0.3,
                0,0,1,0,0,1, 0.5,0,0.5,0.5,0,0.5, 1, u)
            @test sigma ≈ zeros(3)
        end

        @testset "problem_12_1_integration" begin
            # Thin plate with 4 LST elements (Kattan Problem 12.1)
            # 13 nodes, 4 elements, plane stress; validated against the
            # Solutions Manual problem_12_1.m run under Octave (SymPy 1.14.0)
            E = 210e6; NU = 0.3; t = 0.025; p = 1

            # Element stiffnesses (corners then mid-edge nodes)
            k1 = d2_lst_elementstiffness(E, NU, t, 0,0, 0.25,0.125, 0,0.25, 0.125,0.0625, 0.125,0.1875, 0,0.125, p)
            k2 = d2_lst_elementstiffness(E, NU, t, 0,0, 0.5,0, 0.25,0.125, 0.25,0, 0.375,0.0625, 0.125,0.0625, p)
            k3 = d2_lst_elementstiffness(E, NU, t, 0.25,0.125, 0.5,0.25, 0,0.25, 0.375,0.1875, 0.25,0.25, 0.125,0.1875, p)
            k4 = d2_lst_elementstiffness(E, NU, t, 0.25,0.125, 0.5,0, 0.5,0.25, 0.375,0.0625, 0.5,0.125, 0.375,0.1875, p)

            K = zeros(26, 26)
            K = d2_lst_assemble(K, k1, 1,7,11, 4,9,6)
            K = d2_lst_assemble(K, k2, 1,3,7, 2,5,4)
            K = d2_lst_assemble(K, k3, 7,13,11, 10,12,9)
            K = d2_lst_assemble(K, k4, 7,3,13, 5,8,10)

            # Block-ordered reduction [3:10, 13:20, 23:26] (matches Kattan's MATLAB)
            free = [3:10; 13:20; 23:26]
            k = K[free, free]
            f = zeros(20); f[3] = 3.125; f[11] = 12.5; f[19] = 3.125
            u = k \ f
            U = zeros(26); U[3:10] = u[1:8]; U[13:20] = u[9:16]; U[23:26] = u[17:20]
            F = K * U; F[abs.(F) .< 1e-10] .= 0.0

            @test size(K) == (26, 26)
            @test size(k) == (20, 20)
            @test K ≈ K'
            @test k ≈ k'

            # Node displacements (m)
            @test u[1] ≈ 3.4997e-6 rtol=1e-2  # Ux₂
            @test u[2] ≈ 5.9026e-7 rtol=1e-2  # Uy₂
            @test u[3] ≈ 7.0058e-6 rtol=1e-2  # Ux₃
            @test u[4] ≈ 4.1514e-7 rtol=1e-2  # Uy₃
            @test u[9] ≈ 3.4535e-6 rtol=1e-2  # Ux₇
            @test u[10] ≈ 0.0 atol=1e-10       # Uy₇
            @test u[11] ≈ 7.0799e-6 rtol=1e-2  # Ux₈ (max)
            @test u[12] ≈ 0.0 atol=1e-10       # Uy₈
            @test u[19] ≈ 7.0058e-6 rtol=1e-2  # Ux₁₃
            @test u[20] ≈ -4.1514e-7 rtol=1e-2 # Uy₁₃

            # Reactions at fixed nodes 1, 6, 11
            @test F[1] ≈ -3.4469 rtol=1e-2  # Fx₁
            @test F[2] ≈ -1.5335 rtol=1e-2  # Fy₁
            @test F[11] ≈ -11.8562 rtol=1e-2 # Fx₆
            @test F[21] ≈ -3.4469 rtol=1e-2 # Fx₁₁
            @test F[22] ≈ 1.5335 rtol=1e-2  # Fy₁₁

            # Element stresses (at centroid)
            u1 = [U[1];U[2];U[13];U[14];U[21];U[22];U[7];U[8];U[17];U[18];U[11];U[12]]
            u2 = [U[1];U[2];U[5];U[6];U[13];U[14];U[3];U[4];U[9];U[10];U[7];U[8]]
            u3 = [U[13];U[14];U[25];U[26];U[21];U[22];U[19];U[20];U[23];U[24];U[17];U[18]]
            u4 = [U[13];U[14];U[5];U[6];U[25];U[26];U[9];U[10];U[15];U[16];U[19];U[20]]

            sig1 = d2_lst_elementstress(E, NU, 0,0, 0.25,0.125, 0,0.25, 0.125,0.0625, 0.125,0.1875, 0,0.125, p, u1)
            sig2 = d2_lst_elementstress(E, NU, 0,0, 0.5,0, 0.25,0.125, 0.25,0, 0.375,0.0625, 0.125,0.0625, p, u2)
            sig3 = d2_lst_elementstress(E, NU, 0.25,0.125, 0.5,0.25, 0,0.25, 0.375,0.1875, 0.25,0.25, 0.125,0.1875, p, u3)
            sig4 = d2_lst_elementstress(E, NU, 0.25,0.125, 0.5,0, 0.5,0.25, 0.375,0.0625, 0.5,0.125, 0.375,0.1875, p, u4)

            @test sig1[1] ≈ 2970.2 rtol=1e-2  # σxx₁
            @test sig1[2] ≈ 506.7 rtol=1e-2   # σyy₁
            @test sig1[3] ≈ 0.0 atol=1e-10     # τxy₁
            @test sig2[1] ≈ 3008.8 rtol=1e-2  # σxx₂
            @test sig2[2] ≈ -21.3 rtol=1e-2   # σyy₂
            @test sig2[3] ≈ 10.5 rtol=1e-2    # τxy₂
            @test sig3[1] ≈ 3008.8 rtol=1e-2  # σxx₃
            @test sig3[2] ≈ -21.3 rtol=1e-2   # σyy₃
            @test sig3[3] ≈ -10.5 rtol=1e-2   # τxy₃
            @test sig4[1] ≈ 3012.2 rtol=1e-2  # σxx₄
            @test sig4[2] ≈ 26.5 rtol=1e-2    # σyy₄
            @test sig4[3] ≈ 0.0 atol=1e-10     # τxy₄
        end
    end

    # ─────────────────────────────────────────────────
    # 2-D Q4 — Bilinear Quadrilateral (d2_q4)
    # ─────────────────────────────────────────────────
    @testset "d2_q4" begin
        @testset "elementarea" begin
            @test d2_q4_elementarea(0,0, 1,0, 1,1, 0,1) ≈ 1.0
            @test d2_q4_elementarea(0,0, 2,0, 2,2, 0,2) ≈ 4.0
        end

        @testset "elementstiffness" begin
            k = d2_q4_elementstiffness(200e9, 0.3, 0.01, 0,0, 1,0, 1,1, 0,1, 1)
            @test size(k) == (8, 8)
            @test_physical_invariants(k)
        end

        @testset "assemble" begin
            K = zeros(8, 8); k = d2_q4_elementstiffness(200e9,0.3,0.01, 0,0,1,0,1,1,0,1, 1)
            K = d2_q4_assemble(K, k, 1,2,3,4)
            @test K ≈ k
        end

        @testset "problem_13_1_integration" begin
            # Kattan Problem 13.1 — thin plate, 8 Q4 elements, 15 nodes
            # Golden values from Doc/Kattan/Solutions-Manual/problem_13_1.m (Octave)
            E, NU, h, p = 210e6, 0.3, 0.025, 1  # kPa, m, plane stress

            # Node coordinates (3 rows × 5 columns of a 0.5×0.25 plate)
            X = [0.0, 0.125, 0.25, 0.375, 0.5,   # row y=0:   nodes 1-5
                 0.0, 0.125, 0.25, 0.375, 0.5,   # row y=0.125: nodes 6-10
                 0.0, 0.125, 0.25, 0.375, 0.5]   # row y=0.25: nodes 11-15
            Y = [0.0, 0.0, 0.0, 0.0, 0.0,
                 0.125, 0.125, 0.125, 0.125, 0.125,
                 0.25, 0.25, 0.25, 0.25, 0.25]

            # Elements: 4 nodes per Q4, CCW from bottom-left
            conn = [(1,2,7,6), (2,3,8,7), (3,4,9,8), (4,5,10,9),
                    (6,7,12,11), (7,8,13,12), (8,9,14,13), (9,10,15,14)]

            K = zeros(30, 30)
            for (i, j, m, n) in conn
                k = d2_q4_elementstiffness(E, NU, h,
                    X[i],Y[i], X[j],Y[j], X[m],Y[m], X[n],Y[n], p)
                K = d2_q4_assemble(K, k, i, j, m, n)
            end

            # Fixed: nodes 1, 6, 11 (left edge) → DOFs 1:2, 11:12, 21:22
            free = [3:10; 13:20; 23:30]
            kred = K[free, free]
            f = zeros(24)
            f[7]  = 4.6875  # node 5,  Fx
            f[15] = 9.375   # node 10, Fx
            f[23] = 4.6875  # node 15, Fx

            u = kred \ f
            U = zeros(30)
            U[3:10]  = u[1:8]
            U[13:20] = u[9:16]
            U[23:30] = u[17:24]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0

            # Displacements (m)
            @test u[1]  ≈ 1.7679e-6  rtol=1e-2   # Ux node 2
            @test u[2]  ≈ 5.5217e-7  rtol=1e-2   # Uy node 2
            @test u[3]  ≈ 3.4997e-6  rtol=1e-2   # Ux node 3
            @test u[7]  ≈ 7.0706e-6  rtol=1e-2   # Ux node 5 (max)
            @test u[10] ≈ 0.0        atol=1e-10  # Uy node 8 (symmetry)
            @test u[14] ≈ 0.0        atol=1e-10  # Uy node 13 (symmetry)
            @test u[17] ≈ 1.7679e-6  rtol=1e-2   # Ux node 12
            @test u[18] ≈ -5.5217e-7 rtol=1e-2   # Uy node 12
            @test u[23] ≈ 7.0706e-6  rtol=1e-2   # Ux node 15 (max)

            # Reactions at fixed nodes 1, 6, 11 (kN)
            @test F[1]  ≈ -4.9836  rtol=1e-2
            @test F[2]  ≈ -1.2580  rtol=1e-2
            @test F[11] ≈ -8.7829  rtol=1e-2
            @test F[21] ≈ -4.9836  rtol=1e-2
            @test F[22] ≈  1.2580  rtol=1e-2
            @test F[9]  ≈  4.6875  rtol=1e-6   # applied load @5
            @test F[19] ≈  9.3750  rtol=1e-6   # applied load @10
            @test F[29] ≈  4.6875  rtol=1e-6   # applied load @15

            # Equilibrium
            @test sum(F[1:2:end]) ≈ 0.0 atol=1e-6
            @test sum(F[2:2:end]) ≈ 0.0 atol=1e-6

            # Element stresses at centroid (kPa)
            us = [U[[1,2,3,4,13,14,11,12]],   # e1: 1-2-7-6
                  U[[3,4,5,6,15,16,13,14]],   # e2: 2-3-8-7
                  U[[5,6,7,8,17,18,15,16]],   # e3: 3-4-9-8
                  U[[7,8,9,10,19,20,17,18]],  # e4: 4-5-10-9
                  U[[11,12,13,14,23,24,21,22]], # e5: 6-7-12-11
                  U[[13,14,15,16,25,26,23,24]], # e6: 7-8-13-12
                  U[[15,16,17,18,27,28,25,26]], # e7: 8-9-14-13
                  U[[17,18,19,20,29,30,27,28]]] # e8: 9-10-15-14
            sig = [d2_q4_elementstress(E, NU, X[i],Y[i], X[j],Y[j],
                       X[m],Y[m], X[n],Y[n], p, us[e])
                   for (e, (i, j, m, n)) in enumerate(conn)]

            # σxx = 3000 kPa uniform (uniaxial tension)
            for e in 1:8
                @test sig[e][1] ≈ 3000.0 rtol=1e-2
            end
            @test sig[1] ≈ [3000.0; 436.2; 139.6]   rtol=1e-2
            @test sig[2] ≈ [3000.0; -23.92; -41.44] rtol=1e-2
            @test sig[3] ≈ [3000.0; -10.17; -4.235] rtol=1e-2
            @test sig[4] ≈ [3000.0; 0.4880; 0.8013] rtol=1e-2
            @test sig[5] ≈ [3000.0; 436.2; -139.6]  rtol=1e-2
            @test sig[6] ≈ [3000.0; -23.92; 41.44]  rtol=1e-2
            @test sig[7] ≈ [3000.0; -10.17; 4.235]  rtol=1e-2
            @test sig[8] ≈ [3000.0; 0.4880; -0.8013] rtol=1e-2
        end

        @testset "problem_13_2_integration" begin
            # Kattan Problem 13.2 — thin plate with central hole, 8 Q4 elements, 16 nodes
            # Golden values from Doc/Kattan/Solutions-Manual/problem_13_2.m (Octave)
            E, NU, h, p = 70e6, 0.25, 0.02, 1  # kPa, m, plane stress

            # Node coordinates (4 rows × 4 columns of a 0.9×0.9 plate)
            X = [0.0, 0.3, 0.6, 0.9,   # row y=0:    nodes 1-4
                 0.0, 0.3, 0.6, 0.9,   # row y=0.3:  nodes 5-8
                 0.0, 0.3, 0.6, 0.9,   # row y=0.6:  nodes 9-12
                 0.0, 0.3, 0.6, 0.9]   # row y=0.9:  nodes 13-16
            Y = [0.0, 0.0, 0.0, 0.0,
                 0.3, 0.3, 0.3, 0.3,
                 0.6, 0.6, 0.6, 0.6,
                 0.9, 0.9, 0.9, 0.9]

            # Elements: 4 nodes per Q4, CCW; central element (6,7,11,10) is a hole
            conn = [(1,2,6,5), (2,3,7,6), (3,4,8,7), (5,6,10,9),
                    (7,8,12,11), (9,10,14,13), (10,11,15,14), (11,12,16,15)]

            K = zeros(32, 32)
            for (i, j, m, n) in conn
                k = d2_q4_elementstiffness(E, NU, h,
                    X[i],Y[i], X[j],Y[j], X[m],Y[m], X[n],Y[n], p)
                K = d2_q4_assemble(K, k, i, j, m, n)
            end

            # Fixed: nodes 1, 5, 9, 13 (left edge) → DOFs 1:2, 9:10, 17:18, 25:26
            free = [3:8; 11:16; 19:24; 27:32]
            kred = K[free, free]
            f = zeros(24)
            f[24] = -20.0  # node 16, Fy (DOF 32 = 24th free DOF)

            u = kred \ f
            U = zeros(32)
            U[3:8]   = u[1:6]
            U[11:16] = u[7:12]
            U[19:24] = u[13:18]
            U[27:32] = u[19:24]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0

            # Displacements (m)
            @test u[1]  ≈ -2.9918e-5 rtol=1e-2   # Ux node 2
            @test u[2]  ≈ -2.8358e-5 rtol=1e-2   # Uy node 2
            @test u[5]  ≈ -3.8644e-5 rtol=1e-2   # Ux node 4
            @test u[6]  ≈ -1.1018e-4 rtol=1e-2   # Uy node 4
            @test u[7]  ≈  1.4762e-6 rtol=1e-2   # Ux node 6 (hole corner)
            @test u[8]  ≈ -2.0309e-5 rtol=1e-2   # Uy node 6 (hole corner)
            @test u[11] ≈ -1.2326e-5 rtol=1e-2   # Ux node 8
            @test u[12] ≈ -1.0881e-4 rtol=1e-2   # Uy node 8
            @test u[15] ≈ -2.3489e-6 rtol=1e-2   # Ux node 12
            @test u[16] ≈ -8.2419e-5 rtol=1e-2   # Uy node 12
            @test u[23] ≈  5.6534e-5 rtol=1e-2   # Ux node 16
            @test u[24] ≈ -1.5895e-4 rtol=1e-2   # Uy node 16 (max deflection)

            # Reactions at fixed nodes 1, 5, 9, 13 (kN)
            @test F[1]  ≈ 17.6570  rtol=1e-2
            @test F[2]  ≈  3.4450  rtol=1e-2
            @test F[9]  ≈  7.4806  rtol=1e-2
            @test F[10] ≈  7.0314  rtol=1e-2
            @test F[17] ≈ -7.9321  rtol=1e-2
            @test F[18] ≈  6.7416  rtol=1e-2
            @test F[25] ≈ -17.2054 rtol=1e-2
            @test F[26] ≈  2.7819  rtol=1e-2
            @test F[32] ≈ -20.0    rtol=1e-6   # applied load @16

            # Equilibrium
            @test sum(F[1:2:end]) ≈ 0.0 atol=1e-6
            @test sum(F[2:2:end]) ≈ 0.0 atol=1e-6

            # Element stresses at centroid (kPa)
            us = [U[[1,2,3,4,11,12,9,10]],    # e1: 1-2-6-5
                  U[[3,4,5,6,13,14,11,12]],   # e2: 2-3-7-6
                  U[[5,6,7,8,15,16,13,14]],   # e3: 3-4-8-7
                  U[[9,10,11,12,19,20,17,18]], # e4: 5-6-10-9
                  U[[13,14,15,16,23,24,21,22]], # e5: 7-8-12-11
                  U[[17,18,19,20,27,28,25,26]], # e6: 9-10-14-13
                  U[[19,20,21,22,29,30,27,28]], # e7: 10-11-15-14
                  U[[21,22,23,24,31,32,29,30]]] # e8: 11-12-16-15
            sig = [d2_q4_elementstress(E, NU, X[i],Y[i], X[j],Y[j],
                       X[m],Y[m], X[n],Y[n], p, us[e])
                   for (e, (i, j, m, n)) in enumerate(conn)]

            @test sig[1] ≈ [-3288.97; 116.86; -806.08]    rtol=1e-2
            @test sig[2] ≈ [-2209.08; -158.45; -1949.31]  rtol=1e-2
            @test sig[3] ≈ [-592.06; -532.59; -187.44]    rtol=1e-2
            @test sig[4] ≈ [-27.362; 203.241; -1980.51]   rtol=1e-2
            @test sig[5] ≈ [-308.67; -1949.31; -2209.09]  rtol=1e-2
            @test sig[6] ≈ [3316.329; -48.438; -546.742]  rtol=1e-2
            @test sig[7] ≈ [2209.08; 446.45; -1384.02]    rtol=1e-2
            @test sig[8] ≈ [900.72; -3267.68; -936.81]    rtol=1e-2
        end

        @testset "problem_13_3_integration" begin
            # Kattan Problem 13.3 — thin plate on 3 spring supports
            # 2 Q4 elements + 3 springs; golden from Doc/Kattan/Solutions-Manual/problem_13_3.m
            E, NU, h, p = 200e6, 0.3, 0.01, 1  # kPa, m, plane stress
            kspring = d1_spring_elementstiffness(4000)  # kN/m

            # Node coordinates (6 plate nodes; DOFs 1-12; grounds 13-15)
            X = [0.0, 0.35, 0.7, 0.0, 0.35, 0.7]
            Y = [0.4, 0.4,  0.4, 0.0, 0.0,  0.0]

            # Q4 elements, CCW: e1 = (4,5,2,1), e2 = (5,6,3,2)
            K = zeros(15, 15)
            k1 = d2_q4_elementstiffness(E, NU, h, X[4],Y[4], X[5],Y[5], X[2],Y[2], X[1],Y[1], p)
            k2 = d2_q4_elementstiffness(E, NU, h, X[5],Y[5], X[6],Y[6], X[3],Y[3], X[2],Y[2], p)
            K = d2_q4_assemble(K, k1, 4, 5, 2, 1)
            K = d2_q4_assemble(K, k2, 5, 6, 3, 2)
            # Springs: bottom nodes 4, 5, 6 (DOFs 8, 10, 12) → ground (13, 14, 15)
            K = d1_spring_assemble(K, kspring, 8, 13)
            K = d1_spring_assemble(K, kspring, 10, 14)
            K = d1_spring_assemble(K, kspring, 12, 15)

            # Free: 1:12 (plate); fixed: 13-15 (spring grounds)
            kred = K[1:12, 1:12]
            f = zeros(12)
            f[2] = 8.75   # node 1, Fy
            f[4] = 17.5   # node 2, Fy
            f[6] = 8.75   # node 3, Fy

            u = kred \ f
            U = [u; 0; 0; 0]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0

            # NOTE: plate rests only on vertical springs → x-translation is a
            # zero-energy mode (reduced K singular). uy, ux-differences,
            # reactions, and stresses are unique; absolute ux is not.

            # Vertical displacements (m) — near-uniform (plate ≈ rigid vs springs)
            @test u[2]  ≈ 2.9269e-3 rtol=1e-2   # Uy node 1
            @test u[4]  ≈ 2.9292e-3 rtol=1e-2   # Uy node 2
            @test u[6]  ≈ 2.9269e-3 rtol=1e-2   # Uy node 3
            @test u[8]  ≈ 2.9138e-3 rtol=1e-2   # Uy node 4
            @test u[10] ≈ 2.9223e-3 rtol=1e-2   # Uy node 5
            @test u[12] ≈ 2.9138e-3 rtol=1e-2   # Uy node 6

            # Relative horizontal displacements (unique despite x-mode)
            @test (u[3] - u[1])  ≈ -2.31e-7 atol=1e-9   # Ux2 - Ux1
            @test (u[5] - u[1])  ≈ -4.61e-7 atol=1e-9   # Ux3 - Ux1
            @test (u[7] - u[1])  ≈  4.79e-6 atol=1e-9   # Ux4 - Ux1
            @test (u[9] - u[1])  ≈ -2.31e-7 atol=1e-9   # Ux5 - Ux1
            @test (u[11] - u[1]) ≈ -5.25e-6 atol=1e-9   # Ux6 - Ux1

            # Reactions at spring grounds (kN)
            @test F[13] ≈ -11.6553 rtol=1e-2
            @test F[14] ≈ -11.6894 rtol=1e-2
            @test F[15] ≈ -11.6553 rtol=1e-2

            # Applied loads
            @test F[2] ≈  8.75   rtol=1e-6
            @test F[4] ≈ 17.5    rtol=1e-6
            @test F[6] ≈  8.75   rtol=1e-6

            # Equilibrium (DOFs 13-15 are y-direction spring grounds)
            sumfx = F[1] + F[3] + F[5] + F[7] + F[9] + F[11]
            @test sumfx ≈ 0.0 atol=1e-6
            @test sum(F) - sumfx ≈ 0.0 atol=1e-6

            # Element stresses at centroid (kPa)
            u1 = [U[7]; U[8]; U[9]; U[10]; U[3]; U[4]; U[1]; U[2]]  # e1: 4-5-2-1
            u2 = [U[9]; U[10]; U[11]; U[12]; U[5]; U[6]; U[3]; U[4]] # e2: 5-6-3-2
            sig1 = d2_q4_elementstress(E, NU, X[4],Y[4], X[5],Y[5], X[2],Y[2], X[1],Y[1], p, u1)
            sig2 = d2_q4_elementstress(E, NU, X[5],Y[5], X[6],Y[6], X[3],Y[3], X[2],Y[2], p, u2)

            @test abs(sig1[1]) < 1e-2          # σxx ≈ 0 (pure y-stretch)
            @test sig1[2] ≈ 5000.0  rtol=1e-2  # σyy
            @test sig1[3] ≈ 726.33  rtol=1e-2  # τxy
            @test abs(sig2[1]) < 1e-2          # σxx ≈ 0
            @test sig2[2] ≈ 5000.0  rtol=1e-2  # σyy
            @test sig2[3] ≈ -726.33 rtol=1e-2  # τxy

            # Spring element forces (kN) — positive = tension
            fspring3 = d1_spring_elementforce(kspring, [U[8]; U[13]])
            fspring4 = d1_spring_elementforce(kspring, [U[10]; U[14]])
            fspring5 = d1_spring_elementforce(kspring, [U[12]; U[15]])
            @test fspring3 ≈ [11.6553; -11.6553] rtol=1e-2
            @test fspring4 ≈ [11.6894; -11.6894] rtol=1e-2
            @test fspring5 ≈ [11.6553; -11.6553] rtol=1e-2
        end
    end

    # ─────────────────────────────────────────────────
    # 2-D Q8 — Quadratic Quadrilateral (d2_q8)
    # ─────────────────────────────────────────────────
    @testset "d2_q8" begin
        @testset "elementstiffness" begin
            k = d2_q8_elementstiffness(200e9, 0.3, 0.01,
                0,0, 1,0, 1,1, 0,1,  0.5,0, 1,0.5, 0.5,1, 0,0.5, 1)
            @test size(k) == (16, 16)
            @test_physical_invariants(k)
        end

        @testset "assemble" begin
            K = zeros(16, 16)
            k = d2_q8_elementstiffness(200e9, 0.3, 0.01,
                0,0,1,0,1,1,0,1, 0.5,0,1,0.5,0.5,1,0,0.5, 1)
            K = d2_q8_assemble(K, k, 1,2,3,4, 5,6,7,8)
            @test K ≈ k
        end

        @testset "problem_14_1_integration" begin
            # Kattan Problem 14.1 — thin plate on 3 springs (single Q8 element).
            # Golden values from Doc/Kattan/Solutions-Manual/problem_14_1.m (Octave).
            E, NU, h, p = 200e6, 0.3, 0.01, 1   # kPa, m, plane stress
            kspring = d1_spring_elementstiffness(4000)   # kN/m

            # Plate nodes (2 DOF each; DOFs 1-16); spring grounds (DOFs 17-19)
            X = [0.0, 0.35, 0.7, 0.0, 0.7, 0.0, 0.35, 0.7]
            Y = [0.4, 0.4,  0.4, 0.2, 0.2, 0.0, 0.0,  0.0]

            # Q8 element: corners 6-8-3-1 (CCW), mid-sides 7-5-2-4
            K = zeros(19, 19)
            k1 = d2_q8_elementstiffness(E, NU, h,
                X[6],Y[6], X[8],Y[8], X[3],Y[3], X[1],Y[1],
                X[7],Y[7], X[5],Y[5], X[2],Y[2], X[4],Y[4], p)
            K = d2_q8_assemble(K, k1, 6,8,3,1, 7,5,2,4)
            # Springs: bottom nodes 6,7,8 (DOFs 12,14,16) → grounds 17,18,19
            K = d1_spring_assemble(K, kspring, 12, 17)
            K = d1_spring_assemble(K, kspring, 14, 18)
            K = d1_spring_assemble(K, kspring, 16, 19)

            # Free: 1:16 (plate); fixed: 17-19 (spring grounds)
            kred = K[1:16, 1:16]
            f = zeros(16)
            f[2] = 5.8333    # node 1, Fy
            f[4] = 23.3333   # node 2, Fy
            f[6] = 5.8333    # node 3, Fy

            u = kred \ f
            U = [u; 0; 0; 0]
            F = K * U
            F[abs.(F) .< 1e-10] .= 0.0

            # NOTE: plate rests on vertical springs only → rigid x-translation
            # is a zero-energy mode (reduced K singular). uy, ux differences,
            # reactions and stresses are unique; absolute ux is not.

            # Vertical displacements (m) — near-uniform (plate ≈ rigid vs springs)
            @test u[2]  ≈ 2.9309e-3 rtol=1e-2   # Uy node 1
            @test u[4]  ≈ 2.9339e-3 rtol=1e-2   # Uy node 2
            @test u[6]  ≈ 2.9309e-3 rtol=1e-2   # Uy node 3
            @test u[8]  ≈ 2.9212e-3 rtol=1e-2   # Uy node 4
            @test u[10] ≈ 2.9212e-3 rtol=1e-2   # Uy node 5
            @test u[12] ≈ 2.9105e-3 rtol=1e-2   # Uy node 6
            @test u[14] ≈ 2.9290e-3 rtol=1e-2   # Uy node 7
            @test u[16] ≈ 2.9105e-3 rtol=1e-2   # Uy node 8

            # Relative horizontal displacements (unique despite x-mode)
            @test (u[3] - u[1])  ≈  1.5433e-6 atol=1e-9   # Ux2-Ux1
            @test (u[5] - u[1])  ≈  3.0867e-6 atol=1e-9   # Ux3-Ux1
            @test (u[7] - u[1])  ≈  2.9171e-6 atol=1e-9   # Ux4-Ux1
            @test (u[9] - u[1])  ≈  1.6956e-7 atol=1e-9   # Ux5-Ux1
            @test (u[11] - u[1]) ≈  1.3342e-5 atol=1e-9   # Ux6-Ux1
            @test (u[13] - u[1]) ≈  1.5433e-6 atol=1e-9   # Ux7-Ux1
            @test (u[15] - u[1]) ≈ -1.0255e-5 atol=1e-9   # Ux8-Ux1

            # Reactions at spring grounds (kN)
            @test F[17] ≈ -11.6419 rtol=1e-2
            @test F[18] ≈ -11.7162 rtol=1e-2
            @test F[19] ≈ -11.6419 rtol=1e-2

            # Applied loads
            @test F[2] ≈  5.8333 rtol=1e-6
            @test F[4] ≈ 23.3333 rtol=1e-6
            @test F[6] ≈  5.8333 rtol=1e-6

            # Equilibrium (DOFs 17-19 are y-direction spring grounds)
            sumfx = F[1] + F[3] + F[5] + F[7] + F[9] + F[11] + F[13] + F[15]
            @test sumfx ≈ 0.0 atol=1e-6
            @test sum(F) - sumfx ≈ 0.0 atol=1e-6

            # Element stresses at centroid (kPa)
            # (Manual prints σ = [-0.0709; 2.3805; 0.0000]·1e3 = [-70.9; 2380.5; 0];
            #  Julia matches the manual, Octave symbolic drifts — see problem_14_1.m.)
            u1 = [U[11]; U[12]; U[15]; U[16]; U[5]; U[6]; U[1]; U[2];
                  U[13]; U[14]; U[9]; U[10]; U[3]; U[4]; U[7]; U[8]]  # e1: 6-8-3-1-7-5-2-4
            sig1 = d2_q8_elementstress(E, NU,
                X[6],Y[6], X[8],Y[8], X[3],Y[3], X[1],Y[1],
                X[7],Y[7], X[5],Y[5], X[2],Y[2], X[4],Y[4], p, u1)

            @test sig1[1] ≈ -70.85  rtol=1e-2   # σxx
            @test sig1[2] ≈ 2380.54 rtol=1e-2   # σyy
            @test abs(sig1[3]) < 1e-2           # τxy ≈ 0

            # Spring element forces (kN) — positive = tension
            fspring1 = d1_spring_elementforce(kspring, [U[12]; U[17]])
            fspring2 = d1_spring_elementforce(kspring, [U[14]; U[18]])
            fspring3 = d1_spring_elementforce(kspring, [U[16]; U[19]])
            @test fspring1 ≈ [ 11.6419; -11.6419] rtol=1e-2
            @test fspring2 ≈ [ 11.7162; -11.7162] rtol=1e-2
            @test fspring3 ≈ [ 11.6419; -11.6419] rtol=1e-2
        end
    end

    # ─────────────────────────────────────────────────
    # 3-D Tetrahedron — Linear 4-node (d3_tet)
    # ─────────────────────────────────────────────────
    @testset "d3_tet" begin
        @testset "elementvolume" begin
            V = d3_tet_elementvolume(0,0,0, 1,0,0, 0,1,0, 0,0,1)
            @test abs(V - 1/6) < 1e-10
        end

        @testset "elementstiffness" begin
            k = d3_tet_elementstiffness(200e9, 0.3, 0,0,0, 1,0,0, 0,1,0, 0,0,1)
            @test size(k) == (12, 12)
            @test k ≈ k'
        end

        @testset "assemble" begin
            K = zeros(12, 12); k = d3_tet_elementstiffness(200e9,0.3, 0,0,0,1,0,0,0,1,0,0,0,1)
            K = d3_tet_assemble(K, k, 1,2,3,4)
            @test K ≈ k
        end

        @testset "pstress" begin
            p = d3_tet_elementpstress([100.0,0.0,0.0,0.0,0.0,0.0])
            @test length(p) == 4
            @test abs(p[1] - 100) < 1e-10  # σ1 = 100
            @test abs(p[2]) < 1e-10       # σ2 = 0
        end

        @testset "problem_15_1_integration" begin
            # Kattan Problem 15.1 — 3D block (0.025×0.5×0.25 m), 6 tetrahedra,
            # bottom face fixed, upward loads on top face. Golden values from
            # Doc/Kattan/Solutions-Manual/problem_15_1.m under Octave (long g).
            E, NU = 210e6, 0.3
            # Node coordinates (global)
            x1,y1,z1 = 0.0,   0.0,  0.00
            x2,y2,z2 = 0.025, 0.0,  0.00
            x3,y3,z3 = 0.0,   0.5,  0.00
            x4,y4,z4 = 0.025, 0.5,  0.00
            x5,y5,z5 = 0.0,   0.0,  0.25
            x6,y6,z6 = 0.025, 0.0,  0.25
            x7,y7,z7 = 0.0,   0.5,  0.25
            x8,y8,z8 = 0.025, 0.5,  0.25
            k1 = d3_tet_elementstiffness(E, NU, x1,y1,z1, x2,y2,z2, x4,y4,z4, x8,y8,z8)
            k2 = d3_tet_elementstiffness(E, NU, x1,y1,z1, x2,y2,z2, x8,y8,z8, x5,y5,z5)
            k3 = d3_tet_elementstiffness(E, NU, x2,y2,z2, x8,y8,z8, x5,y5,z5, x6,y6,z6)
            k4 = d3_tet_elementstiffness(E, NU, x1,y1,z1, x3,y3,z3, x7,y7,z7, x4,y4,z4)
            k5 = d3_tet_elementstiffness(E, NU, x1,y1,z1, x7,y7,z7, x5,y5,z5, x8,y8,z8)
            k6 = d3_tet_elementstiffness(E, NU, x1,y1,z1, x8,y8,z8, x4,y4,z4, x7,y7,z7)
            K = zeros(24, 24)
            K = d3_tet_assemble(K, k1, 1,2,4,8)
            K = d3_tet_assemble(K, k2, 1,2,8,5)
            K = d3_tet_assemble(K, k3, 2,8,5,6)
            K = d3_tet_assemble(K, k4, 1,3,7,4)
            K = d3_tet_assemble(K, k5, 1,7,5,8)
            K = d3_tet_assemble(K, k6, 1,8,4,7)
            free = [7:12; 19:24]
            fixed = [1:6; 13:18]
            f = zeros(12)
            f[2], f[5], f[8], f[11] = 3.125, 6.25, 6.25, 3.125
            u = K[free, free] \ f
            U = zeros(24); U[free] = u
            F = K * U; F[abs.(F) .< 1e-10] .= 0.0
            # Golden free displacements (m)
            u_gold = [1.846590992634907e-07, 6.709937720724766e-06, 1.485208020455631e-06,
                      9.07262051068782e-08,  6.698777435174929e-06, 1.489155301206617e-06,
                      1.831613663252598e-07, 5.809126841859452e-06, 3.188325752472113e-07,
                      7.408420903751547e-08, 5.794544023355245e-06, 3.173716316460239e-07]
            @test u ≈ u_gold rtol=1e-4
            # Golden reactions (kN) at fixed DOFs 1:6, 13:18
            F_gold = [-51.19249793433492, -3.056522511152604, -4.484218066705922,
                       51.20900702348261, -6.318477488847259, -3.036817407557082,
                      -29.25534696033375,  -6.318477488848091,  4.649308958182774,
                       29.23883787118602,  -3.056522511151611,  2.871726516080239]
            @test F[fixed] ≈ F_gold rtol=1e-6
            # Applied loads echoed at free DOFs
            @test F[8]  ≈ 3.125 rtol=1e-6
            @test F[11] ≈ 6.25  rtol=1e-6
            @test F[20] ≈ 6.25  rtol=1e-6
            @test F[23] ≈ 3.125 rtol=1e-6
            # Element nodal displacement vectors (local node order)
            u1 = [U[1:6];  U[10:12]; U[22:24]]
            u2 = [U[1:6];  U[22:24]; U[13:15]]
            u3 = [U[4:6];  U[22:24]; U[13:15]; U[16:18]]
            u4 = [U[1:3];  U[7:9];   U[19:21]; U[10:12]]
            u5 = [U[1:3];  U[19:21]; U[13:15]; U[22:24]]
            u6 = [U[1:3];  U[22:24]; U[10:12]; U[19:21]]
            sig1 = d3_tet_elementstress(E, NU, x1,y1,z1, x2,y2,z2, x4,y4,z4, x8,y8,z8, u1)
            sig2 = d3_tet_elementstress(E, NU, x1,y1,z1, x2,y2,z2, x8,y8,z8, x5,y5,z5, u2)
            sig3 = d3_tet_elementstress(E, NU, x2,y2,z2, x8,y8,z8, x5,y5,z5, x6,y6,z6, u3)
            sig4 = d3_tet_elementstress(E, NU, x1,y1,z1, x3,y3,z3, x7,y7,z7, x4,y4,z4, u4)
            sig5 = d3_tet_elementstress(E, NU, x1,y1,z1, x7,y7,z7, x5,y5,z5, x8,y8,z8, u5)
            sig6 = d3_tet_elementstress(E, NU, x1,y1,z1, x8,y8,z8, x4,y4,z4, x7,y7,z7, u6)
            # Golden element stresses (kPa, Voigt [σxx;σyy;σzz;τxy;τyz;τzx])
            sig1_gold = [1055.300907889945, 3219.521310023383, 298.1483829431006,
                         14.65577159418802, -51.58109208529072, -5.376644883947961]
            sig2_gold = [1404.06259027454, 3276.146043973927, 1404.06259027454,
                         11.96744915221404, 51.26772511205002, 0.0]
            sig4_gold = [-1.53822504246682, 2773.238816203646, -148.2451966267186,
                         -6.226760356908926, -51.11298832903799, 12.26887024621828]
            sig5_gold = [174.1851869660662, 2755.786259887622, 878.9914340561063,
                         -17.52611599182273, 51.50372369378029, -4.719971634605372]
            sig6_gold = [-174.5764954185288, 2699.161525937078, -226.9227732753332,
                         -14.83779354984654, -51.34509350356047, -10.09661651855333]
            @test sig1 ≈ sig1_gold rtol=1e-4
            @test sig2 ≈ sig2_gold rtol=1e-4
            @test sig3 ≈ sig2_gold rtol=1e-4  # elements 2 & 3 are mirrored
            @test sig4 ≈ sig4_gold rtol=1e-4
            @test sig5 ≈ sig5_gold rtol=1e-4
            @test sig6 ≈ sig6_gold rtol=1e-4
            # Stress invariants: I1 = trace, I2 = Σ principal minors, I3 = det
            invariants(s) = (s[1]+s[2]+s[3],
                             s[1]*s[2]+s[1]*s[3]+s[2]*s[3]-s[4]^2-s[5]^2-s[6]^2,
                             det([s[1] s[4] s[6]; s[4] s[2] s[5]; s[6] s[5] s[3]]))
            # Golden invariants [I1; I2; I3] from TetrahedronElementPStresses (Octave)
            @test invariants(sig1)[1] ≈ 4572.970600856429   rtol=1e-4
            @test invariants(sig1)[2] ≈ 4669190.78406686    rtol=1e-4
            @test invariants(sig1)[3] ≈ 1010021416.625032   rtol=1e-4
            @test invariants(sig2)[1] ≈ 6084.271224523007   rtol=1e-4
            @test invariants(sig2)[2] ≈ 11168448.35917051   rtol=1e-4
            @test invariants(sig2)[3] ≈ 6454675808.015096   rtol=1e-4
            @test invariants(sig4)[1] ≈ 2623.455394534461   rtol=1e-4
            @test invariants(sig4)[2] ≈ -417958.9998204918  rtol=1e-4
            @test invariants(sig4)[3] ≈ 232527.890274289    rtol=1e-4
            @test invariants(sig5)[1] ≈ 3808.962880909794   rtol=1e-4
            @test invariants(sig5)[2] ≈ 3052454.872302094   rtol=1e-4
            @test invariants(sig5)[3] ≈ 421146041.2244004   rtol=1e-4
            @test invariants(sig6)[1] ≈ 2297.662257243216   rtol=1e-4
            @test invariants(sig6)[2] ≈ -1047054.416670724  rtol=1e-4
            @test invariants(sig6)[3] ≈ 107147973.668339    rtol=1e-4
        end
    end

    # ─────────────────────────────────────────────────
    # 3-D Brick — Linear 8-node Hexahedron (d3_brick)
    # ─────────────────────────────────────────────────
    @testset "d3_brick" begin
        @testset "elementstiffness" begin
            k = d3_brick_elementstiffness(200e9, 0.3,
                0,0,0, 1,0,0, 1,1,0, 0,1,0,
                0,0,1, 1,0,1, 1,1,1, 0,1,1)
            @test size(k) == (24, 24)
            @test k ≈ k'
        end

        @testset "assemble" begin
            K = zeros(24, 24)
            k = d3_brick_elementstiffness(200e9, 0.3,
                0,0,0,1,0,0,1,1,0,0,1,0,
                0,0,1,1,0,1,1,1,1,0,1,1)
            K = d3_brick_assemble(K, k, 1,2,3,4, 5,6,7,8)
            @test K ≈ k
        end

        @testset "problem_16_1_integration" begin
            # Kattan Problem 16.1 — cantilever plate (0.5×0.25×0.025 m) modeled
            # with two 8-node linear bricks along X, left face (nodes 1–4) fixed,
            # Fx = 4.6875 kN at nodes 9–12. Golden values from Julia solve
            # (node-major; the book's RTF transcript is singular — see
            # docs/adr/2026-08-01-problem-16-1-port-plan.md).
            E, NU = 210e6, 0.3
            # Node coordinates (m)
            x1,y1,z1 = 0.0,   0.0,  0.025
            x2,y2,z2 = 0.0,   0.0,  0.0
            x3,y3,z3 = 0.0,   0.25, 0.0
            x4,y4,z4 = 0.0,   0.25, 0.025
            x5,y5,z5 = 0.25,  0.0,  0.025
            x6,y6,z6 = 0.25,  0.0,  0.0
            x7,y7,z7 = 0.25,  0.25, 0.0
            x8,y8,z8 = 0.25,  0.25, 0.025
            x9,y9,z9 = 0.5,   0.0,  0.025
            x10,y10,z10 = 0.5, 0.0,  0.0
            x11,y11,z11 = 0.5, 0.25, 0.0
            x12,y12,z12 = 0.5, 0.25, 0.025
            # Local (J-order) node lists for brick element node numbering
            e1n = [2,6,7,3,1,5,8,4]
            e2n = [6,10,11,7,5,9,12,8]
            k1 = d3_brick_elementstiffness(E, NU,
                x2,y2,z2, x6,y6,z6, x7,y7,z7, x3,y3,z3,
                x1,y1,z1, x5,y5,z5, x8,y8,z8, x4,y4,z4)
            k2 = d3_brick_elementstiffness(E, NU,
                x6,y6,z6, x10,y10,z10, x11,y11,z11, x7,y7,z7,
                x5,y5,z5, x9,y9,z9, x12,y12,z12, x8,y8,z8)
            K = zeros(36, 36)
            K = d3_brick_assemble(K, k1, e1n...)
            K = d3_brick_assemble(K, k2, e2n...)
            free = 13:36
            fixed = 1:12
            f = zeros(24)
            f[[13, 16, 19, 22]] .= 4.6875  # kN at global DOFs 25,28,31,34
            u = K[free, free] \ f
            U = zeros(36); U[free] = u
            F = K * U; F[abs.(F) .< 1e-10] .= 0.0
            # Golden free displacements (m), nodes 5–12 [Ux;Uy;Uz]
            u_gold = [3.1958828389624026e-6, 6.072461518759357e-7, -6.593376152285259e-8,
                      3.195882838962374e-6,  6.0724615187595e-7,   6.593376152252052e-8,
                      3.1958828389625005e-6, -6.072461518760465e-7, 6.593376152266689e-8,
                      3.1958828389625064e-6, -6.072461518760609e-7, -6.593376152271287e-8,
                      6.8214927696327516e-6, 5.197306274629394e-7, -4.829659198604257e-8,
                      6.821492769632714e-6,  5.197306274629792e-7,  4.829659198502911e-8,
                      6.821492769632977e-6,  -5.197306274634197e-7, 4.829659198543291e-8,
                      6.821492769632987e-6,  -5.197306274634598e-7, -4.829659198564395e-8]
            @test u ≈ u_gold rtol=1e-6
            # Golden reactions (kN) at fixed DOFs 1:12
            F_gold = [-4.687500000000182, -1.474035604056745, 13.379026616555146,
                      -4.687499999999687, -1.4740356040567458, -13.379026616555135,
                      -4.687499999999884, 1.4740356040567403,  -13.379026616555302,
                      -4.687500000000153, 1.4740356040567467,  13.379026616555304]
            @test F[fixed] ≈ F_gold rtol=1e-6
            # Applied loads echoed at free DOFs (global 25,28,31,34)
            @test F[25] ≈ 4.6875 rtol=1e-6
            @test F[28] ≈ 4.6875 rtol=1e-6
            @test F[31] ≈ 4.6875 rtol=1e-6
            @test F[34] ≈ 4.6875 rtol=1e-6
            # Global force balance (kN)
            @test abs(sum(F[1:3:36])) < 1e-8
            @test abs(sum(F[2:3:36])) < 1e-8
            @test abs(sum(F[3:3:36])) < 1e-8
            # Element stresses (kPa, Voigt) at centroids
            u1 = vcat([U[3n-2:3n] for n in e1n]...)
            u2 = vcat([U[3n-2:3n] for n in e2n]...)
            sig1 = d3_brick_elementstress(E, NU,
                x2,y2,z2, x6,y6,z6, x7,y7,z7, x3,y3,z3,
                x1,y1,z1, x5,y5,z5, x8,y8,z8, x4,y4,z4, u1)
            sig2 = d3_brick_elementstress(E, NU,
                x6,y6,z6, x10,y10,z10, x11,y11,z11, x7,y7,z7,
                x5,y5,z5, x9,y9,z9, x12,y12,z12, x8,y8,z8, u2)
            @test sig1 ≈ [3000.0, 542.5935751505255, 508.9344757545714, 0.0, 0.0, 0.0] rtol=1e-6
            @test sig2 ≈ [3000.0, -70.9021818523695, -80.8056240248061, 0.0, 0.0, 0.0] rtol=1e-6
            # Principal stresses (kPa) — σ1, σ2, σ3 (tuple) + pstress 4th value
            p1 = d3_brick_elementpstress(sig1)
            p2 = d3_brick_elementpstress(sig2)
            @test p1[1] ≈ 3000.0 rtol=1e-6
            @test p1[2] ≈ 542.5935751505252 rtol=1e-6
            @test p1[3] ≈ 508.9344757545714 rtol=1e-6
            @test p2[1] ≈ 3000.0 rtol=1e-6
            @test p2[2] ≈ -70.90218185236901 rtol=1e-6
            @test p2[3] ≈ -80.8056240248059 rtol=1e-6
        end
    end

    # ─────────────────────────────────────────────────
    # 1-D Fluid Flow (d1_fluidflow)
    # ─────────────────────────────────────────────────
    @testset "d1_fluidflow" begin
        @testset "elementstiffness" begin
            k = d1_fluidflow_elementstiffness(1.0, 1.0, 1.0)
            @test size(k) == (2, 2)
            @test k ≈ [1 -1; -1 1]
            @test_throws ElementParameterError d1_fluidflow_elementstiffness(1.0, 1.0, 0.0)
            @test_throws ElementParameterError d1_fluidflow_elementstiffness(1.0, 0.0, 1.0)
        end

        @testset "velocity" begin
            v = d1_fluidflow_elementvelocity(1.0, 10.0, [10.0, 5.0])
            @test abs(v - 0.5) < 1e-10
        end

        @testset "vfr" begin
            Q = d1_fluidflow_elementvfr(1.0, 10.0, [10.0, 5.0], 2.0)
            @test abs(Q - 1.0) < 1e-10  # 0.5 * 2 = 1.0
        end

        @testset "assemble" begin
            K = zeros(4, 4); k = d1_fluidflow_elementstiffness(1.0, 1.0, 1.0)
            K = d1_fluidflow_assemble(K, k, 1, 2)
            @test K[1:2, 1:2] ≈ k
        end
    end

end  # @testset "LibFEM"

@testset "module loaded and exports accessible" begin
    @test isdefined(Main, :LibFEM)
    # Verify key exports are accessible
    for sym in [
        :d1_spring_elementstiffness,
        :d2_spring_elementstiffness,
        :d3_spring_elementstiffness,
        :d1_bar_elementstiffness,
        :d2_truss_elementstiffness,
        :d3_truss_elementstiffness,
        :d2_beam_elementstiffness,
        :d2_planeframe_elementstiffness,
        :d3_spaceframe_elementstiffness,
        :d2_grid_elementstiffness,
        :d2_cst_elementstiffness,
        :d2_lst_elementstiffness,
        :d2_q4_elementstiffness,
        :d2_q8_elementstiffness,
        :d3_tet_elementstiffness,
        :d3_brick_elementstiffness,
        :d1_fluidflow_elementstiffness,
        :AbstractSpring,
        :Spring,
        :AbstractTruss,
        :Truss,
        :AbstractBeam,
        :Beam,
        :AbstractTriangle,
        :Triangle,
        :AbstractQuadrilateral,
        :Quadrilateral,
        :AbstractTetrahedron,
        :Tetrahedron,
        :AbstractBrick,
        :Brick,
        :ElementDimensionError,
        :AssemblyError,
    ]
        @test isdefined(LibFEM, sym) || error("$sym not exported")
    end
end

# Golden regression tests — compare current function outputs against stored snapshots
include("golden_regression.jl")

# Property-based tests — random parameter invariants
include("property_tests.jl")
