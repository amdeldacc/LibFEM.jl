using LibFEM
using Plots
using Test

@testset "LibFEM" begin

    # ─────────────────────────────────────────────────
    # Helper: deg2rad (module-internal, use qualified)
    # ─────────────────────────────────────────────────
    @testset "deg2rad helper" begin
        @test LibFEM.deg2rad(0) == 0.0
        @test LibFEM.deg2rad(180) ≈ π
        @test LibFEM.deg2rad(90) ≈ π / 2
        @test LibFEM.deg2rad(360) ≈ 2π
        @test LibFEM.deg2rad(45) ≈ π / 4
        @test LibFEM.deg2rad(-180) ≈ -π
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
            # zero stiffness → zero matrix
            @test d1_spring_elementstiffness(0) == zeros(2, 2)
            # symmetric
            @test Ke == Ke'
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
            @test d1_spring_elementforce(Ke, u_rb) ≈ [0.0; 0.0]
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
    end

    # ─────────────────────────────────────────────────
    # 1-D Truss / Linear Bar (d1_truss)
    # ─────────────────────────────────────────────────
    @testset "d1_truss" begin
        @testset "elementstiffness" begin
            E, A, L = 200e9, 0.01, 4.0
            Ke = d1_truss_elementstiffness(E, A, L)
            EAoL = E * A / L  # 5e8
            @test Ke ≈ [EAoL -EAoL; -EAoL EAoL]
            @test size(Ke) == (2, 2)
            @test Ke == Ke'
        end

        @testset "elementforce" begin
            E, A, L = 200e9, 0.01, 4.0
            Ke = d1_truss_elementstiffness(E, A, L)
            u = [0.001; 0.0]
            f = d1_truss_elementforce(Ke, u)
            @test f ≈ [500000.0; -500000.0]
            # zero displacement
            @test d1_truss_elementforce(Ke, [0.0; 0.0]) ≈ [0.0; 0.0]
        end

        @testset "elementstress" begin
            Ke = [5e8 -5e8; -5e8 5e8]
            u = [0.001; 0.0]
            sigma = d1_truss_elementstress(Ke, u, 0.01)
            @test sigma ≈ [5e7; -5e7]
        end

        @testset "elementstrain" begin
            L = 4.0
            u = [0.001; 0.0]
            eps = d1_truss_elementstrain(L, u)
            @test eps ≈ [2.5e-4; 0.0]
            # zero displacement
            @test d1_truss_elementstrain(L, [0.0; 0.0]) ≈ [0.0; 0.0]
        end

        @testset "assemble" begin
            K = zeros(2, 2)
            k = [5e8 -5e8; -5e8 5e8]
            K = d1_truss_assemble(K, k, 1, 2)
            @test K == k
            @test size(K) == (2, 2)
        end
    end

    # ─────────────────────────────────────────────────
    # 2-D Beam / Plane Frame (d2_beam)
    # ─────────────────────────────────────────────────
    @testset "d2_beam" begin
        @testset "elementlength" begin
            @test d2_beam_elementlength(0, 0, 3, 4) == 5.0
            @test d2_beam_elementlength(1, 2, 1, 2) == 0.0  # zero length
            @test d2_beam_elementlength(-1, -1, 2, 3) ≈ sqrt(3^2 + 4^2)
            @test d2_beam_elementlength(0, 0, 0, 5) == 5.0
        end

        @testset "elementstiffness" begin
            # Simple case: E=1, A=1, I=1, L=1, theta=0
            Ke = d2_beam_elementstiffness(1, 1, 1, 1, 0)
            @test size(Ke) == (6, 6)
            @test Ke == Ke'  # symmetric
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

        @testset "elementforce" begin
            # Simple: E=1, A=1, I=1, L=1, theta=0
            # u has only axial displacement at node 2
            u = [0.0, 0.0, 0.0, 0.001, 0.0, 0.0]
            f = d2_beam_elementforce(1, 1, 1, 1, 0, u)
            @test length(f) == 6
            @test f[1] ≈ -0.001  # axial force = -EA/L * u_x2
            @test f[4] ≈ 0.001
            @test f[2] ≈ 0.0
            @test f[3] ≈ 0.0
            @test f[5] ≈ 0.0
            @test f[6] ≈ 0.0
            # zero displacement
            @test d2_beam_elementforce(1, 1, 1, 1, 0, zeros(6)) ≈ zeros(6)
        end

        @testset "elementaxialdiagram" begin
            f = [1000, 500, 200, -1000, 500, -200]
            L = 5.0
            p = d2_beam_elementaxialdiagram(f, L)
            @test p isa Plots.Plot
        end

        @testset "elementmomentdiagram" begin
            f = [1000, 500, 200, -1000, 500, -200]
            L = 5.0
            p = d2_beam_elementmomentdiagram(f, L)
            @test p isa Plots.Plot
        end

        @testset "elementsheardiagram" begin
            f = [1000, 500, 200, -1000, 500, -200]
            L = 5.0
            p = d2_beam_elementsheardiagram(f, L)
            @test p isa Plots.Plot
        end

        @testset "assemble" begin
            K = zeros(6, 6)
            k = ones(6, 6)
            K = d2_beam_assemble(K, k, 1, 2)
            @test K == ones(6, 6)
            # assemble into larger system
            K9 = zeros(9, 9)
            ke = reshape(1:36, 6, 6)  # non-symmetric to check positions
            K9 = d2_beam_assemble(K9, ke, 1, 2)
            # Node 1 DOF: 1-3, Node 2 DOF: 4-6
            @test K9[1:3, 1:3] == ke[1:3, 1:3]
            @test K9[1:3, 4:6] == ke[1:3, 4:6]
            @test K9[4:6, 1:3] == ke[4:6, 1:3]
            @test K9[4:6, 4:6] == ke[4:6, 4:6]
        end
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
            @test Ke == Ke'
            # Vertical spring: theta=90
            Ke90 = d2_spring_elementstiffness(1000, 90)
            @test Ke90 ≈ 1000 * [0 0 0 0; 0 1 0 -1; 0 0 0 0; 0 -1 0 1]
            # Zero stiffness
            @test d2_spring_elementstiffness(0, 30) == zeros(4, 4)
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
    end

    # ─────────────────────────────────────────────────
    # 2-D Truss / Plane Truss (d2_truss)
    # ─────────────────────────────────────────────────
    @testset "d2_truss" begin
        @testset "elementlength" begin
            @test d2_truss_elementlength(0, 0, 3, 4) == 5.0
            @test d2_truss_elementlength(0, 0, 0, 0) == 0.0
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
            @test Ke == Ke'
            # Horizontal truss (theta=0)
            Ke0 = d2_truss_elementstiffness(E, A, L, 0)
            @test Ke0 ≈ EAoL * [1 0 -1 0; 0 0 0 0; -1 0 1 0; 0 0 0 0]
        end

        @testset "elementforce" begin
            E, A, L = 1.0, 1.0, 1.0
            theta = 30.0
            C = cos(π / 6)
            u = [1.0; 0.0; 0.0; 0.0]
            f = d2_truss_elementforce(E, A, L, theta, u)  # returns 1-element Vector
            @test f[1] ≈ -C  # -EA/L * C
            # zero displacement
            @test d2_truss_elementforce(E, A, L, theta, zeros(4))[1] ≈ 0.0
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
    end

    # ─────────────────────────────────────────────────
    # 3-D Spring (d3_spring)
    # ─────────────────────────────────────────────────
    @testset "d3_spring" begin
        @testset "elementstiffness" begin
            # All direction cosines = 1
            Ke = d3_spring_elementstiffness(1000, 0, 0, 0)
            @test size(Ke) == (6, 6)
            @test Ke == Ke'
            w_ones = ones(3, 3)
            @test Ke ≈ 1000 * [w_ones -w_ones; -w_ones w_ones]
            # thetax=0, thetay=90, thetaz=0 → Cy=0
            Ke2 = d3_spring_elementstiffness(1000, 0, 90, 0)
            w2 = [1 0 1; 0 0 0; 1 0 1]
            @test Ke2 ≈ 1000 * [w2 -w2; -w2 w2]
            # Zero stiffness
            @test d3_spring_elementstiffness(0, 0, 0, 0) == zeros(6, 6)
        end

        @testset "elementforce" begin
            k = 1000.0
            # Unit displacement in x at node 1, all direction cosines = 1
            f = d3_spring_elementforce(k, 0, 0, 0, [1.0; 0.0; 0.0; 0.0; 0.0; 0.0])
            @test f[1] ≈ -1000.0  # -k * Cx
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
    end

    # ─────────────────────────────────────────────────
    # 3-D Truss / Space Truss (d3_truss)
    # ─────────────────────────────────────────────────
    @testset "d3_truss" begin
        @testset "elementlength" begin
            @test d3_truss_elementlength(0, 0, 0, 1, 1, 1) ≈ sqrt(3)
            @test d3_truss_elementlength(0, 0, 0, 0, 0, 0) == 0.0
            @test d3_truss_elementlength(1, 0, 0, 4, 0, 0) == 3.0
        end

        @testset "elementstiffness" begin
            E, A, L = 1.0, 1.0, 1.0
            # All direction cosines = 1
            Ke = d3_truss_elementstiffness(E, A, L, 0, 0, 0)
            @test size(Ke) == (6, 6)
            @test Ke == Ke'
            w_ones = ones(3, 3)
            @test Ke ≈ [w_ones -w_ones; -w_ones w_ones]
            # thetax=0, thetay=90, thetaz=0
            Ke2 = d3_truss_elementstiffness(E, A, L, 0, 90, 0)
            w2 = [1 0 1; 0 0 0; 1 0 1]
            @test Ke2 ≈ [w2 -w2; -w2 w2]
        end

        @testset "elementforce" begin
            E, A, L = 1.0, 1.0, 1.0
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            f = d3_truss_elementforce(E, A, L, 0, 0, 0, u)
            @test f[1] ≈ -1.0
            # zero displacement
            @test d3_truss_elementforce(E, A, L, 0, 0, 0, zeros(6))[1] ≈ 0.0
        end

        @testset "elementstrain" begin
            L = 1.0
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            eps = d3_truss_elementstrain(L, 0, 0, 0, u)
            @test eps[1] ≈ -1.0
        end

        @testset "elementstress" begin
            E = 1.0
            L = 1.0
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            sigma = d3_truss_elementstress(E, L, 0, 0, 0, u)
            @test sigma[1] ≈ -1.0
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
    end

end  # @testset "LibFEM"

include("comparison.jl")
