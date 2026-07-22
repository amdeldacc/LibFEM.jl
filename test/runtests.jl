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

        @testset "negative/zero parameter behavior" begin
            # Zero stiffness → zero matrix
            @test d1_spring_elementstiffness(0) == zeros(2, 2)
            # Negative stiffness → negated matrix
            @test d1_spring_elementstiffness(-100) == -100 * [1 -1; -1 1]
            # Negative stiffness force
            Ke_neg = d1_spring_elementstiffness(-100)
            @test d1_spring_elementforce(Ke_neg, [0.01; 0.0]) ≈ [-1.0; 1.0]
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

        @testset "elementforces" begin
            E, A, L = 200e9, 0.01, 4.0
            Ke = d1_truss_elementstiffness(E, A, L)
            u = [0.001; 0.0]
            f = d1_truss_elementforces(Ke, u)
            @test f ≈ [500000.0; -500000.0]
            # zero displacement
            @test d1_truss_elementforces(Ke, [0.0; 0.0]) ≈ [0.0; 0.0]
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
            @test eps ≈ -2.5e-4
            # zero displacement
            @test d1_truss_elementstrain(L, [0.0; 0.0]) ≈ 0.0
        end

        @testset "assemble" begin
            K = zeros(2, 2)
            k = [5e8 -5e8; -5e8 5e8]
            K = d1_truss_assemble(K, k, 1, 2)
            @test K == k
            @test size(K) == (2, 2)
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d1_truss_elementstiffness(1.0, 1.0, 0.0)
            @test_throws ElementParameterError d1_truss_elementstiffness(1.0, 1.0, -1.0)
            @test_throws ElementParameterError d1_truss_elementstrain(0.0, [1.0; 0.0])
            @test_throws ElementParameterError d1_truss_elementstrain(-1.0, [1.0; 0.0])
        end

        @testset "assembly error paths" begin
            K = zeros(2, 2)
            k = d1_truss_elementstiffness(1, 1, 1)
            @test_throws AssemblyError d1_truss_assemble(K, k, 1, 1)

            K4 = zeros(4, 4)
            k4 = d2_truss_elementstiffness(1, 1, 1, 0)
            @test_throws AssemblyError d2_truss_assemble(K4, k4, 1, 1)

            K6 = zeros(6, 6)
            k6 = d2_beam_elementstiffness(1, 1, 1, 1, 0)
            @test_throws AssemblyError d2_beam_assemble(K6, k6, 1, 1)
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → zero matrix
            @test d1_truss_elementstiffness(1.0, 0.0, 1.0) == zeros(2, 2)
            # Negative area → negated matrix
            @test d1_truss_elementstiffness(1.0, -1.0, 1.0) == -[1 -1; -1 1]
            # Zero modulus → zero matrix
            @test d1_truss_elementstiffness(0.0, 1.0, 1.0) == zeros(2, 2)
            # Negative modulus → negated matrix
            @test d1_truss_elementstiffness(-1.0, 1.0, 1.0) == -[1 -1; -1 1]
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

        @testset "elementforces" begin
            # Simple: E=1, A=1, I=1, L=1, theta=0
            # u has only axial displacement at node 2
            u = [0.0, 0.0, 0.0, 0.001, 0.0, 0.0]
            f = d2_beam_elementforces(1, 1, 1, 1, 0, u)
            @test length(f) == 6
            @test f[1] ≈ -0.001  # axial force = -EA/L * u_x2
            @test f[4] ≈ 0.001
            @test f[2] ≈ 0.0
            @test f[3] ≈ 0.0
            @test f[5] ≈ 0.0
            @test f[6] ≈ 0.0
            # zero displacement
            @test d2_beam_elementforces(1, 1, 1, 1, 0, zeros(6)) ≈ zeros(6)
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

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d2_beam_elementstiffness(1.0, 1.0, 1.0, 0.0, 0.0)
            @test_throws ElementParameterError d2_beam_elementstiffness(1.0, 1.0, 1.0, -1.0, 0.0)
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → zero matrix (axial part)
            Ke = d2_beam_elementstiffness(1.0, 0.0, 1.0, 1.0, 0.0)
            @test Ke[1, 1] == 0.0
            @test Ke[1, 4] == 0.0
            # Negative area → negated axial part
            Ke_neg = d2_beam_elementstiffness(1.0, -1.0, 1.0, 1.0, 0.0)
            @test Ke_neg[1, 1] == -1.0
            @test Ke_neg[1, 4] == 1.0
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

        @testset "L>0 error paths" begin
            # d2_spring doesn't have L parameter
        end

        @testset "negative/zero parameter behavior" begin
            # Zero stiffness → zero matrix
            @test d2_spring_elementstiffness(0, 30) == zeros(4, 4)
            # Negative stiffness → negated matrix
            @test d2_spring_elementstiffness(-100, 0) == -100 * [1 0 -1 0; 0 0 0 0; -1 0 1 0; 0 0 0 0]
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
            # Zero area → zero matrix
            @test d2_truss_elementstiffness(1.0, 0.0, 1.0, 0.0) == zeros(4, 4)
            # Negative area → negated matrix
            C = cos(0); S = sin(0)
            expected = [C*C C*S -C*C -C*S; C*S S*S -C*S -S*S; -C*C -C*S C*C C*S; -C*S -S*S C*S S*S]
            @test d2_truss_elementstiffness(1.0, -1.0, 1.0, 0.0) == -expected
            # Zero modulus → zero matrix
            @test d2_truss_elementstiffness(0.0, 1.0, 1.0, 0.0) == zeros(4, 4)
            # Negative modulus → negated matrix
            @test d2_truss_elementstiffness(-1.0, 1.0, 1.0, 0.0) == -expected
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

        @testset "negative/zero parameter behavior" begin
            # Zero stiffness → zero matrix
            @test d3_spring_elementstiffness(0, 0, 0, 0) == zeros(6, 6)
            # Negative stiffness → negated matrix
            w_ones = ones(3, 3)
            @test d3_spring_elementstiffness(-1000, 0, 0, 0) == -1000 * [w_ones -w_ones; -w_ones w_ones]
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

        @testset "elementforces" begin
            E, A, L = 1.0, 1.0, 1.0
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            f = d3_truss_elementforces(E, A, L, 0, 0, 0, u)
            @test f[1] ≈ -1.0
            # zero displacement
            @test d3_truss_elementforces(E, A, L, 0, 0, 0, zeros(6))[1] ≈ 0.0
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
            # Zero area → zero matrix
            @test d3_truss_elementstiffness(1.0, 0.0, 1.0, 0, 0, 0) == zeros(6, 6)
            # Negative area → negated matrix
            @test d3_truss_elementstiffness(1.0, -1.0, 1.0, 0, 0, 0) == -[ones(3,3) -ones(3,3); -ones(3,3) ones(3,3)]
            # Zero modulus → zero matrix
            @test d3_truss_elementstiffness(0.0, 1.0, 1.0, 0, 0, 0) == zeros(6, 6)
            # Negative modulus → negated matrix
            @test d3_truss_elementstiffness(-1.0, 1.0, 1.0, 0, 0, 0) == -[ones(3,3) -ones(3,3); -ones(3,3) ones(3,3)]
        end
    end

    # ─────────────────────────────────────────────────
    # 3-D Beam / Space Frame (d3_beam)
    # ─────────────────────────────────────────────────
    @testset "d3_beam" begin
        @testset "elementlength" begin
            @test d3_beam_elementlength(0,0,0, 3,4,12) ≈ 13.0  # 5-12-13 triangle
            @test d3_beam_elementlength(0,0,0, 0,0,0) == 0.0
            @test d3_beam_elementlength(1,0,0, 5,0,0) == 4.0
            @test d3_beam_elementlength(0,0,0, 1,1,1) ≈ sqrt(3)
        end

        @testset "elementstiffness" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            # Horizontal beam along X: (0,0,0)→(4,0,0)
            Ke = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 4,0,0)
            @test size(Ke) == (12, 12)
            @test Ke == Ke'  # symmetric

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
            f = d3_beam_elementforces(E, G, A, Iy, Iz, J, 0,0,0, 4,0,0, u)
            @test length(f) == 12
            @test f[1] ≈ -(E*A/4.0) * 0.001  # reaction at node 1 = -EA/L * u_x2
            @test f[7] ≈ (E*A/4.0) * 0.001   # reaction at node 2 = +EA/L * u_x2
            # Zero displacement → zero force
            @test d3_beam_elementforces(E, G, A, Iy, Iz, J, 0,0,0, 4,0,0, zeros(12)) ≈ zeros(12)
        end

        @testset "assemble" begin
            K = zeros(12, 12)
            k = reshape(1.0:144.0, 12, 12)
            K = d3_beam_assemble(K, k, 1, 2)
            @test K[1:6, 1:6] == k[1:6, 1:6]
            @test K[1:6, 7:12] == k[1:6, 7:12]
            @test K[7:12, 1:6] == k[7:12, 1:6]
            @test K[7:12, 7:12] == k[7:12, 7:12]
        end

        @testset "diagrams" begin
            f = [1000, 500, 300, 200, 150, 100, -1000, -500, -300, -200, -150, -100]
            L = 5.0
            @test d3_beam_elementaxialdiagram(f, L) isa Plots.Plot
            @test d3_beam_elementshearydiagram(f, L) isa Plots.Plot
            @test d3_beam_elementshearzdiagram(f, L) isa Plots.Plot
            @test d3_beam_elementmomentydiagram(f, L) isa Plots.Plot
            @test d3_beam_elementmomentzdiagram(f, L) isa Plots.Plot
            @test d3_beam_elementtorsiondiagram(f, L) isa Plots.Plot
        end

        @testset "near-vertical beam" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            Ke = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 1e-10,1e-10,4)
            @test size(Ke) == (12, 12)
            @test all(!isnan, Ke)
            @test Ke ≈ Ke'
            u = zeros(12); u[7] = 0.001
            f = d3_beam_elementforces(E, G, A, Iy, Iz, J, 0,0,0, 1e-10,1e-10,4, u)
            @test all(!isnan, f)
            @test length(f) == 12
        end

        @testset "vertical beam" begin
            E, G, A, Iy, Iz, J = 3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5
            # Vertical beam along Z: (0,0,0)→(0,0,4)
            Ke = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 0,0,4)
            @test size(Ke) == (12, 12)
            @test Ke == Ke'
            @test all(!isnan, Ke)
            # Vertical beam along Z (negative direction)
            Ke2 = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,4, 0,0,0)
            @test size(Ke2) == (12, 12)
            @test all(!isnan, Ke2)
        end

        @testset "L>0 error paths" begin
            @test_throws ElementParameterError d3_beam_elementstiffness(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0,0,0, 0,0,0)
            @test_throws ElementParameterError d3_beam_elementforces(1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0,0,0, 0,0,0, zeros(12))
        end

        @testset "negative/zero parameter behavior" begin
            # Zero area → zero axial part
            Ke = d3_beam_elementstiffness(1.0, 1.0, 0.0, 1.0, 1.0, 1.0, 0,0,0, 1,0,0)
            @test Ke[1, 1] == 0.0
            @test Ke[1, 7] == 0.0
            # Negative area → negated axial part
            Ke_neg = d3_beam_elementstiffness(1.0, 1.0, -1.0, 1.0, 1.0, 1.0, 0,0,0, 1,0,0)
            @test Ke_neg[1, 1] == -1.0
            @test Ke_neg[1, 7] == 1.0
        end

        # ═══════════════════════════════════════════════════
        # Sprint 3 — Wave 5: Test Hardening
        # ═══════════════════════════════════════════════════

        @testset "element property tests" begin
            k1 = d1_truss_elementstiffness(1, 1, 1)
            @test k1 == k1'
            @test all(x -> isapprox(x, 0.0, atol=1e-15), k1 * ones(2))

            k2 = d2_truss_elementstiffness(1, 1, 1, 30)
            @test k2 == k2'
            @test all(x -> isapprox(x, 0.0, atol=1e-14), k2 * ones(4))

            k3 = d3_truss_elementstiffness(1, 1, 1, 30, 45, 60)
            @test k3 == k3'
            @test all(x -> isapprox(x, 0.0, atol=1e-14), k3 * ones(6))

            k2s = d2_spring_elementstiffness(100, 30)
            @test k2s == k2s'
            @test all(x -> isapprox(x, 0.0, atol=1e-14), k2s * ones(4))

            k3s = d3_spring_elementstiffness(100, 30, 45, 60)
            @test k3s == k3s'
            @test_broken all(x -> isapprox(x, 0.0, atol=1e-14), k3s * ones(6))

            k2b = d2_beam_elementstiffness(1, 1, 1, 1, 30)
            @test k2b == k2b'

            k3b = d3_beam_elementstiffness(1, 1, 1, 1, 1, 1, 0,0,0, 4,0,0)
            @test k3b == k3b'
        end

        @testset "negative path tests" begin
            @test_throws ElementParameterError d1_truss_elementstiffness(1, 1, 0)
            @test_throws ElementParameterError d2_truss_elementstiffness(1, 1, 0, 0)
            @test_throws ElementParameterError d3_truss_elementstiffness(1, 1, 0, 0, 0, 0)
            @test_throws ElementParameterError d2_beam_elementstiffness(1, 1, 1, 0, 0)
            @test_throws ElementParameterError d1_truss_elementstiffness(1, 1, -1)
            # C2: impossible 3D direction cosines → warning, not error
            @test_logs (:warn, r"Direction cosines do not form a unit vector") d3_truss_elementstiffness(1, 1, 1, 90, 90, 90)
            @test_logs (:warn, r"Direction cosines do not form a unit vector") d3_spring_elementstiffness(100, 90, 90, 90)
        end

        @testset "diagram functions" begin
            f2 = [1000, 500, 200, -1000, 500, -200]
            f3 = [1000, 500, 300, 200, 150, 100, -1000, -500, -300, -200, -150, -100]
            L = 5.0
            # Returns Plots.Plot objects (not raw data vectors)
            @test d2_beam_elementaxialdiagram(f2, L) isa Plots.Plot
            @test d2_beam_elementsheardiagram(f2, L) isa Plots.Plot
            @test d2_beam_elementmomentdiagram(f2, L) isa Plots.Plot
            @test d3_beam_elementaxialdiagram(f3, L) isa Plots.Plot
            @test d3_beam_elementshearydiagram(f3, L) isa Plots.Plot
            @test d3_beam_elementshearzdiagram(f3, L) isa Plots.Plot
            @test d3_beam_elementmomentydiagram(f3, L) isa Plots.Plot
            @test d3_beam_elementmomentzdiagram(f3, L) isa Plots.Plot
            @test d3_beam_elementtorsiondiagram(f3, L) isa Plots.Plot
        end

        include("comparison.jl")

        @testset "diagram z-vector values" begin
            f2 = [1000, 500, 200, -1000, 500, -200]
            f3 = [1000, 500, 300, 200, 150, 100, -1000, -500, -300, -200, -150, -100]
            L = 5.0
            # Verify via MATLAB reference data functions from comparison.jl
            @test PlaneFrameElementAxialDiagram(f2, L) == [-1000, -1000]
            @test PlaneFrameElementShearDiagram(f2, L) == [500, -500]
            @test PlaneFrameElementMomentDiagram(f2, L) == [-200, -200]
            @test SpaceFrameElementAxialDiagram(f3, L) == [-1000, -1000]
            @test SpaceFrameElementShearYDiagram(f3, L) == [500, 500]
            @test SpaceFrameElementShearZDiagram(f3, L) == [300, 300]
            @test SpaceFrameElementMomentYDiagram(f3, L) == [150, 150]
            @test SpaceFrameElementMomentZDiagram(f3, L) == [100, 100]
            @test SpaceFrameElementTorsionDiagram(f3, L) == [200, 200]
        end

        @testset "assembly edge cases" begin
            K6 = zeros(6, 6)
            k = d2_truss_elementstiffness(1, 1, 1, 0)
            K6 = d2_truss_assemble(K6, k, 1, 3)
            @test K6[1:2, 1:2] == k[1:2, 1:2]
            @test K6[1:2, 5:6] == k[1:2, 3:4]
            @test K6[5:6, 1:2] == k[3:4, 1:2]
            @test K6[5:6, 5:6] == k[3:4, 3:4]

            # d1_spring/d1_truss identity
            @test d1_spring_elementstiffness(500) == d1_truss_elementstiffness(500, 1, 1)
            # 2D identity: spring(k=EA/L) = truss(E, A, L)
            @test d2_spring_elementstiffness(100, 30) ≈ d2_truss_elementstiffness(100, 1, 1, 30)
            # 3D identity
            @test d3_spring_elementstiffness(100, 30, 45, 60) ≈ d3_truss_elementstiffness(100, 1, 1, 30, 45, 60)
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
        :d1_truss_elementstiffness,
        :d2_truss_elementstiffness,
        :d3_truss_elementstiffness,
        :d2_beam_elementstiffness,
        :d3_beam_elementstiffness,
        :deg2rad,
        :AbstractSpring,
        :Spring,
        :AbstractTruss,
        :Truss,
        :AbstractBeam,
        :Beam,
        :ElementDimensionError,
        :AssemblyError,
    ]
        @test isdefined(LibFEM, sym) || error("$sym not exported")
    end
end
