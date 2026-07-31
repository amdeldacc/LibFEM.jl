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
