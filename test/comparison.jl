# ─────────────────────────────────────────────────
# MATLAB Reference Implementations (Spring)
# Transcribed from Doc/Kattan/M-Files/ (read-only)
# ─────────────────────────────────────────────────

"""
    SpringElementStiffness(k) -> Matrix

MATLAB reference: returns the 2×2 element stiffness matrix for a spring
with stiffness `k`.  Identical to `d1_spring_elementstiffness(k)`.
"""
function SpringElementStiffness(k)
    return [k -k; -k k]
end

"""
    SpringElementForces(k, u) -> Vector

MATLAB reference: returns the element nodal force vector given the
element stiffness matrix `k` (2×2) and element nodal displacement
vector `u` (2-element).  Identical to `d1_spring_elementforce(k, u)`.
"""
function SpringElementForces(k, u)
    return k * u
end

"""
    SpringAssemble(K, k, i, j) -> Matrix

MATLAB reference: assembles the element stiffness matrix `k` of a
spring with nodes `i` and `j` into the global stiffness matrix `K`.
Returns the updated global matrix.  Identical to `d1_spring_assemble(K, k, i, j)`.
"""
function SpringAssemble(K, k, i, j)
    K[i, i] = K[i, i] + k[1, 1]
    K[i, j] = K[i, j] + k[1, 2]
    K[j, i] = K[j, i] + k[2, 1]
    K[j, j] = K[j, j] + k[2, 2]
    return K
end

# ─────────────────────────────────────────────────
# MATLAB Reference Implementations (LinearBar / 1D Truss)
# Transcribed from Doc/Kattan/M-Files/ (read-only)
# ─────────────────────────────────────────────────

"""
    LinearBarElementStiffness(E, A, L) -> Matrix

MATLAB reference: returns the 2×2 element stiffness matrix for a linear bar
with modulus of elasticity E, cross-sectional area A, and length L.
Identical to `d1_truss_elementstiffness(E, A, L)`.
"""
function LinearBarElementStiffness(E, A, L)
    return [E * A / L -E * A / L; -E * A / L E * A / L]
end

"""
    LinearBarElementForces(k, u) -> Vector

MATLAB reference: returns the element nodal force vector given the
element stiffness matrix k (2×2) and element nodal displacement
vector u (2-element). Identical to `d1_truss_elementforce(k, u)`.
"""
function LinearBarElementForces(k, u)
    return k * u
end

"""
    LinearBarElementStresses(k, u, A) -> Vector

MATLAB reference: returns the element nodal stress vector given the
element stiffness matrix k, element nodal displacement vector u,
and cross-sectional area A. Identical to `d1_truss_elementstress(k, u, A)`.
"""
function LinearBarElementStresses(k, u, A)
    return k * u / A
end

"""
    LinearBarAssemble(K, k, i, j) -> Matrix

MATLAB reference: assembles the element stiffness matrix k of a linear
bar with nodes i and j into the global stiffness matrix K.
Returns the updated global matrix. Identical to `d1_truss_assemble(K, k, i, j)`.
"""
function LinearBarAssemble(K, k, i, j)
    K[i, i] = K[i, i] + k[1, 1]
    K[i, j] = K[i, j] + k[1, 2]
    K[j, i] = K[j, i] + k[2, 1]
    K[j, j] = K[j, j] + k[2, 2]
    return K
end

# ─────────────────────────────────────────────────
# MATLAB Reference Implementations (PlaneTruss / 2D Truss)
# Transcribed from Doc/Kattan/M-Files/ (read-only)
# ─────────────────────────────────────────────────

"""
    PlaneTrussElementLength(x1, y1, x2, y2) -> Real

MATLAB reference: returns the length of a plane truss element between
coordinates (x1, y1) and (x2, y2).
Identical to `d2_truss_elementlength(x1, y1, x2, y2)`.
"""
function PlaneTrussElementLength(x1, y1, x2, y2)
    return sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

"""
    PlaneTrussElementStiffness(E, A, L, theta) -> Matrix

MATLAB reference: returns the 4×4 element stiffness matrix for a plane
truss element with modulus of elasticity E, cross-sectional area A,
length L, and angle theta (in degrees).
Identical to `d2_truss_elementstiffness(E, A, L, theta)`.
"""
function PlaneTrussElementStiffness(E, A, L, theta)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return E * A / L * [
        C * C  C * S -C * C -C * S
        C * S  S * S -C * S -S * S
       -C * C -C * S  C * C  C * S
       -C * S -S * S  C * S  S * S
    ]
end

"""
    PlaneTrussElementForce(E, A, L, theta, u) -> Real

MATLAB reference: returns the scalar element force given the modulus
of elasticity E, cross-sectional area A, length L, angle theta (in degrees),
and element nodal displacement vector u.
MATLAB returns a scalar; Julia's `d2_truss_elementforce` returns a 1-element Vector.
"""
function PlaneTrussElementForce(E, A, L, theta, u)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return first(E * A / L * [-C -S C S] * u)
end

"""
    PlaneTrussElementStress(E, L, theta, u) -> Real

MATLAB reference: returns the scalar element stress given the modulus
of elasticity E, length L, angle theta (in degrees), and element nodal
displacement vector u.
MATLAB returns a scalar; Julia's `d2_truss_elementstress` returns a 1-element Vector.
"""
function PlaneTrussElementStress(E, L, theta, u)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return first(E / L * [-C -S C S] * u)
end

"""
    PlaneTrussAssemble(K, k, i, j) -> Matrix

MATLAB reference: assembles the 4×4 element stiffness matrix k of a
plane truss with nodes i and j into the global stiffness matrix K.
Returns the updated global matrix. Identical to `d2_truss_assemble(K, k, i, j)`.
"""
function PlaneTrussAssemble(K, k, i, j)
    K[2 * i - 1, 2 * i - 1] = K[2 * i - 1, 2 * i - 1] + k[1, 1]
    K[2 * i - 1, 2 * i]     = K[2 * i - 1, 2 * i]     + k[1, 2]
    K[2 * i - 1, 2 * j - 1] = K[2 * i - 1, 2 * j - 1] + k[1, 3]
    K[2 * i - 1, 2 * j]     = K[2 * i - 1, 2 * j]     + k[1, 4]
    K[2 * i, 2 * i - 1]     = K[2 * i, 2 * i - 1]     + k[2, 1]
    K[2 * i, 2 * i]         = K[2 * i, 2 * i]         + k[2, 2]
    K[2 * i, 2 * j - 1]     = K[2 * i, 2 * j - 1]     + k[2, 3]
    K[2 * i, 2 * j]         = K[2 * i, 2 * j]         + k[2, 4]
    K[2 * j - 1, 2 * i - 1] = K[2 * j - 1, 2 * i - 1] + k[3, 1]
    K[2 * j - 1, 2 * i]     = K[2 * j - 1, 2 * i]     + k[3, 2]
    K[2 * j - 1, 2 * j - 1] = K[2 * j - 1, 2 * j - 1] + k[3, 3]
    K[2 * j - 1, 2 * j]     = K[2 * j - 1, 2 * j]     + k[3, 4]
    K[2 * j, 2 * i - 1]     = K[2 * j, 2 * i - 1]     + k[4, 1]
    K[2 * j, 2 * i]         = K[2 * j, 2 * i]         + k[4, 2]
    K[2 * j, 2 * j - 1]     = K[2 * j, 2 * j - 1]     + k[4, 3]
    K[2 * j, 2 * j]         = K[2 * j, 2 * j]         + k[4, 4]
    return K
end

# ─────────────────────────────────────────────────
# MATLAB Reference Implementations (PlaneFrame / 2D Beam)
# Transcribed from Doc/Kattan/M-Files/ (read-only)
# ─────────────────────────────────────────────────

"""
    PlaneFrameElementLength(x1, y1, x2, y2) -> Real

MATLAB reference: returns the length of a plane frame element between
coordinates (x1, y1) and (x2, y2).
Identical to `d2_beam_elementlength(x1, y1, x2, y2)`.
"""
function PlaneFrameElementLength(x1, y1, x2, y2)
    return sqrt((x2 - x1)^2 + (y2 - y1)^2)
end

"""
    PlaneFrameElementStiffness(E, A, I, L, theta) -> Matrix

MATLAB reference: returns the 6×6 element stiffness matrix for a plane
frame element with modulus of elasticity E, cross-sectional area A,
moment of inertia I, length L, and angle theta (in degrees).
Identical to `d2_beam_elementstiffness(E, A, I, L, theta)`.
"""
function PlaneFrameElementStiffness(E, A, I, L, theta)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    w1 = A * C * C + 12 * I * S * S / (L * L)
    w2 = A * S * S + 12 * I * C * C / (L * L)
    w3 = (A - 12 * I / (L * L)) * C * S
    w4 = 6 * I * S / L
    w5 = 6 * I * C / L
    return E / L * [
        w1  w3 -w4 -w1 -w3 -w4
        w3  w2  w5 -w3 -w2  w5
       -w4  w5 4*I  w4 -w5 2*I
       -w1 -w3  w4  w1  w3  w4
       -w3 -w2 -w5  w3  w2 -w5
       -w4  w5 2*I  w4 -w5 4*I
    ]
end

"""
    PlaneFrameElementForces(E, A, I, L, theta, u) -> Vector

MATLAB reference: returns the 6-element element force vector given the
modulus of elasticity E, cross-sectional area A, moment of inertia I,
length L, angle theta (in degrees), and element nodal displacement
vector u. Identical to `d2_beam_elementforce(E, A, I, L, theta, u)`.
"""
function PlaneFrameElementForces(E, A, I, L, theta, u)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    w1 = E * A / L
    w2 = 12 * E * I / (L^3)
    w3 = 6 * E * I / (L^2)
    w4 = 4 * E * I / L
    w5 = 2 * E * I / L
    kprime = [
        w1 0  0  -w1 0   0
        0  w2 w3  0  -w2 w3
        0  w3 w4  0  -w3 w5
       -w1 0  0   w1 0   0
        0 -w2 -w3 0  w2 -w3
        0  w3 w5  0  -w3 w4
    ]
    T = [
        C  S 0 0 0 0
       -S  C 0 0 0 0
        0  0 1 0 0 0
        0  0 0 C S 0
        0  0 0 -S C 0
        0  0 0 0 0 1
    ]
    return kprime * T * u
end

"""
    PlaneFrameAssemble(K, k, i, j) -> Matrix

MATLAB reference: assembles the 6×6 element stiffness matrix k of a
plane frame element with nodes i and j into the global stiffness matrix K
using 3-DOF indexing (3i-2,3i-1,3i). Returns the updated global matrix.
Identical to `d2_beam_assemble(K, k, i, j)`.
"""
function PlaneFrameAssemble(K, k, i, j)
    # Block (i, i)
    K[3*i-2, 3*i-2] += k[1, 1]
    K[3*i-2, 3*i-1] += k[1, 2]
    K[3*i-2, 3*i]   += k[1, 3]
    K[3*i-1, 3*i-2] += k[2, 1]
    K[3*i-1, 3*i-1] += k[2, 2]
    K[3*i-1, 3*i]   += k[2, 3]
    K[3*i,   3*i-2] += k[3, 1]
    K[3*i,   3*i-1] += k[3, 2]
    K[3*i,   3*i]   += k[3, 3]
    # Block (i, j)
    K[3*i-2, 3*j-2] += k[1, 4]
    K[3*i-2, 3*j-1] += k[1, 5]
    K[3*i-2, 3*j]   += k[1, 6]
    K[3*i-1, 3*j-2] += k[2, 4]
    K[3*i-1, 3*j-1] += k[2, 5]
    K[3*i-1, 3*j]   += k[2, 6]
    K[3*i,   3*j-2] += k[3, 4]
    K[3*i,   3*j-1] += k[3, 5]
    K[3*i,   3*j]   += k[3, 6]
    # Block (j, i)
    K[3*j-2, 3*i-2] += k[4, 1]
    K[3*j-2, 3*i-1] += k[4, 2]
    K[3*j-2, 3*i]   += k[4, 3]
    K[3*j-1, 3*i-2] += k[5, 1]
    K[3*j-1, 3*i-1] += k[5, 2]
    K[3*j-1, 3*i]   += k[5, 3]
    K[3*j,   3*i-2] += k[6, 1]
    K[3*j,   3*i-1] += k[6, 2]
    K[3*j,   3*i]   += k[6, 3]
    # Block (j, j)
    K[3*j-2, 3*j-2] += k[4, 4]
    K[3*j-2, 3*j-1] += k[4, 5]
    K[3*j-2, 3*j]   += k[4, 6]
    K[3*j-1, 3*j-2] += k[5, 4]
    K[3*j-1, 3*j-1] += k[5, 5]
    K[3*j-1, 3*j]   += k[5, 6]
    K[3*j,   3*j-2] += k[6, 4]
    K[3*j,   3*j-1] += k[6, 5]
    K[3*j,   3*j]   += k[6, 6]
    return K
end

"""
    PlaneFrameElementAxialDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the axial force diagram
(z = [-f₁, f₄]) for a plane frame element with nodal force vector f
and length L. (Returns data only, no plot.)
Identical to the data portion of `d2_beam_elementaxialdiagram(f, L)`.
"""
function PlaneFrameElementAxialDiagram(f, L)
    return [-f[1], f[4]]
end

"""
    PlaneFrameElementShearDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the shear force diagram
(z = [f₂, -f₅]) for a plane frame element with nodal force vector f
and length L. (Returns data only, no plot.)
Identical to the data portion of `d2_beam_elementsheardiagram(f, L)`.
"""
function PlaneFrameElementShearDiagram(f, L)
    return [f[2], -f[5]]
end

"""
    PlaneFrameElementMomentDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the bending moment diagram
(z = [-f₃, f₆]) for a plane frame element with nodal force vector f
and length L. (Returns data only, no plot.)
Identical to the data portion of `d2_beam_elementmomentdiagram(f, L)`.
"""
function PlaneFrameElementMomentDiagram(f, L)
    return [-f[3], f[6]]
end

# ─────────────────────────────────────────────────
# MATLAB-vs-Julia Comparison Tests
# ─────────────────────────────────────────────────

@testset "MATLAB comparison" begin

    @testset "Spring" begin

        # ═══════════════════════════════════════════
        # Edge cases
        # ═══════════════════════════════════════════
        @testset "Edge cases" begin
            # Zero stiffness → zero matrix
            @test SpringElementStiffness(0) == zeros(2, 2)
            @test d1_spring_elementstiffness(0) == zeros(2, 2)

            # Zero displacement → zero force
            k = SpringElementStiffness(100)
            @test SpringElementForces(k, [0.0, 0.0]) ≈ [0.0, 0.0]
            @test d1_spring_elementforce(k, [0.0, 0.0]) ≈ [0.0, 0.0]

            # MATLAB and Julia agree on edge cases
            @test SpringElementStiffness(0) == d1_spring_elementstiffness(0)

            k = SpringElementStiffness(100)
            @test SpringElementForces(k, [0.0, 0.0]) ≈ d1_spring_elementforce(k, [0.0, 0.0])
        end

        # ═══════════════════════════════════════════
        # Problem 2.1 — Three springs, two elements
        #   (Kattan, Solutions Manual, p. 7)
        # ═══════════════════════════════════════════
        @testset "Problem 2.1" begin
            # --- MATLAB computation path ---
            k1_mat = SpringElementStiffness(200)
            k2_mat = SpringElementStiffness(250)

            K_mat = zeros(3, 3)
            K_mat = SpringAssemble(K_mat, k1_mat, 1, 2)
            K_mat = SpringAssemble(K_mat, k2_mat, 2, 3)

            # Expected assembled matrix
            K_expected = [200  -200    0
                         -200  450  -250
                            0  -250   250]

            @test K_mat ≈ K_expected

            # Reduced system: u1=0, u3=0, f2=10
            k_reduced = K_mat[2, 2]  # 450
            f2 = [10.0]
            u2 = k_reduced \ f2       # [0.0222...]

            U_mat = [0.0; u2[1]; 0.0]
            F_mat = K_mat * U_mat

            # Element forces
            u1_mat = [0.0; u2[1]]
            f1_mat = SpringElementForces(k1_mat, u1_mat)

            u2_vec = [u2[1]; 0.0]
            f2_mat = SpringElementForces(k2_mat, u2_vec)

            # --- Julia computation path ---
            k1_jl = d1_spring_elementstiffness(200)
            k2_jl = d1_spring_elementstiffness(250)

            K_jl = zeros(3, 3)
            K_jl = d1_spring_assemble(K_jl, k1_jl, 1, 2)
            K_jl = d1_spring_assemble(K_jl, k2_jl, 2, 3)

            @test K_jl ≈ K_expected
            # MATLAB and Julia assembly match
            @test K_mat ≈ K_jl

            k_reduced_jl = K_jl[2, 2]
            u2_jl = k_reduced_jl \ f2

            U_jl = [0.0; u2_jl[1]; 0.0]
            F_jl = K_jl * U_jl

            u1_jl = [0.0; u2_jl[1]]
            f1_jl = d1_spring_elementforce(k1_jl, u1_jl)

            u2_jl_vec = [u2_jl[1]; 0.0]
            f2_jl = d1_spring_elementforce(k2_jl, u2_jl_vec)

            # --- Assertions against textbook values ---
            # u2 = 10/450 = 0.02222...
            @test u2[1] ≈ 10 / 450  rtol=1e-10
            @test u2[1] ≈ 0.022222222222222223  rtol=1e-10

            # Full displacement vector
            @test U_mat ≈ [0.0; 10 / 450; 0.0]  rtol=1e-10

            # Nodal forces (from K*U)
            @test F_mat[1] ≈ -4.444444444444445  rtol=1e-10
            @test F_mat[2] ≈ 10.0
            @test F_mat[3] ≈ -5.555555555555555  rtol=1e-10

            # Element 1 forces
            @test f1_mat[1] ≈ -4.444444444444445  rtol=1e-10
            @test f1_mat[2] ≈ 4.444444444444445   rtol=1e-10

            # Element 2 forces
            @test f2_mat[1] ≈ 5.555555555555555   rtol=1e-10
            @test f2_mat[2] ≈ -5.555555555555555  rtol=1e-10

            # --- MATLAB and Julia paths produce identical results ---
            @test K_mat ≈ K_jl
            @test u2 ≈ u2_jl
            @test U_mat ≈ U_jl
            @test F_mat ≈ F_jl
            @test f1_mat ≈ f1_jl
            @test f2_mat ≈ f2_jl
        end

        # ═══════════════════════════════════════════
        # Problem 2.2 — Four springs, four nodes
        #   (Kattan, Solutions Manual, p. 7)
        # ═══════════════════════════════════════════
        @testset "Problem 2.2" begin
            # --- MATLAB computation path ---
            k1_mat = SpringElementStiffness(170)
            k2_mat = SpringElementStiffness(170)
            k3_mat = SpringElementStiffness(170)
            k4_mat = SpringElementStiffness(170)

            K_mat = zeros(4, 4)
            K_mat = SpringAssemble(K_mat, k1_mat, 1, 2)
            K_mat = SpringAssemble(K_mat, k2_mat, 2, 3)
            K_mat = SpringAssemble(K_mat, k3_mat, 2, 3)  # second spring between 2-3
            K_mat = SpringAssemble(K_mat, k4_mat, 3, 4)

            # Expected assembled matrix
            K_expected = [170  -170     0     0
                         -170   510  -340     0
                            0  -340   510  -170
                            0     0  -170   170]

            @test K_mat ≈ K_expected

            # Reduced system: u1=0, f4=25
            K_reduced = K_mat[2:4, 2:4]
            f = [0.0, 0.0, 25.0]
            u_reduced = K_reduced \ f

            U_mat = [0.0; u_reduced]
            F_mat = K_mat * U_mat

            # --- Julia computation path ---
            k1_jl = d1_spring_elementstiffness(170)
            k2_jl = d1_spring_elementstiffness(170)
            k3_jl = d1_spring_elementstiffness(170)
            k4_jl = d1_spring_elementstiffness(170)

            K_jl = zeros(4, 4)
            K_jl = d1_spring_assemble(K_jl, k1_jl, 1, 2)
            K_jl = d1_spring_assemble(K_jl, k2_jl, 2, 3)
            K_jl = d1_spring_assemble(K_jl, k3_jl, 2, 3)
            K_jl = d1_spring_assemble(K_jl, k4_jl, 3, 4)

            @test K_jl ≈ K_expected
            @test K_mat ≈ K_jl

            K_reduced_jl = K_jl[2:4, 2:4]
            u_reduced_jl = K_reduced_jl \ f

            U_jl = [0.0; u_reduced_jl]
            F_jl = K_jl * U_jl

            # --- Assertions against textbook values ---
            # u2 = 5/34 ≈ 0.14706, u3 = 15/68 ≈ 0.22059, u4 = 25/68 ≈ 0.36765
            @test u_reduced[1] ≈ 5 / 34   rtol=1e-10  # u2
            @test u_reduced[2] ≈ 15 / 68  rtol=1e-10  # u3
            @test u_reduced[3] ≈ 25 / 68  rtol=1e-10  # u4

            @test u_reduced[1] ≈ 0.14705882352941177  rtol=1e-6
            @test u_reduced[2] ≈ 0.22058823529411764  rtol=1e-6
            @test u_reduced[3] ≈ 0.36764705882352944  rtol=1e-6

            # Full displacement vector
            @test U_mat[1] ≈ 0.0
            @test U_mat[2] ≈ 0.14705882352941177  rtol=1e-6
            @test U_mat[3] ≈ 0.22058823529411764  rtol=1e-6
            @test U_mat[4] ≈ 0.36764705882352944  rtol=1e-6

            # Nodal forces (from K*U)
            @test F_mat[1] ≈ -25.0  rtol=1e-6
            @test F_mat[2] ≈ 0.0   atol=1e-10
            @test F_mat[3] ≈ 0.0   atol=1e-10
            @test F_mat[4] ≈ 25.0  rtol=1e-6

            # --- MATLAB and Julia paths produce identical results ---
            @test K_mat ≈ K_jl
            @test u_reduced ≈ u_reduced_jl
            @test U_mat ≈ U_jl
            @test F_mat ≈ F_jl
        end
    end

    # ═══════════════════════════════════════════════════
    # Truss (1D LinearBar / 2D PlaneTruss)
    # ═══════════════════════════════════════════════════
    @testset "Truss" begin

        # ─────────────────────────────────────────────
        # Basic d1_truss (LinearBar) element-level tests
        # ─────────────────────────────────────────────
        @testset "LinearBar element-level" begin
            E, A, L = 1.0, 1.0, 1.0

            # --- Element stiffness matrix ---
            k_mat = LinearBarElementStiffness(E, A, L)
            k_jl  = d1_truss_elementstiffness(E, A, L)

            @test k_mat ≈ [1 -1; -1 1]
            @test k_jl ≈ [1 -1; -1 1]
            @test k_mat ≈ k_jl

            # --- Element forces ---
            u = [1.0; 0.0]
            f_mat = LinearBarElementForces(k_mat, u)
            f_jl  = d1_truss_elementforce(k_jl, u)

            @test f_mat ≈ [1.0; -1.0]
            @test f_jl ≈ [1.0; -1.0]
            @test f_mat ≈ f_jl

            # Zero displacement
            @test LinearBarElementForces(k_mat, [0.0, 0.0]) ≈ [0.0, 0.0]
            @test d1_truss_elementforce(k_jl, [0.0, 0.0]) ≈ [0.0, 0.0]

            # --- Element stresses ---
            sigma_mat = LinearBarElementStresses(k_mat, u, A)
            sigma_jl  = d1_truss_elementstress(k_jl, u, A)

            @test sigma_mat ≈ [1.0; -1.0]
            @test sigma_jl ≈ [1.0; -1.0]
            @test sigma_mat ≈ sigma_jl

            # Zero displacement → zero stress
            @test LinearBarElementStresses(k_mat, [0.0, 0.0], A) ≈ [0.0, 0.0]
            @test d1_truss_elementstress(k_jl, [0.0, 0.0], A) ≈ [0.0, 0.0]

            # --- Assembly ---
            K_mat = zeros(3, 3)
            K_mat = LinearBarAssemble(K_mat, k_mat, 1, 2)
            K_jl = zeros(3, 3)
            K_jl = d1_truss_assemble(K_jl, k_jl, 1, 2)

            K_expected = [1 -1 0; -1 1 0; 0 0 0]
            @test K_mat ≈ K_expected
            @test K_jl ≈ K_expected
            @test K_mat ≈ K_jl

            # --- MATLAB and Julia paths are identical ---
            @test k_mat ≈ k_jl
            @test f_mat ≈ f_jl
            @test sigma_mat ≈ sigma_jl
        end

        # ─────────────────────────────────────────────
        # Problem 5.2 — Plane truss with three elements
        #   and a spring support
        #   (Kattan, Solutions Manual, p. 28)
        # ─────────────────────────────────────────────
        @testset "Problem 5.2" begin
            E = 70e6
            A = 0.01

            # ══════════════════════
            # MATLAB computation path
            # ══════════════════════
            # Element geometries
            L1_mat = PlaneTrussElementLength(0, 0, 4, 3)
            L2_mat = PlaneTrussElementLength(0, 0, 4, 0)
            L3_mat = PlaneTrussElementLength(0, 0, 4, -4)

            theta1 = atan(3, 4) * 180 / pi
            theta2 = 0.0
            theta3 = 360 - atan(4, 4) * 180 / pi

            # Element stiffness matrices
            k1_mat = PlaneTrussElementStiffness(E, A, L1_mat, theta1)
            k2_mat = PlaneTrussElementStiffness(E, A, L2_mat, theta2)
            k3_mat = PlaneTrussElementStiffness(E, A, L3_mat, theta3)

            # Spring stiffness
            k4_mat = SpringElementStiffness(3000)

            # Assemble global stiffness matrix (9×9)
            K_mat = zeros(9, 9)
            K_mat = PlaneTrussAssemble(K_mat, k1_mat, 1, 4)
            K_mat = PlaneTrussAssemble(K_mat, k2_mat, 2, 4)
            K_mat = PlaneTrussAssemble(K_mat, k3_mat, 3, 4)
            K_mat = SpringAssemble(K_mat, k4_mat, 7, 9)

            # Reduced system (DOFs 7, 8, 9)
            K_reduced_mat = K_mat[7:9, 7:9]
            f_reduced = [0.0, 0.0, 10.0]
            u_reduced_mat = K_reduced_mat \ f_reduced

            # Full displacement vector
            U_mat = zeros(9)
            U_mat[7:9] = u_reduced_mat

            # Element nodal displacements
            u1_mat = [U_mat[1]; U_mat[2]; U_mat[7]; U_mat[8]]
            u2_mat = [U_mat[3]; U_mat[4]; U_mat[7]; U_mat[8]]
            u3_mat = [U_mat[5]; U_mat[6]; U_mat[7]; U_mat[8]]

            # Stresses
            sigma1_mat = PlaneTrussElementStress(E, L1_mat, theta1, u1_mat)
            sigma2_mat = PlaneTrussElementStress(E, L2_mat, theta2, u2_mat)
            sigma3_mat = PlaneTrussElementStress(E, L3_mat, theta3, u3_mat)

            # Spring element forces
            u4_mat = [U_mat[7]; U_mat[9]]
            f4_mat = SpringElementForces(k4_mat, u4_mat)

            # ══════════════════════
            # Julia computation path
            # ══════════════════════
            L1_jl = d2_truss_elementlength(0, 0, 4, 3)
            L2_jl = d2_truss_elementlength(0, 0, 4, 0)
            L3_jl = d2_truss_elementlength(0, 0, 4, -4)

            k1_jl = d2_truss_elementstiffness(E, A, L1_jl, theta1)
            k2_jl = d2_truss_elementstiffness(E, A, L2_jl, theta2)
            k3_jl = d2_truss_elementstiffness(E, A, L3_jl, theta3)

            K_jl = zeros(9, 9)
            K_jl = d2_truss_assemble(K_jl, k1_jl, 1, 4)
            K_jl = d2_truss_assemble(K_jl, k2_jl, 2, 4)
            K_jl = d2_truss_assemble(K_jl, k3_jl, 3, 4)
            K_jl = d1_spring_assemble(K_jl, k4_mat, 7, 9)

            K_reduced_jl = K_jl[7:9, 7:9]
            u_reduced_jl = K_reduced_jl \ f_reduced

            U_jl = zeros(9)
            U_jl[7:9] = u_reduced_jl

            u1_jl = [U_jl[1]; U_jl[2]; U_jl[7]; U_jl[8]]
            u2_jl = [U_jl[3]; U_jl[4]; U_jl[7]; U_jl[8]]
            u3_jl = [U_jl[5]; U_jl[6]; U_jl[7]; U_jl[8]]

            sigma1_jl = d2_truss_elementstress(E, L1_jl, theta1, u1_jl)[1]
            sigma2_jl = d2_truss_elementstress(E, L2_jl, theta2, u2_jl)[1]
            sigma3_jl = d2_truss_elementstress(E, L3_jl, theta3, u3_jl)[1]

            # ══════════════════════
            # Assertions
            # ══════════════════════

            # --- Element lengths ---
            @test L1_mat ≈ 5.0
            @test L2_mat ≈ 4.0
            @test L3_mat ≈ 5.6569  rtol=1e-4

            # --- Element stiffness matrices (textbook values) ---
            k1_expected = 1e4 * [8.96  6.72  -8.96  -6.72
                                 6.72  5.04  -6.72  -5.04
                                -8.96 -6.72   8.96   6.72
                                -6.72 -5.04   6.72   5.04]
            @test k1_mat ≈ k1_expected  rtol=1e-4

            k2_expected = [175000      0 -175000      0
                                 0      0       0      0
                           -175000      0  175000      0
                                 0      0       0      0]
            @test k2_mat ≈ k2_expected  rtol=1e-10

            k3_expected = 1e4 * [ 6.1872  -6.1872  -6.1872   6.1872
                                 -6.1872   6.1872   6.1872  -6.1872
                                 -6.1872   6.1872   6.1872  -6.1872
                                  6.1872  -6.1872  -6.1872   6.1872]
            @test k3_mat ≈ k3_expected  rtol=1e-4

            # --- Spring stiffness ---
            @test k4_mat ≈ [3000 -3000; -3000 3000]  rtol=1e-10

            # --- Reduced stiffness matrix (textbook values) ---
            K_reduced_expected = 1e5 * [3.2947   0.0533  -0.0300
                                         0.0533  1.1227   0.0
                                        -0.0300  0.0      0.0300]
            @test K_reduced_mat ≈ K_reduced_expected  rtol=1e-4

            # --- Displacement solution (textbook values, rounded) ---
            @test u_reduced_mat[1] ≈ 0.0     atol=5e-5
            @test u_reduced_mat[2] ≈ 0.0     atol=5e-5
            @test u_reduced_mat[3] ≈ 0.0034  rtol=1.5e-2

            # --- Element stresses (textbook values) ---
            @test sigma1_mat ≈ 331.1075  rtol=1e-6
            @test sigma2_mat ≈ 536.4495  rtol=1e-6
            @test sigma3_mat ≈ 280.9540  rtol=1e-6

            # --- Spring element forces ---
            @test f4_mat[1] ≈ -10.0  rtol=1e-2
            @test f4_mat[2] ≈  10.0  rtol=1e-2

            # ══════════════════════
            # MATLAB vs Julia: exact match
            # ══════════════════════
            @test L1_mat ≈ L1_jl
            @test L2_mat ≈ L2_jl
            @test L3_mat ≈ L3_jl

            @test k1_mat ≈ k1_jl
            @test k2_mat ≈ k2_jl
            @test k3_mat ≈ k3_jl

            @test K_mat ≈ K_jl
            @test K_reduced_mat ≈ K_reduced_jl
            @test u_reduced_mat ≈ u_reduced_jl
            @test U_mat ≈ U_jl

            @test sigma1_mat ≈ sigma1_jl
            @test sigma2_mat ≈ sigma2_jl
            @test sigma3_mat ≈ sigma3_jl

            # Spring force: MATLAB path vs Julia SpringAssemble -> element force
            u4_jl = [U_jl[7]; U_jl[9]]
            f4_jl = d1_spring_elementforce(k4_mat, u4_jl)
            @test f4_mat ≈ f4_jl
        end
    end

    # ═══════════════════════════════════════════════════
    # Beam / Plane Frame (2D Frame)
    # ═══════════════════════════════════════════════════
    @testset "Beam/Frame" begin

        # ─────────────────────────────────────────────
        # Problem 8.1 — Two-element plane frame
        #   (Kattan, Solutions Manual)
        #   E=210e6, A=4e-2, I=4e-6, L=4
        #   Element 1: nodes 1→2, theta=90° (vertical)
        #   Element 2: nodes 2→3, theta=0°  (horizontal)
        # ─────────────────────────────────────────────
        @testset "Problem 8.1" begin
            E = 210e6
            A = 4e-2
            I = 4e-6
            L = 4.0

            # ══════════════════════
            # MATLAB computation path
            # ══════════════════════
            k1_mat = PlaneFrameElementStiffness(E, A, I, L, 90)
            k2_mat = PlaneFrameElementStiffness(E, A, I, L, 0)

            K_mat = zeros(9, 9)
            K_mat = PlaneFrameAssemble(K_mat, k1_mat, 1, 2)
            K_mat = PlaneFrameAssemble(K_mat, k2_mat, 2, 3)

            # Reduced system: DOFs 4,5,6,7,9 (DOF 8 constrained)
            k_reduced_mat = vcat(
                hcat(K_mat[4:7, 4:7], K_mat[4:7, 9]),
                hcat(K_mat[9:9, 4:7], K_mat[9:9, 9]),
            )
            f = [0.0, 0.0, 15.0, 20.0, 0.0]
            u_reduced_mat = k_reduced_mat \ f

            # Full displacement vector
            U_mat = zeros(9)
            U_mat[4] = u_reduced_mat[1]
            U_mat[5] = u_reduced_mat[2]
            U_mat[6] = u_reduced_mat[3]
            U_mat[7] = u_reduced_mat[4]
            U_mat[9] = u_reduced_mat[5]

            # Nodal forces
            F_mat = K_mat * U_mat

            # Element displacements
            u1_mat = U_mat[1:6]
            u2_mat = U_mat[4:9]

            # Element forces
            f1_mat = PlaneFrameElementForces(E, A, I, L, 90, u1_mat)
            f2_mat = PlaneFrameElementForces(E, A, I, L, 0, u2_mat)

            # ══════════════════════
            # Julia computation path
            # ══════════════════════
            k1_jl = d2_beam_elementstiffness(E, A, I, L, 90)
            k2_jl = d2_beam_elementstiffness(E, A, I, L, 0)

            K_jl = zeros(9, 9)
            K_jl = d2_beam_assemble(K_jl, k1_jl, 1, 2)
            K_jl = d2_beam_assemble(K_jl, k2_jl, 2, 3)

            k_reduced_jl = vcat(
                hcat(K_jl[4:7, 4:7], K_jl[4:7, 9]),
                hcat(K_jl[9:9, 4:7], K_jl[9:9, 9]),
            )
            u_reduced_jl = k_reduced_jl \ f

            U_jl = zeros(9)
            U_jl[4] = u_reduced_jl[1]
            U_jl[5] = u_reduced_jl[2]
            U_jl[6] = u_reduced_jl[3]
            U_jl[7] = u_reduced_jl[4]
            U_jl[9] = u_reduced_jl[5]

            F_jl = K_jl * U_jl

            u1_jl = U_jl[1:6]
            u2_jl = U_jl[4:9]

            f1_jl = d2_beam_elementforce(E, A, I, L, 90, u1_jl)
            f2_jl = d2_beam_elementforce(E, A, I, L, 0, u2_jl)

            # ══════════════════════
            # Assertions: MATLAB vs Julia (exact)
            # ══════════════════════
            @test k1_mat ≈ k1_jl  rtol=1e-10
            @test k2_mat ≈ k2_jl  rtol=1e-10
            @test K_mat ≈ K_jl    rtol=1e-10
            @test k_reduced_mat ≈ k_reduced_jl  rtol=1e-10
            @test u_reduced_mat ≈ u_reduced_jl  rtol=1e-10
            @test U_mat ≈ U_jl    rtol=1e-10
            @test F_mat ≈ F_jl    rtol=1e-10
            @test u1_mat ≈ u1_jl  rtol=1e-10
            @test u2_mat ≈ u2_jl  rtol=1e-10
            @test f1_mat ≈ f1_jl  rtol=1e-10
            @test f2_mat ≈ f2_jl  rtol=1e-10

            # ══════════════════════
            # Assertions: textbook values (rounded)
            # ══════════════════════
            # Reduced displacements
            @test u_reduced_mat[1] ≈ 0.1865  rtol=1e-3
            @test u_reduced_mat[2] ≈ 0.0     atol=1e-5
            @test u_reduced_mat[3] ≈ -0.0298 atol=5e-5
            @test u_reduced_mat[4] ≈ 0.1865  rtol=1e-3
            @test u_reduced_mat[5] ≈ 0.0149  atol=5e-5

            # Nodal forces
            @test F_mat[1] ≈ -20.0      rtol=1e-4
            @test F_mat[2] ≈ -4.6875    rtol=1e-4
            @test F_mat[3] ≈ 46.2501    rtol=1e-4
            @test F_mat[4] ≈ 0.0        atol=1e-10
            @test F_mat[5] ≈ 0.0        atol=1e-10
            @test F_mat[6] ≈ 15.0       rtol=1e-10
            @test F_mat[7] ≈ 20.0       rtol=1e-4
            @test F_mat[8] ≈ 4.6875     rtol=1e-4
            @test F_mat[9] ≈ 0.0        atol=1e-10

            # Element forces
            @test f1_mat[1] ≈ -4.6875   rtol=1e-4
            @test f1_mat[2] ≈ 20.0      rtol=1e-10
            @test f1_mat[3] ≈ 46.2501   rtol=1e-4
            @test f1_mat[4] ≈ 4.6875    rtol=1e-4
            @test f1_mat[5] ≈ -20.0     rtol=1e-10
            @test f1_mat[6] ≈ 33.7499   rtol=1e-5

            @test f2_mat[1] ≈ -20.0     rtol=1e-10
            @test f2_mat[2] ≈ -4.6875   rtol=1e-4
            @test f2_mat[3] ≈ -18.7499  rtol=1e-5
            @test f2_mat[4] ≈ 20.0      rtol=1e-10
            @test f2_mat[5] ≈ 4.6875    rtol=1e-4
            @test f2_mat[6] ≈ 0.0       atol=1e-10
        end

        # ─────────────────────────────────────────────
        # Diagram function tests — verify z-vector
        # ─────────────────────────────────────────────
        @testset "Diagram functions" begin
            f = [1000.0, 500.0, 200.0, -1000.0, 500.0, -200.0]
            L = 5.0

            # Axial: z = [-f₁, f₄]
            @test PlaneFrameElementAxialDiagram(f, L) ≈ [-1000.0, -1000.0]
            @test PlaneFrameElementAxialDiagram(f, L) == [-f[1], f[4]]

            # Shear: z = [f₂, -f₅]
            @test PlaneFrameElementShearDiagram(f, L) ≈ [500.0, -500.0]
            @test PlaneFrameElementShearDiagram(f, L) == [f[2], -f[5]]

            # Moment: z = [-f₃, f₆]
            @test PlaneFrameElementMomentDiagram(f, L) ≈ [-200.0, -200.0]
            @test PlaneFrameElementMomentDiagram(f, L) == [-f[3], f[6]]

            # Zero force → zero diagram
            f0 = zeros(6)
            @test PlaneFrameElementAxialDiagram(f0, L) == [0.0, 0.0]
            @test PlaneFrameElementShearDiagram(f0, L) == [0.0, 0.0]
            @test PlaneFrameElementMomentDiagram(f0, L) == [0.0, 0.0]
        end
    end

    # ═════════════════════════════════════════════════
    # Julia-only extensions — strain, identity checks
    # ═════════════════════════════════════════════════
    @testset "Julia-only extensions" begin

        # ─────────────────────────────────────────────
        # d1_truss_elementstrain — 1/L * u (vector)
        # ─────────────────────────────────────────────
        @testset "d1_truss_elementstrain" begin
            L, E, A = 1.0, 1.0, 1.0
            u = [1.0, 0.0]
            strain = d1_truss_elementstrain(L, u)
            @test strain ≈ [1.0, 0.0]
            # Cross-check with stress/E identity
            k = d1_truss_elementstiffness(E, A, L)
            stress = d1_truss_elementstress(k, u, A)
            stress_div_E = stress / E
            @test stress_div_E ≈ [1.0, -1.0]
            # strain (simplified formula) ≠ stress/E
            @test strain != stress_div_E
            # zero displacement
            @test d1_truss_elementstrain(L, [0.0, 0.0]) ≈ [0.0, 0.0]
        end

        # ─────────────────────────────────────────────
        # d2_truss_elementstrain — 1/L*[-C -S C S]*u (scalar)
        # ─────────────────────────────────────────────
        @testset "d2_truss_elementstrain" begin
            L, E = 1.0, 1.0
            theta = 0.0
            u = [1.0, 0.0, 0.0, 0.0]
            strain = d2_truss_elementstrain(L, theta, u)
            @test strain[1] ≈ -1.0
            # Verify stress/E = strain
            stress = d2_truss_elementstress(E, L, theta, u)
            @test stress / E ≈ strain
            # 45 deg
            theta45 = 45.0
            u45 = [1.0, 0.0, 0.0, 0.0]
            @test d2_truss_elementstrain(L, theta45, u45)[1] ≈ -cos(π/4)
            # Theta = 90 deg
            @test d2_truss_elementstrain(L, 90.0, [0.0, 1.0, 0.0, 0.0])[1] ≈ -1.0
            # zero displacement
            @test d2_truss_elementstrain(L, theta, zeros(4))[1] ≈ 0.0
        end

        # ─────────────────────────────────────────────
        # d2_spring/d2_truss identity (E*A/L = k)
        # ─────────────────────────────────────────────
        @testset "d2_spring/d2_truss identity" begin
            E, A, L = 1.0, 1.0, 1.0
            k = E * A / L  # = 1
            theta = 30.0
            u = [0.1, 0.2, 0.3, 0.4]

            # Stiffness identity
            K_spring = d2_spring_elementstiffness(k, theta)
            K_truss  = d2_truss_elementstiffness(E, A, L, theta)
            @test K_spring ≈ K_truss rtol=1e-10

            # Force identity
            f_spring = d2_spring_elementforce(k, theta, u)
            f_truss  = d2_truss_elementforce(E, A, L, theta, u)
            @test f_spring[1] ≈ f_truss[1] rtol=1e-10

            # Theta = 0 (horizontal)
            K_spring0 = d2_spring_elementstiffness(k, 0.0)
            K_truss0  = d2_truss_elementstiffness(E, A, L, 0.0)
            @test K_spring0 ≈ K_truss0 rtol=1e-10

            # Theta = 90 (vertical)
            K_spring90 = d2_spring_elementstiffness(k, 90.0)
            K_truss90  = d2_truss_elementstiffness(E, A, L, 90.0)
            @test K_spring90 ≈ K_truss90 rtol=1e-10
        end

    end

    # ═════════════════════════════════════════════════
    # Edge case sweep
    # ═════════════════════════════════════════════════
    @testset "Edge cases" begin

        # ─────────────────────────────────────────────
        # Zero stiffness — all matrices → zero
        # ─────────────────────────────────────────────
        @testset "Zero stiffness" begin
            E, A, L = 0.0, 1.0, 1.0
            @test d1_truss_elementstiffness(E, A, L) == zeros(2, 2)
            @test d1_spring_elementstiffness(0.0) == zeros(2, 2)
            @test d2_spring_elementstiffness(0.0, 45.0) == zeros(4, 4)
            # non-zero sanity check
            @test d2_truss_elementstiffness(1.0, 1.0, 1.0, 45.0) != zeros(4, 4)
            # Zero-stiffness forces
            f1 = d1_truss_elementforce(d1_truss_elementstiffness(0, 1, 1), [1.0, 2.0])
            @test f1 ≈ [0.0, 0.0]
            f2 = d1_spring_elementforce(d1_spring_elementstiffness(0), [1.0, 2.0])
            @test f2 ≈ [0.0, 0.0]
        end

        # ─────────────────────────────────────────────
        # Theta extremes — no NaN, periodicity
        # ─────────────────────────────────────────────
        @testset "Theta extremes" begin
            # 0°, 90°, 180°, 360° — no NaN
            k0 = nothing
            for theta in (0, 90, 180, 360, -90, -45)
                k = d2_truss_elementstiffness(1.0, 1.0, 1.0, theta)
                @test all(!isnan, k)
                k2 = d2_spring_elementstiffness(1.0, theta)
                @test all(!isnan, k2)
                if theta == 0
                    k0 = copy(k)
                elseif theta == 360
                    @test k ≈ k0 rtol=1e-10
                end
            end
            # Negative theta periodicity: -45° ≡ 315°
            @test d2_truss_elementstiffness(1.0, 1.0, 1.0, -45) ≈
                  d2_truss_elementstiffness(1.0, 1.0, 1.0, 315) rtol=1e-10
            @test d2_spring_elementstiffness(1.0, -45) ≈
                  d2_spring_elementstiffness(1.0, 315) rtol=1e-10
        end

        # ─────────────────────────────────────────────
        # Boundary node indices for assemble
        # ─────────────────────────────────────────────
        @testset "Boundary node indices" begin
            K = zeros(10, 10)
            k_s = d1_spring_elementstiffness(100.0)
            # Low indices
            r1 = d1_spring_assemble(copy(K), k_s, 1, 2)
            @test r1 != zeros(10, 10)
            @test r1[1, 1] ≈ 100.0
            # High indices (within bounds)
            r2 = d1_spring_assemble(copy(K), k_s, 9, 10)
            @test r2 != zeros(10, 10)
            @test r2[9, 9] ≈ 100.0
            # d2 indices
            K4 = zeros(8, 8)
            k2 = d2_spring_elementstiffness(100.0, 0.0)
            r3 = d2_spring_assemble(copy(K4), k2, 1, 2)
            @test r3 != zeros(8, 8)
            r4 = d2_spring_assemble(copy(K4), k2, 3, 4)
            @test r4[5:6, 5:6] != zeros(2, 2)
        end

        # ─────────────────────────────────────────────
        # Zero displacement → zero force
        # ─────────────────────────────────────────────
        @testset "Zero displacement → zero force" begin
            u0 = [0.0, 0.0]
            u0_4 = zeros(4)
            # d1 functions
            @test d1_spring_elementforce([1.0 0.0; 0.0 1.0], u0) ≈ [0.0, 0.0]
            k1 = d1_truss_elementstiffness(1.0, 1.0, 1.0)
            @test d1_truss_elementforce(k1, u0) ≈ [0.0, 0.0]
            # d2 functions
            @test d2_spring_elementforce(1.0, 45.0, u0_4)[1] ≈ 0.0
            @test d2_truss_elementforce(1.0, 1.0, 1.0, 45.0, u0_4)[1] ≈ 0.0
            # strain/stress with zero displacement
            @test d1_truss_elementstrain(1.0, u0) ≈ [0.0, 0.0]
            @test d2_truss_elementstrain(1.0, 0.0, u0_4)[1] ≈ 0.0
        end

    end

end  # @testset "MATLAB comparison"
