# ═══════════════════════════════════════════════════════════════
# Property-Based Tests
# ═══════════════════════════════════════════════════════════════
# Tests physical invariants across randomly generated parameters:
# 1. Stiffness symmetry (K ≈ K') — all element types
# 2. Zero row-sum (rigid body modes) — spring and truss elements only
# 3. Assembly linearity — sequential assembly = direct addition
# 4. PropCheck.jl integration — demonstrate property-based checking
# ═══════════════════════════════════════════════════════════════

using LibFEM, Test, LinearAlgebra, PropCheck

@testset "property-based tests" begin

    # Helper: generate 3D angles with valid direction cosines (Cx²+Cy²+Cz² = 1)
    function _rand_3d_angles()
        φ = π * rand()
        ψ = 2π * rand()
        Cx = sin(φ) * cos(ψ)
        Cy = sin(φ) * sin(ψ)
        Cz = cos(φ)
        tx = rad2deg(acos(clamp(Cx, -1, 1)))
        ty = rad2deg(acos(clamp(Cy, -1, 1)))
        tz = rad2deg(acos(clamp(Cz, -1, 1)))
        return tx, ty, tz
    end

    # ─────────────────────────────────────────────────
    # 1. Stiffness Symmetry
    # ─────────────────────────────────────────────────
    @testset "stiffness symmetry" begin

        # d1_spring: K ≈ K' for k ∈ [1, 1001]
        for _ in 1:30
            k = 1.0 + 1000.0 * rand()
            Ke = d1_spring_elementstiffness(k)
            @test Ke ≈ Ke'
        end

        # d2_truss: K ≈ K' for random (E, A, L, θ)
        for _ in 1:20
            e = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            th = 180.0 * rand()
            Ke = d2_truss_elementstiffness(e, a, l, th)
            @test Ke ≈ Ke'
        end

        # d2_beam: K ≈ K' for random (E, I, L)
        for _ in 1:20
            e = 1.0 + 100.0 * rand()
            i_val = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            Ke = d2_beam_elementstiffness(e, i_val, l)
            @test Ke ≈ Ke'
        end

        # d3_spring: K ≈ K' for random angles (valid 3D direction cosines)
        for _ in 1:15
            k = 1.0 + 1000.0 * rand()
            tx, ty, tz = _rand_3d_angles()
            Ke = d3_spring_elementstiffness(k, tx, ty, tz)
            @test Ke ≈ Ke'
        end

        # d2_planeframe: K ≈ K' for random (E, A, I, L, θ)
        for _ in 1:15
            e = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            i_val = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            th = 180.0 * rand()
            Ke = d2_planeframe_elementstiffness(e, a, i_val, l, th)
            @test Ke ≈ Ke'
        end

        # d3_truss: K ≈ K' (valid 3D direction cosines)
        for _ in 1:15
            e = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            tx, ty, tz = _rand_3d_angles()
            Ke = d3_truss_elementstiffness(e, a, l, tx, ty, tz)
            @test Ke ≈ Ke'
        end

        # d3_spaceframe: K ≈ K'
        for _ in 1:10
            e = 1.0 + 100.0 * rand()
            g = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            iy = 0.01 + 1.0 * rand()
            iz = 0.01 + 1.0 * rand()
            j = 0.01 + 1.0 * rand()
            x2 = 1.0 + 10.0 * rand()
            Ke = d3_spaceframe_elementstiffness(e, g, a, iy, iz, j, 0, 0, 0, x2, 0, 0)
            @test Ke ≈ Ke'
        end

        # d2_grid: K ≈ K' for random (E, G, I, J, L, θ)
        for _ in 1:15
            e = 1.0 + 100.0 * rand()
            g = 1.0 + 100.0 * rand()
            i_val = 0.1 + 10.0 * rand()
            j_val = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            th = 180.0 * rand()
            Ke = d2_grid_elementstiffness(e, g, i_val, j_val, l, th)
            @test Ke ≈ Ke'
        end

        # d2_cst: K ≈ K' for random (E, NU, t, p)
        for _ in 1:15
            e = 1.0 + 100.0 * rand()
            nu = 0.1 + 0.4 * rand()
            t = 0.01 + 1.0 * rand()
            p = rand(1:2)
            Ke = d2_cst_elementstiffness(e, nu, t, 0,0, 1,0, 0,1, p)
            @test Ke ≈ Ke'
        end

        # d2_q4: K ≈ K' for random (E, NU, h, p)
        for _ in 1:15
            e = 1.0 + 100.0 * rand()
            nu = 0.1 + 0.4 * rand()
            h = 0.01 + 1.0 * rand()
            p = rand(1:2)
            Ke = d2_q4_elementstiffness(e, nu, h, 0,0, 1,0, 1,1, 0,1, p)
            @test Ke ≈ Ke'
        end
    end

    # ─────────────────────────────────────────────────
    # 2. Zero Row-Sum (rigid body translation modes)
    # ─────────────────────────────────────────────────
    # Only spring and truss elements (purely translational DOFs).
    # For these, K · [1,1,…,1]ᵀ ≈ 0 (sum of each row ≈ 0).
    @testset "zero row-sum" begin

        # d1_spring
        for _ in 1:20
            k = 1.0 + 1000.0 * rand()
            Ke = d1_spring_elementstiffness(k)
            @test all(x -> isapprox(x, 0.0, atol=1e-10), sum(Ke, dims=2))
        end

        # d2_spring
        for _ in 1:15
            k = 1.0 + 1000.0 * rand()
            th = 180.0 * rand()
            Ke = d2_spring_elementstiffness(k, th)
            @test all(x -> isapprox(x, 0.0, atol=1e-10), sum(Ke, dims=2))
        end

        # d3_spring (valid 3D direction cosines)
        for _ in 1:10
            k = 1.0 + 1000.0 * rand()
            tx, ty, tz = _rand_3d_angles()
            Ke = d3_spring_elementstiffness(k, tx, ty, tz)
            @test all(x -> isapprox(x, 0.0, atol=1e-9), sum(Ke, dims=2))
        end

        # d1_bar
        for _ in 1:10
            e = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            Ke = d1_bar_elementstiffness(e, a, l)
            @test all(x -> isapprox(x, 0.0, atol=1e-10), sum(Ke, dims=2))
        end

        # d2_truss
        for _ in 1:10
            e = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            th = 180.0 * rand()
            Ke = d2_truss_elementstiffness(e, a, l, th)
            @test all(x -> isapprox(x, 0.0, atol=1e-10), sum(Ke, dims=2))
        end

        # d3_truss (valid 3D direction cosines)
        for _ in 1:10
            e = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            l = 0.1 + 10.0 * rand()
            tx, ty, tz = _rand_3d_angles()
            Ke = d3_truss_elementstiffness(e, a, l, tx, ty, tz)
            @test all(x -> isapprox(x, 0.0, atol=1e-9), sum(Ke, dims=2))
        end
    end

    # ─────────────────────────────────────────────────
    # 3. Assembly Linearity
    # ─────────────────────────────────────────────────
    # Assembling k₁ + k₂ sequentially gives the same global
    # matrix as directly adding the element contributions.
    @testset "assembly linearity" begin

        # d1_spring: two springs in series (3 nodes)
        for _ in 1:20
            k1 = 100.0 + 1000.0 * rand()
            k2 = 100.0 + 1000.0 * rand()
            ke1 = d1_spring_elementstiffness(k1)
            ke2 = d1_spring_elementstiffness(k2)

            K_seq = zeros(3, 3)
            K_seq = d1_spring_assemble(K_seq, ke1, 1, 2)
            K_seq = d1_spring_assemble(K_seq, ke2, 2, 3)

            K_ref = zeros(3, 3)
            K_ref[1:2, 1:2] .+= ke1
            K_ref[2:3, 2:3] .+= ke2

            @test K_seq ≈ K_ref
        end

        # d2_truss: two trusses sharing a node (3 nodes)
        for _ in 1:15
            e = 1.0 + 100.0 * rand()
            a = 0.1 + 10.0 * rand()
            l1 = 0.1 + 10.0 * rand()
            l2 = 0.1 + 10.0 * rand()
            th1 = 180.0 * rand()
            th2 = 180.0 * rand()

            ke1 = d2_truss_elementstiffness(e, a, l1, th1)
            ke2 = d2_truss_elementstiffness(e, a, l2, th2)

            K_seq = zeros(6, 6)
            K_seq = d2_truss_assemble(K_seq, ke1, 1, 2)
            K_seq = d2_truss_assemble(K_seq, ke2, 2, 3)

            K_ref = zeros(6, 6)
            K_ref[1:2, 1:2] .+= ke1[1:2, 1:2]
            K_ref[1:2, 3:4] .+= ke1[1:2, 3:4]
            K_ref[3:4, 1:2] .+= ke1[3:4, 1:2]
            K_ref[3:4, 3:4] .+= ke1[3:4, 3:4]
            K_ref[3:4, 3:4] .+= ke2[1:2, 1:2]
            K_ref[3:4, 5:6] .+= ke2[1:2, 3:4]
            K_ref[5:6, 3:4] .+= ke2[3:4, 1:2]
            K_ref[5:6, 5:6] .+= ke2[3:4, 3:4]

            @test K_seq ≈ K_ref
        end
    end

    # ─────────────────────────────────────────────────
    # 4. PropCheck.jl Integration Demo
    # ─────────────────────────────────────────────────
    @testset "PropCheck.check integration" begin
        # Demonstrate PropCheck.jl usage: property-based check
        # for stiffness symmetry on d1_spring with random values.
        gen_k = PropCheck.map(x -> Float64(x), PropCheck.isample(1:10000))

        # check(predicate, generator; ntests=N) returns true if the
        # predicate holds for all generated values, or the failing
        # counterexample value if a counterexample is found.
        ok = PropCheck.check(k -> begin
            Ke = d1_spring_elementstiffness(k)
            return Ke ≈ Ke'
        end, gen_k; ntests=20)

        # true means all 20 random tests passed
        @test ok == true
    end

end # @testset "property-based tests"
