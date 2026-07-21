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
vector u (2-element). Identical to `d1_truss_elementforces(k, u)`.
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
    x = LibFEM.deg2rad(theta)
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
MATLAB returns a scalar; Julia's `d2_truss_elementforces` returns a 1-element Vector.
"""
function PlaneTrussElementForce(E, A, L, theta, u)
    x = LibFEM.deg2rad(theta)
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
    x = LibFEM.deg2rad(theta)
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
    x = LibFEM.deg2rad(theta)
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
vector u. Identical to `d2_beam_elementforces(E, A, I, L, theta, u)`.
"""
function PlaneFrameElementForces(E, A, I, L, theta, u)
    x = LibFEM.deg2rad(theta)
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
# MATLAB Reference Implementations (SpaceFrame / 3D Beam)
# Transcribed from Doc/Kattan/M-Files/ (read-only)
# ─────────────────────────────────────────────────

"""
    SpaceFrameElementLength(x1, y1, z1, x2, y2, z2) -> Real

MATLAB reference: returns the length of a space frame element between
coordinates (x1,y1,z1) and (x2,y2,z2).
Identical to `d3_beam_elementlength(x1, y1, z1, x2, y2, z2)`.
"""
function SpaceFrameElementLength(x1, y1, z1, x2, y2, z2)
    return sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

"""
    SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2) -> Matrix

MATLAB reference: returns the 12×12 element stiffness matrix for a space frame
element. Identical to `d3_beam_elementstiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)`.
"""
function SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2)
    L = SpaceFrameElementLength(x1, y1, z1, x2, y2, z2)
    w1 = E * A / L
    w2 = 12 * E * Iz / (L^3)
    w3 = 6 * E * Iz / (L^2)
    w4 = 4 * E * Iz / L
    w5 = 2 * E * Iz / L
    w6 = 12 * E * Iy / (L^3)
    w7 = 6 * E * Iy / (L^2)
    w8 = 4 * E * Iy / L
    w9 = 2 * E * Iy / L
    w10 = G * J / L
    kprime = [
        w1   0    0    0    0    0   -w1   0    0    0    0    0
        0   w2   0    0    0    w3   0   -w2   0    0    0    w3
        0    0   w6   0   -w7   0    0    0   -w6   0   -w7   0
        0    0    0   w10   0    0    0    0    0   -w10  0    0
        0    0   -w7   0   w8    0    0    0    w7   0    w9   0
        0    w3   0    0    0    w4   0   -w3   0    0    0    w5
       -w1   0    0    0    0    0    w1   0    0    0    0    0
        0   -w2   0    0    0   -w3   0    w2   0    0    0   -w3
        0    0   -w6   0    w7    0    0    0    w6   0    w7   0
        0    0    0   -w10  0    0    0    0    0    w10   0    0
        0    0   -w7   0    w9    0    0    0    w7   0    w8   0
        0    w3   0    0    0    w5   0   -w3   0    0    0    w4
    ]
    Cx = (x2 - x1) / L
    Cy = (y2 - y1) / L
    Cz = (z2 - z1) / L
    if x1 == x2 && y1 == y2
        if z2 > z1
            Lambda = [0 0 1; 0 1 0; -1 0 0]
        else
            Lambda = [0 0 -1; 0 1 0; 1 0 0]
        end
    else
        D = sqrt(Cx^2 + Cy^2)
        Lambda = [
            Cx       Cy       Cz
            -Cy / D   Cx / D   0
            -Cx * Cz / D  -Cy * Cz / D  D
        ]
    end
    Z33 = zeros(3, 3)
    R = [Lambda Z33 Z33 Z33; Z33 Lambda Z33 Z33; Z33 Z33 Lambda Z33; Z33 Z33 Z33 Lambda]
    return R' * kprime * R
end

"""
    SpaceFrameAssemble(K, k, i, j) -> Matrix

MATLAB reference: assembles the 12×12 element stiffness matrix k of a space
frame element with nodes i and j into the global stiffness matrix K (6 DOF/node).
Returns the updated global matrix.
Identical to `d3_beam_assemble(K, k, i, j)`.
"""
function SpaceFrameAssemble(K, k, i, j)
    for a in 1:6, b in 1:6
        K[6*i-6+a, 6*i-6+b] += k[a, b]     # (i, i)
        K[6*i-6+a, 6*j-6+b] += k[a, b+6]   # (i, j)
        K[6*j-6+a, 6*i-6+b] += k[a+6, b]   # (j, i)
        K[6*j-6+a, 6*j-6+b] += k[a+6, b+6] # (j, j)
    end
    return K
end

"""
    SpaceFrameElementForces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u) -> Vector

MATLAB reference: returns the 12-element element force vector for a space frame
element. Identical to `d3_beam_elementforces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)`.
"""
function SpaceFrameElementForces(E, G, A, Iy, Iz, J, x1, y1, z1, x2, y2, z2, u)
    L = SpaceFrameElementLength(x1, y1, z1, x2, y2, z2)
    w1 = E * A / L
    w2 = 12 * E * Iz / (L^3)
    w3 = 6 * E * Iz / (L^2)
    w4 = 4 * E * Iz / L
    w5 = 2 * E * Iz / L
    w6 = 12 * E * Iy / (L^3)
    w7 = 6 * E * Iy / (L^2)
    w8 = 4 * E * Iy / L
    w9 = 2 * E * Iy / L
    w10 = G * J / L
    kprime = [
        w1   0    0    0    0    0   -w1   0    0    0    0    0
        0   w2   0    0    0    w3   0   -w2   0    0    0    w3
        0    0   w6   0   -w7   0    0    0   -w6   0   -w7   0
        0    0    0   w10   0    0    0    0    0   -w10  0    0
        0    0   -w7   0   w8    0    0    0    w7   0    w9   0
        0    w3   0    0    0    w4   0   -w3   0    0    0    w5
       -w1   0    0    0    0    0    w1   0    0    0    0    0
        0   -w2   0    0    0   -w3   0    w2   0    0    0   -w3
        0    0   -w6   0    w7    0    0    0    w6   0    w7   0
        0    0    0   -w10  0    0    0    0    0    w10   0    0
        0    0   -w7   0    w9    0    0    0    w7   0    w8   0
        0    w3   0    0    0    w5   0   -w3   0    0    0    w4
    ]
    Cx = (x2 - x1) / L
    Cy = (y2 - y1) / L
    Cz = (z2 - z1) / L
    if x1 == x2 && y1 == y2
        if z2 > z1
            Lambda = [0 0 1; 0 1 0; -1 0 0]
        else
            Lambda = [0 0 -1; 0 1 0; 1 0 0]
        end
    else
        D = sqrt(Cx^2 + Cy^2)
        Lambda = [
            Cx       Cy       Cz
            -Cy / D   Cx / D   0
            -Cx * Cz / D  -Cy * Cz / D  D
        ]
    end
    Z33 = zeros(3, 3)
    R = [Lambda Z33 Z33 Z33; Z33 Lambda Z33 Z33; Z33 Z33 Lambda Z33; Z33 Z33 Z33 Lambda]
    return kprime * R * u
end

"""
    SpaceFrameElementAxialDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the axial force diagram
(z = [-f[1], f[7]]) for a space frame element with nodal force vector f
and length L. (Returns data only, no plot.)
Identical to the data portion of `d3_beam_elementaxialdiagram(f, L)`.
"""
function SpaceFrameElementAxialDiagram(f, L)
    return [-f[1], f[7]]
end

"""
    SpaceFrameElementShearYDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the shear force Y diagram
(z = [f[2], -f[8]]). (Returns data only, no plot.)
"""
function SpaceFrameElementShearYDiagram(f, L)
    return [f[2], -f[8]]
end

"""
    SpaceFrameElementShearZDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the shear force Z diagram
(z = [f[3], -f[9]]). (Returns data only, no plot.)
"""
function SpaceFrameElementShearZDiagram(f, L)
    return [f[3], -f[9]]
end

"""
    SpaceFrameElementMomentYDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the bending moment Y diagram
(z = [f[5], -f[11]]). (Returns data only, no plot.)
"""
function SpaceFrameElementMomentYDiagram(f, L)
    return [f[5], -f[11]]
end

"""
    SpaceFrameElementMomentZDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the bending moment Z diagram
(z = [f[6], -f[12]]). (Returns data only, no plot.)
"""
function SpaceFrameElementMomentZDiagram(f, L)
    return [f[6], -f[12]]
end

"""
    SpaceFrameElementTorsionDiagram(f, L) -> Vector

MATLAB reference: returns the z-vector of the torsion diagram
(z = [f[4], -f[10]]). (Returns data only, no plot.)
"""
function SpaceFrameElementTorsionDiagram(f, L)
    return [f[4], -f[10]]
end

# ─────────────────────────────────────────────────
# MATLAB Reference Implementations (SpaceTruss / 3D Truss)
# Transcribed from Doc/Kattan/M-Files/ (read-only)
# ─────────────────────────────────────────────────

"""
    SpaceTrussElementLength(x1, y1, z1, x2, y2, z2) -> Real

MATLAB reference: returns the length of a space truss element between
coordinates (x1, y1, z1) and (x2, y2, z2).
Identical to `d3_truss_elementlength(x1, y1, z1, x2, y2, z2)`.
"""
function SpaceTrussElementLength(x1, y1, z1, x2, y2, z2)
    return sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2)
end

"""
    SpaceTrussElementStiffness(E, A, L, thetax, thetay, thetaz) -> Matrix

MATLAB reference: returns the 6×6 element stiffness matrix for a space
truss element with modulus of elasticity E, cross-sectional area A,
length L, and angles thetax, thetay, thetaz (in degrees).
Identical to `d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)`.
"""
function SpaceTrussElementStiffness(E, A, L, thetax, thetay, thetaz)
    x = thetax * π / 180
    u = thetay * π / 180
    v = thetaz * π / 180
    Cx = cos(x)
    Cy = cos(u)
    Cz = cos(v)
    w = [
        Cx * Cx  Cx * Cy  Cx * Cz
        Cy * Cx  Cy * Cy  Cy * Cz
        Cz * Cx  Cz * Cy  Cz * Cz
    ]
    return E * A / L * [w -w; -w w]
end

"""
    SpaceTrussElementForce(E, A, L, thetax, thetay, thetaz, u) -> Real

MATLAB reference: returns the scalar element force given the modulus
of elasticity E, cross-sectional area A, length L, angles thetax,
thetay, thetaz (in degrees), and element nodal displacement vector u.
MATLAB returns a scalar; Julia's `d3_truss_elementforces` returns a 1-element Vector.
"""
function SpaceTrussElementForce(E, A, L, thetax, thetay, thetaz, u)
    x = thetax * π / 180
    u_ = thetay * π / 180
    v = thetaz * π / 180
    Cx = cos(x)
    Cy = cos(u_)
    Cz = cos(v)
    return first(E * A / L * [-Cx -Cy -Cz Cx Cy Cz] * u)
end

"""
    SpaceTrussElementStress(E, L, thetax, thetay, thetaz, u) -> Real

MATLAB reference: returns the scalar element stress given the modulus
of elasticity E, length L, angles thetax, thetay, thetaz (in degrees),
and element nodal displacement vector u.
MATLAB returns a scalar; Julia's `d3_truss_elementstress` returns a 1-element Vector.
"""
function SpaceTrussElementStress(E, L, thetax, thetay, thetaz, u)
    x = thetax * π / 180
    u_ = thetay * π / 180
    v = thetaz * π / 180
    Cx = cos(x)
    Cy = cos(u_)
    Cz = cos(v)
    return first(E / L * [-Cx -Cy -Cz Cx Cy Cz] * u)
end

"""
    SpaceTrussAssemble(K, k, i, j) -> Matrix

MATLAB reference: assembles the 6×6 element stiffness matrix k of a
space truss with nodes i and j into the global stiffness matrix K
using 3-DOF indexing (3i-2, 3i-1, 3i). Returns the updated global matrix.
Identical to `d3_truss_assemble(K, k, i, j)`.
"""
function SpaceTrussAssemble(K, k, i, j)
    K[3 * i - 2, 3 * i - 2] = K[3 * i - 2, 3 * i - 2] + k[1, 1]
    K[3 * i - 2, 3 * i - 1] = K[3 * i - 2, 3 * i - 1] + k[1, 2]
    K[3 * i - 2, 3 * i]     = K[3 * i - 2, 3 * i]     + k[1, 3]
    K[3 * i - 2, 3 * j - 2] = K[3 * i - 2, 3 * j - 2] + k[1, 4]
    K[3 * i - 2, 3 * j - 1] = K[3 * i - 2, 3 * j - 1] + k[1, 5]
    K[3 * i - 2, 3 * j]     = K[3 * i - 2, 3 * j]     + k[1, 6]
    K[3 * i - 1, 3 * i - 2] = K[3 * i - 1, 3 * i - 2] + k[2, 1]
    K[3 * i - 1, 3 * i - 1] = K[3 * i - 1, 3 * i - 1] + k[2, 2]
    K[3 * i - 1, 3 * i]     = K[3 * i - 1, 3 * i]     + k[2, 3]
    K[3 * i - 1, 3 * j - 2] = K[3 * i - 1, 3 * j - 2] + k[2, 4]
    K[3 * i - 1, 3 * j - 1] = K[3 * i - 1, 3 * j - 1] + k[2, 5]
    K[3 * i - 1, 3 * j]     = K[3 * i - 1, 3 * j]     + k[2, 6]
    K[3 * i,     3 * i - 2] = K[3 * i,     3 * i - 2] + k[3, 1]
    K[3 * i,     3 * i - 1] = K[3 * i,     3 * i - 1] + k[3, 2]
    K[3 * i,     3 * i]     = K[3 * i,     3 * i]     + k[3, 3]
    K[3 * i,     3 * j - 2] = K[3 * i,     3 * j - 2] + k[3, 4]
    K[3 * i,     3 * j - 1] = K[3 * i,     3 * j - 1] + k[3, 5]
    K[3 * i,     3 * j]     = K[3 * i,     3 * j]     + k[3, 6]
    K[3 * j - 2, 3 * i - 2] = K[3 * j - 2, 3 * i - 2] + k[4, 1]
    K[3 * j - 2, 3 * i - 1] = K[3 * j - 2, 3 * i - 1] + k[4, 2]
    K[3 * j - 2, 3 * i]     = K[3 * j - 2, 3 * i]     + k[4, 3]
    K[3 * j - 2, 3 * j - 2] = K[3 * j - 2, 3 * j - 2] + k[4, 4]
    K[3 * j - 2, 3 * j - 1] = K[3 * j - 2, 3 * j - 1] + k[4, 5]
    K[3 * j - 2, 3 * j]     = K[3 * j - 2, 3 * j]     + k[4, 6]
    K[3 * j - 1, 3 * i - 2] = K[3 * j - 1, 3 * i - 2] + k[5, 1]
    K[3 * j - 1, 3 * i - 1] = K[3 * j - 1, 3 * i - 1] + k[5, 2]
    K[3 * j - 1, 3 * i]     = K[3 * j - 1, 3 * i]     + k[5, 3]
    K[3 * j - 1, 3 * j - 2] = K[3 * j - 1, 3 * j - 2] + k[5, 4]
    K[3 * j - 1, 3 * j - 1] = K[3 * j - 1, 3 * j - 1] + k[5, 5]
    K[3 * j - 1, 3 * j]     = K[3 * j - 1, 3 * j]     + k[5, 6]
    K[3 * j,     3 * i - 2] = K[3 * j,     3 * i - 2] + k[6, 1]
    K[3 * j,     3 * i - 1] = K[3 * j,     3 * i - 1] + k[6, 2]
    K[3 * j,     3 * i]     = K[3 * j,     3 * i]     + k[6, 3]
    K[3 * j,     3 * j - 2] = K[3 * j,     3 * j - 2] + k[6, 4]
    K[3 * j,     3 * j - 1] = K[3 * j,     3 * j - 1] + k[6, 5]
    K[3 * j,     3 * j]     = K[3 * j,     3 * j]     + k[6, 6]
    return K
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

        # ═══════════════════════════════════════════════════════════
        # 2D Spring Full Problem — Horizontal + Vertical springs
        #   Verified against analytical solution (no MATLAB ref)
        #   Uses cross-configuration (θ=0° and θ=90°) for a
        #   well-constrained 2D system.
        # ═══════════════════════════════════════════════════════════
        @testset "2D Spring Full Problem" begin
            # Problem: 3 nodes, 2 orthogonal springs
            #   Node 1: (0,0), fixed (u1x=0, u1y=0)
            #   Node 2: (1,0)
            #   Node 3: (1,1), fixed (u3x=0, u3y=0)
            #
            #   Element 1: k=200, θ=0°  (horizontal), nodes 1→2
            #   Element 2: k=100, θ=90° (vertical),   nodes 2→3
            #
            #   Force at node 2: f2x=10, f2y=5
            #
            # Analytical (uncoupled x/y stiffness):
            #   u2x = f2x / k1 = 10 / 200 = 0.05
            #   u2y = f2y / k2 =  5 / 100 = 0.05
            #   Element 1 force  = k1 · u2x = 200·0.05 = 10 (tension)
            #   Element 2 force  = k2 · (u3y − u2y) = 100·(0−0.05) = −5 (compression)

            # --- Element stiffness matrices ---
            ke1 = d2_spring_elementstiffness(200.0, 0.0)
            ke2 = d2_spring_elementstiffness(100.0, 90.0)

            @test size(ke1) == (4, 4)
            @test size(ke2) == (4, 4)
            @test ke1 ≈ ke1'
            @test ke2 ≈ ke2'

            # --- Expected stiffness entries ---
            # θ=0°:  C=1, S=0 → ke = 200·[1 0 -1 0; 0 0 0 0; -1 0 1 0; 0 0 0 0]
            @test ke1[1, 1] ≈ 200.0
            @test ke1[1, 3] ≈ -200.0
            @test ke1[3, 1] ≈ -200.0
            @test ke1[3, 3] ≈ 200.0
            @test all(ke1[2, :] .≈ 0.0)
            @test all(ke1[4, :] .≈ 0.0)
            @test all(ke1[:, 2] .≈ 0.0)
            @test all(ke1[:, 4] .≈ 0.0)

            # θ=90°: C=0, S=1 → ke = 100·[0 0 0 0; 0 1 0 -1; 0 0 0 0; 0 -1 0 1]
            # Note: cos(90°) ≈ 6.12e-17 in floating-point → near-zero entries use atol
            @test ke2[2, 2] ≈ 100.0
            @test ke2[2, 4] ≈ -100.0
            @test ke2[4, 2] ≈ -100.0
            @test ke2[4, 4] ≈ 100.0
            @test maximum(abs.(ke2[1, :])) < 1e-12
            @test maximum(abs.(ke2[3, :])) < 1e-12

            # --- Assemble global stiffness (3 nodes × 2 DOF = 6×6) ---
            K = zeros(6, 6)
            K = d2_spring_assemble(K, ke1, 1, 2)
            K = d2_spring_assemble(K, ke2, 2, 3)

            @test size(K) == (6, 6)
            @test K ≈ K'

            # Expected K matrix (manual assembly verification)
            #   K[1,1] = 200,  K[1,3] = -200     (elem 1: node 1→2, x only)
            #   K[3,1] = -200, K[3,3] = 200       (elem 1: node 2→1, x only)
            #   K[4,4] = 100,  K[4,6] = -100     (elem 2: node 2→3, y only)
            #   K[6,4] = -100, K[6,6] = 100       (elem 2: node 3→2, y only)
            K_expected = [200.0   0.0  -200.0   0.0    0.0    0.0
                            0.0   0.0     0.0   0.0    0.0    0.0
                         -200.0   0.0   200.0   0.0    0.0    0.0
                            0.0   0.0     0.0 100.0    0.0 -100.0
                            0.0   0.0     0.0   0.0    0.0    0.0
                            0.0   0.0     0.0 -100.0    0.0  100.0]
            @test K ≈ K_expected

            # --- Apply BCs and solve ---
            # Remove DOFs 1,2 (node 1 fixed) and DOFs 5,6 (node 3 fixed)
            retained = [3, 4]  # u2x, u2y
            K_reduced = K[retained, retained]

            f_reduced = [10.0, 5.0]  # f2x=10, f2y=5

            u_reduced = K_reduced \ f_reduced
            @test u_reduced[1] ≈ 0.05  # u2x = 10/200
            @test u_reduced[2] ≈ 0.05  # u2y = 5/100

            # Full displacement vector
            U = zeros(6)
            U[3] = u_reduced[1]
            U[4] = u_reduced[2]
            F = K * U

            @test U[3] ≈ 0.05
            @test U[4] ≈ 0.05

            # --- Reaction forces ---
            # Equilibrium: F1x + f2x = 0, F1y + f2y + F3y = 0
            @test F[1] ≈ -10.0           # F1x = -f2x
            @test F[2] ≈   0.0  atol=1e-15
            @test F[5] ≈   0.0  atol=1e-15
            @test F[6] ≈  -5.0           # F3y = -f2y

            # --- Internal element forces (scalar, positive = tension) ---
            u_elem1 = [U[1], U[2], U[3], U[4]]
            u_elem2 = [U[3], U[4], U[5], U[6]]

            f_elem1 = d2_spring_elementforce(200.0, 0.0, u_elem1)  # 1-element vector
            f_elem2 = d2_spring_elementforce(100.0, 90.0, u_elem2)

            @test length(f_elem1) == 1
            @test length(f_elem2) == 1
            @test f_elem1[1] ≈ 10.0   # tension (stretch = 0.05)
            @test f_elem2[1] ≈ -5.0   # compression (u3y < u2y)

            # --- Element stiffness × displacement = nodal forces ---
            # Element 1: horizontal spring
            f_elem1_nodal = ke1 * u_elem1
            @test f_elem1_nodal[1] ≈ -10.0  # force on node 1 in x
            @test f_elem1_nodal[2] ≈   0.0  # no y-force
            @test f_elem1_nodal[3] ≈  10.0  # force on node 2 in x
            @test f_elem1_nodal[4] ≈   0.0  # no y-force

            # Element 2: vertical spring
            f_elem2_nodal = ke2 * u_elem2
            @test f_elem2_nodal[1] ≈  0.0   atol=1e-15
            @test f_elem2_nodal[2] ≈  5.0           # force on node 2 in y
            @test f_elem2_nodal[3] ≈  0.0   atol=1e-15
            @test f_elem2_nodal[4] ≈ -5.0           # force on node 3 in y
        end

        # ═══════════════════════════════════════════════════════════
        # 3D Spring Full Problem — Two springs along x-axis
        #   Verified against analytical solution (no MATLAB ref)
        # ═══════════════════════════════════════════════════════════
        @testset "3D Spring Full Problem" begin
            # Problem: 3 nodes, 2 elements, 3 DOF/node
            #   Node 1 (0,0,0) --k1=200-- Node 2 --k2=250-- Node 3
            #   Springs along x-axis: thetax=0°, thetay=90°, thetaz=90°
            #     → Cx=1, Cy=0, Cz=0 → only x-direction stiffness
            #   BCs: Node 1 fixed (all DOFs), Node 3 fixed (all DOFs)
            #        Node 2 y/z fixed, F2x = 10
            #
            # Analytical (reduces to 1D along x-direction):
            #   Equivalent stiffness at node 2: k_eq = k1 + k2 = 450
            #   u2x = F/k_eq = 10/450 = 1/45 ≈ 0.02222
            #   Reaction at node 1: -k1·u2x = -40/9 ≈ -4.444
            #   Reaction at node 3: -k2·u2x = -50/9 ≈ -5.556
            #   Element 1 force: k1·u2x = 40/9 ≈ 4.444 (tension)
            #   Element 2 force: -k2·u2x = -50/9 ≈ -5.556 (compression)

            k1 = 200.0
            k2 = 250.0
            θx, θy, θz = 0.0, 90.0, 90.0
            Cx, Cy, Cz = 1.0, 0.0, 0.0

            # --- Element stiffness matrices (6×6) ---
            ke1 = d3_spring_elementstiffness(k1, θx, θy, θz)
            ke2 = d3_spring_elementstiffness(k2, θx, θy, θz)

            @test size(ke1) == (6, 6)
            @test size(ke2) == (6, 6)
            @test ke1 ≈ ke1'
            @test ke2 ≈ ke2'

            # Expected element structure: k*[w -w; -w w] where w = [Cx² 0 0; 0 0 0; 0 0 0]
            @test ke1[1, 1] ≈ k1 * Cx^2
            @test ke1[1, 4] ≈ -k1 * Cx^2
            @test ke1[4, 4] ≈ k1 * Cx^2
            @test ke2[1, 1] ≈ k2 * Cx^2
            @test ke2[1, 4] ≈ -k2 * Cx^2
            @test ke2[4, 4] ≈ k2 * Cx^2

            # --- Assemble global stiffness (3 nodes × 3 DOF = 9×9) ---
            K = zeros(9, 9)
            K = d3_spring_assemble(K, ke1, 1, 2)
            K = d3_spring_assemble(K, ke2, 2, 3)

            @test size(K) == (9, 9)
            @test K ≈ K'

            # Verify key entries (only x-direction DOFs have stiffness)
            @test K[1, 1] ≈ k1                     # node 1x from element 1
            @test K[1, 4] ≈ -k1                    # node 1x-2x coupling
            @test K[4, 1] ≈ -k1                    # symmetry
            @test K[4, 4] ≈ k1 + k2                # node 2x from both elements
            @test K[4, 7] ≈ -k2                    # node 2x-3x coupling
            @test K[7, 4] ≈ -k2                    # symmetry
            @test K[7, 7] ≈ k2                     # node 3x from element 2

            # y and z directions are uncoupled (only floating-point noise from cos(π/2))
            @test maximum(abs.(K[2:3, :])) < 1e-12
            @test maximum(abs.(K[5:6, :])) < 1e-12
            @test maximum(abs.(K[8:9, :])) < 1e-12

            # --- Apply BCs and solve ---
            # Free DOF: node 2 x (DOF 4)
            K_reduced = K[4:4, 4:4]  # 1×1
            f_reduced = [10.0]
            u2x = K_reduced \ f_reduced
            u2x_exp = 10.0 / (k1 + k2)  # = 1/45 ≈ 0.022222...

            @test u2x[1] ≈ u2x_exp  rtol=1e-10
            @test u2x[1] ≈ 0.022222222222222223  rtol=1e-10

            # Full displacement vector
            U = zeros(9)
            U[4] = u2x[1]

            # Global force vector
            F = K * U

            # Reaction forces
            r1x_exp = -k1 * u2x_exp  # -40/9 ≈ -4.444...
            r3x_exp = -k2 * u2x_exp  # -50/9 ≈ -5.555...
            @test F[1] ≈ r1x_exp  rtol=1e-10
            @test F[2] ≈ 0.0  atol=1e-15
            @test F[3] ≈ 0.0  atol=1e-15
            @test F[4] ≈ 10.0
            @test F[5] ≈ 0.0  atol=1e-15
            @test F[6] ≈ 0.0  atol=1e-15
            @test F[7] ≈ r3x_exp  rtol=1e-10
            @test F[8] ≈ 0.0  atol=1e-15
            @test F[9] ≈ 0.0  atol=1e-15

            # --- Internal element forces (scalar, positive = tension) ---
            u_elem1 = [U[1], U[2], U[3], U[4], U[5], U[6]]
            u_elem2 = [U[4], U[5], U[6], U[7], U[8], U[9]]

            f_elem1 = d3_spring_elementforce(k1, θx, θy, θz, u_elem1)  # 1-element vector
            f_elem2 = d3_spring_elementforce(k2, θx, θy, θz, u_elem2)

            @test length(f_elem1) == 1
            @test length(f_elem2) == 1
            @test f_elem1[1] ≈  k1 * u2x_exp  rtol=1e-10  # element 1 tension
            @test f_elem2[1] ≈ -k2 * u2x_exp  rtol=1e-10  # element 2 compression

            # --- Element nodal forces (k_elem * u_elem) ---
            f_elem1_nodal = ke1 * u_elem1  # 6×1 vector
            f_elem2_nodal = ke2 * u_elem2

            # Element 1: node 1 reaction = -k1*u2x, node 2 force = k1*u2x
            @test f_elem1_nodal[1] ≈ -k1 * u2x_exp  rtol=1e-10
            @test f_elem1_nodal[4] ≈  k1 * u2x_exp  rtol=1e-10

            # Element 2: node 2 force = k2*u2x, node 3 reaction = -k2*u2x
            @test f_elem2_nodal[1] ≈  k2 * u2x_exp  rtol=1e-10
            @test f_elem2_nodal[4] ≈ -k2 * u2x_exp  rtol=1e-10
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
            f_jl  = d1_truss_elementforces(k_jl, u)

            @test f_mat ≈ [1.0; -1.0]
            @test f_jl ≈ [1.0; -1.0]
            @test f_mat ≈ f_jl

            # Zero displacement
            @test LinearBarElementForces(k_mat, [0.0, 0.0]) ≈ [0.0, 0.0]
            @test d1_truss_elementforces(k_jl, [0.0, 0.0]) ≈ [0.0, 0.0]

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
        # Problem 3.1 — Three-element linear bar (1D truss)
        #   (Kattan, Solutions Manual)
        #   E=70e6, A=0.005, L=[1,2,1], Node 1 fixed
        #   Forces: f₂=-10, f₃=0, f₄=15
        # ─────────────────────────────────────────────
        @testset "Problem 3.1" begin
            E = 70e6
            A = 0.005

            # Element lengths
            L1 = 1.0
            L2 = 2.0
            L3 = 1.0

            # ══════════════════════
            # MATLAB computation path
            # ══════════════════════
            k1_mat = LinearBarElementStiffness(E, A, L1)
            k2_mat = LinearBarElementStiffness(E, A, L2)
            k3_mat = LinearBarElementStiffness(E, A, L3)

            K_mat = zeros(4, 4)
            K_mat = LinearBarAssemble(K_mat, k1_mat, 1, 2)
            K_mat = LinearBarAssemble(K_mat, k2_mat, 2, 3)
            K_mat = LinearBarAssemble(K_mat, k3_mat, 3, 4)

            # Reduced system (DOFs 2, 3, 4 — node 1 fixed)
            K_reduced_mat = K_mat[2:4, 2:4]
            f_reduced = [-10.0, 0.0, 15.0]
            u_reduced_mat = K_reduced_mat \ f_reduced

            # Full displacement vector
            U_mat = zeros(4)
            U_mat[2:4] = u_reduced_mat

            # Nodal reactions
            F_mat = K_mat * U_mat

            # Element nodal displacements
            u1_mat = [U_mat[1]; U_mat[2]]
            u2_mat = [U_mat[2]; U_mat[3]]
            u3_mat = [U_mat[3]; U_mat[4]]

            # Element stresses
            sigma1_mat = LinearBarElementStresses(k1_mat, u1_mat, A)
            sigma2_mat = LinearBarElementStresses(k2_mat, u2_mat, A)
            sigma3_mat = LinearBarElementStresses(k3_mat, u3_mat, A)

            # Element forces
            f1_mat = LinearBarElementForces(k1_mat, u1_mat)
            f2_mat = LinearBarElementForces(k2_mat, u2_mat)
            f3_mat = LinearBarElementForces(k3_mat, u3_mat)

            # ══════════════════════
            # Julia computation path
            # ══════════════════════
            k1_jl = d1_truss_elementstiffness(E, A, L1)
            k2_jl = d1_truss_elementstiffness(E, A, L2)
            k3_jl = d1_truss_elementstiffness(E, A, L3)

            K_jl = zeros(4, 4)
            K_jl = d1_truss_assemble(K_jl, k1_jl, 1, 2)
            K_jl = d1_truss_assemble(K_jl, k2_jl, 2, 3)
            K_jl = d1_truss_assemble(K_jl, k3_jl, 3, 4)

            K_reduced_jl = K_jl[2:4, 2:4]
            u_reduced_jl = K_reduced_jl \ f_reduced

            U_jl = zeros(4)
            U_jl[2:4] = u_reduced_jl

            F_jl = K_jl * U_jl

            u1_jl = [U_jl[1]; U_jl[2]]
            u2_jl = [U_jl[2]; U_jl[3]]
            u3_jl = [U_jl[3]; U_jl[4]]

            sigma1_jl = d1_truss_elementstress(k1_jl, u1_jl, A)
            sigma2_jl = d1_truss_elementstress(k2_jl, u2_jl, A)
            sigma3_jl = d1_truss_elementstress(k3_jl, u3_jl, A)

            f1_jl = d1_truss_elementforces(k1_jl, u1_jl)
            f2_jl = d1_truss_elementforces(k2_jl, u2_jl)
            f3_jl = d1_truss_elementforces(k3_jl, u3_jl)

            # ══════════════════════
            # Assertions: textbook values (exact)
            # ══════════════════════
            k1_expected = 350000.0 * [1 -1; -1 1]
            k2_expected = 175000.0 * [1 -1; -1 1]
            k3_expected = 350000.0 * [1 -1; -1 1]

            @test k1_mat ≈ k1_expected
            @test k2_mat ≈ k2_expected
            @test k3_mat ≈ k3_expected

            K_expected = [
                 350000   -350000         0         0
                -350000    525000   -175000         0
                      0   -175000    525000   -350000
                      0         0   -350000    350000
            ]
            @test K_mat ≈ K_expected

            K_reduced_expected = [
                525000   -175000         0
               -175000    525000   -350000
                     0   -350000    350000
            ]
            @test K_reduced_mat ≈ K_reduced_expected

            # Displacement solution (exact rational values)
            @test u_reduced_mat[1] ≈ 1/70000   rtol=1e-6
            @test u_reduced_mat[2] ≈ 1/10000   rtol=1e-6
            @test u_reduced_mat[3] ≈ 1/7000    rtol=1e-6

            # Nodal reactions
            @test F_mat[1] ≈ -5.0   rtol=1e-6
            @test F_mat[2] ≈ -10.0  rtol=1e-6
            @test F_mat[3] ≈ 0.0    atol=1e-10
            @test F_mat[4] ≈ 15.0   rtol=1e-6

            # Element stresses (MATLAB values from Solutions Manual)
            @test sigma1_mat ≈ [-1000, 1000]  rtol=1e-6
            @test sigma2_mat ≈ [-3000, 3000]  rtol=1e-6
            @test sigma3_mat ≈ [-3000, 3000]  rtol=1e-6

            # Element forces
            @test f1_mat ≈ [-5.0, 5.0]    rtol=1e-6
            @test f2_mat ≈ [-15.0, 15.0]  rtol=1e-6
            @test f3_mat ≈ [-15.0, 15.0]  rtol=1e-6

            # ══════════════════════
            # MATLAB vs Julia: exact match
            # ══════════════════════
            @test k1_mat ≈ k1_jl
            @test k2_mat ≈ k2_jl
            @test k3_mat ≈ k3_jl

            @test K_mat ≈ K_jl
            @test K_reduced_mat ≈ K_reduced_jl
            @test u_reduced_mat ≈ u_reduced_jl
            @test U_mat ≈ U_jl
            @test F_mat ≈ F_jl

            @test sigma1_mat ≈ sigma1_jl
            @test sigma2_mat ≈ sigma2_jl
            @test sigma3_mat ≈ sigma3_jl

            @test f1_mat ≈ f1_jl
            @test f2_mat ≈ f2_jl
            @test f3_mat ≈ f3_jl
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
    # SpaceTruss (3D Truss) — MATLAB comparison
    # ═══════════════════════════════════════════════════
    @testset "SpaceTruss" begin

        # ─────────────────────────────────────────────
        # Element-level tests
        # ─────────────────────────────────────────────
        @testset "Element-level" begin
            E, A, L = 1.0, 1.0, 1.0

            # --- Element length ---
            L1_mat = SpaceTrussElementLength(0, 0, 0, 1, 1, 1)
            L1_jl  = d3_truss_elementlength(0, 0, 0, 1, 1, 1)
            @test L1_mat ≈ √3
            @test L1_jl ≈ √3
            @test L1_mat ≈ L1_jl

            # --- Element stiffness matrix ---
            # All direction cosines = 1 (thetax=thetay=thetaz=0)
            k_mat = SpaceTrussElementStiffness(E, A, L, 0, 0, 0)
            k_jl  = d3_truss_elementstiffness(E, A, L, 0, 0, 0)
            w_ones = ones(3, 3)
            expected = [w_ones -w_ones; -w_ones w_ones]
            @test k_mat ≈ expected
            @test k_jl ≈ expected
            @test k_mat ≈ k_jl

            # thetax=0, thetay=90, thetaz=0
            k2_mat = SpaceTrussElementStiffness(E, A, L, 0, 90, 0)
            k2_jl  = d3_truss_elementstiffness(E, A, L, 0, 90, 0)
            w2 = [1 0 1; 0 0 0; 1 0 1]
            expected2 = [w2 -w2; -w2 w2]
            @test k2_mat ≈ expected2
            @test k2_jl ≈ expected2
            @test k2_mat ≈ k2_jl

            # --- Element force ---
            u = [1.0; 0.0; 0.0; 0.0; 0.0; 0.0]
            f_mat = SpaceTrussElementForce(E, A, L, 0, 0, 0, u)
            f_jl  = d3_truss_elementforces(E, A, L, 0, 0, 0, u)
            @test f_mat ≈ -1.0
            @test f_jl[1] ≈ -1.0
            @test f_mat ≈ f_jl[1]

            # Zero displacement → zero force
            @test SpaceTrussElementForce(E, A, L, 0, 0, 0, zeros(6)) ≈ 0.0
            @test d3_truss_elementforces(E, A, L, 0, 0, 0, zeros(6))[1] ≈ 0.0

            # --- Element stress ---
            sigma_mat = SpaceTrussElementStress(E, L, 0, 0, 0, u)
            sigma_jl  = d3_truss_elementstress(E, L, 0, 0, 0, u)
            @test sigma_mat ≈ -1.0
            @test sigma_jl[1] ≈ -1.0
            @test sigma_mat ≈ sigma_jl[1]

            # Zero displacement → zero stress
            @test SpaceTrussElementStress(E, L, 0, 0, 0, zeros(6)) ≈ 0.0
            @test d3_truss_elementstress(E, L, 0, 0, 0, zeros(6))[1] ≈ 0.0

            # --- Assembly ---
            K_mat = zeros(6, 6)
            k_mat = SpaceTrussElementStiffness(E, A, L, 0, 0, 0)
            K_mat = SpaceTrussAssemble(K_mat, k_mat, 1, 2)
            K_jl = zeros(6, 6)
            K_jl = d3_truss_assemble(K_jl, k_jl, 1, 2)
            @test K_mat ≈ K_jl
            @test K_mat[1:3, 1:3] == k_mat[1:3, 1:3]
            @test K_mat[1:3, 4:6] == k_mat[1:3, 4:6]
            @test K_mat[4:6, 1:3] == k_mat[4:6, 1:3]
            @test K_mat[4:6, 4:6] == k_mat[4:6, 4:6]
        end

        # ─────────────────────────────────────────────
        # Mixed angles test (thetax=30, thetay=45, thetaz=60)
        # ─────────────────────────────────────────────
        @testset "Mixed angles" begin
            E, A, L = 200e9, 0.01, 4.0
            thetax, thetay, thetaz = 30.0, 45.0, 60.0

            k_mat = SpaceTrussElementStiffness(E, A, L, thetax, thetay, thetaz)
            k_jl  = d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)

            @test size(k_mat) == (6, 6)
            @test size(k_jl) == (6, 6)
            @test k_mat ≈ k_jl rtol=1e-10
            @test k_mat == k_mat'  # symmetric
        end

        # ─────────────────────────────────────────────
        # Stress/Strain cross-identity (stress/E = strain)
        # ─────────────────────────────────────────────
        @testset "Stress/Strain identity" begin
            E, L = 200e9, 4.0
            u = [0.001; 0.0; 0.0; 0.0; 0.0; 0.0]

            stress = d3_truss_elementstress(E, L, 0, 0, 0, u)[1]
            strain = d3_truss_elementstrain(L, 0, 0, 0, u)[1]
            @test stress / E ≈ strain rtol=1e-10
        end

        # ─────────────────────────────────────────────
        # Full Problem: Problem 6.1 (Space Truss)
        # MATLAB reference from Kattan Solutions Manual
        # 4 elements, 5 nodes, 3 DOF/node → 15 DOFs
        # Nodes 1-4 fixed; Node 5 loaded: f=[15; 0; -20] N
        # ─────────────────────────────────────────────
        @testset "Problem 6.1" begin
            E = 200e6
            A = 0.003

            # ═══════════════════════════════════════
            # MATLAB computation path
            # ═══════════════════════════════════════

            # Element geometries: node coordinates
            # Element 1: node1(0,0,-3) → node5(0,5,0)
            # Element 2: node2(-3,0,0) → node5(0,5,0)
            # Element 3: node3(0,0,3)  → node5(0,5,0)
            # Element 4: node4(4,0,0)  → node5(0,5,0)
            L1_mat = SpaceTrussElementLength(0, 0, -3, 0, 5, 0)
            L2_mat = SpaceTrussElementLength(-3, 0, 0, 0, 5, 0)
            L3_mat = SpaceTrussElementLength(0, 0, 3, 0, 5, 0)
            L4_mat = SpaceTrussElementLength(4, 0, 0, 0, 5, 0)

            # Direction angles (MATLAB: acosd(dx/L))
            theta1x = rad2deg(acos(0.0 / L1_mat))
            theta1y = rad2deg(acos(5.0 / L1_mat))
            theta1z = rad2deg(acos(3.0 / L1_mat))

            theta2x = rad2deg(acos(3.0 / L2_mat))
            theta2y = rad2deg(acos(5.0 / L2_mat))
            theta2z = rad2deg(acos(0.0 / L2_mat))

            theta3x = rad2deg(acos(0.0 / L3_mat))
            theta3y = rad2deg(acos(5.0 / L3_mat))
            theta3z = rad2deg(acos(-3.0 / L3_mat))

            theta4x = rad2deg(acos(-4.0 / L4_mat))
            theta4y = rad2deg(acos(5.0 / L4_mat))
            theta4z = rad2deg(acos(0.0 / L4_mat))

            # Element stiffness matrices
            k1_mat = SpaceTrussElementStiffness(E, A, L1_mat, theta1x, theta1y, theta1z)
            k2_mat = SpaceTrussElementStiffness(E, A, L2_mat, theta2x, theta2y, theta2z)
            k3_mat = SpaceTrussElementStiffness(E, A, L3_mat, theta3x, theta3y, theta3z)
            k4_mat = SpaceTrussElementStiffness(E, A, L4_mat, theta4x, theta4y, theta4z)

            # Assemble global stiffness matrix (15×15)
            K_mat = zeros(15, 15)
            K_mat = SpaceTrussAssemble(K_mat, k1_mat, 1, 5)
            K_mat = SpaceTrussAssemble(K_mat, k2_mat, 2, 5)
            K_mat = SpaceTrussAssemble(K_mat, k3_mat, 3, 5)
            K_mat = SpaceTrussAssemble(K_mat, k4_mat, 4, 5)

            # Reduced system (DOFs 13,14,15 → Node 5)
            K_reduced_mat = K_mat[13:15, 13:15]
            f_reduced = [15.0, 0.0, -20.0]
            u_reduced_mat = K_reduced_mat \ f_reduced

            # Full displacement vector (15 DOFs)
            U_mat = zeros(15)
            U_mat[13:15] = u_reduced_mat

            # Element nodal displacements (each 6-element: node_i, node_j)
            u1_mat = [U_mat[1]; U_mat[2]; U_mat[3]; U_mat[13]; U_mat[14]; U_mat[15]]
            u2_mat = [U_mat[4]; U_mat[5]; U_mat[6]; U_mat[13]; U_mat[14]; U_mat[15]]
            u3_mat = [U_mat[7]; U_mat[8]; U_mat[9]; U_mat[13]; U_mat[14]; U_mat[15]]
            u4_mat = [U_mat[10]; U_mat[11]; U_mat[12]; U_mat[13]; U_mat[14]; U_mat[15]]

            # Stresses
            sigma1_mat = SpaceTrussElementStress(E, L1_mat, theta1x, theta1y, theta1z, u1_mat)
            sigma2_mat = SpaceTrussElementStress(E, L2_mat, theta2x, theta2y, theta2z, u2_mat)
            sigma3_mat = SpaceTrussElementStress(E, L3_mat, theta3x, theta3y, theta3z, u3_mat)
            sigma4_mat = SpaceTrussElementStress(E, L4_mat, theta4x, theta4y, theta4z, u4_mat)

            # Forces
            f1_mat = SpaceTrussElementForce(E, A, L1_mat, theta1x, theta1y, theta1z, u1_mat)
            f2_mat = SpaceTrussElementForce(E, A, L2_mat, theta2x, theta2y, theta2z, u2_mat)
            f3_mat = SpaceTrussElementForce(E, A, L3_mat, theta3x, theta3y, theta3z, u3_mat)
            f4_mat = SpaceTrussElementForce(E, A, L4_mat, theta4x, theta4y, theta4z, u4_mat)

            # Strains (stress/E)
            strain1_mat = sigma1_mat / E
            strain2_mat = sigma2_mat / E
            strain3_mat = sigma3_mat / E
            strain4_mat = sigma4_mat / E

            # ═══════════════════════════════════════
            # Julia computation path
            # ═══════════════════════════════════════

            L1_jl = d3_truss_elementlength(0, 0, -3, 0, 5, 0)
            L2_jl = d3_truss_elementlength(-3, 0, 0, 0, 5, 0)
            L3_jl = d3_truss_elementlength(0, 0, 3, 0, 5, 0)
            L4_jl = d3_truss_elementlength(4, 0, 0, 0, 5, 0)

            k1_jl = d3_truss_elementstiffness(E, A, L1_jl, theta1x, theta1y, theta1z)
            k2_jl = d3_truss_elementstiffness(E, A, L2_jl, theta2x, theta2y, theta2z)
            k3_jl = d3_truss_elementstiffness(E, A, L3_jl, theta3x, theta3y, theta3z)
            k4_jl = d3_truss_elementstiffness(E, A, L4_jl, theta4x, theta4y, theta4z)

            K_jl = zeros(15, 15)
            K_jl = d3_truss_assemble(K_jl, k1_jl, 1, 5)
            K_jl = d3_truss_assemble(K_jl, k2_jl, 2, 5)
            K_jl = d3_truss_assemble(K_jl, k3_jl, 3, 5)
            K_jl = d3_truss_assemble(K_jl, k4_jl, 4, 5)

            K_reduced_jl = K_jl[13:15, 13:15]
            u_reduced_jl = K_reduced_jl \ f_reduced

            U_jl = zeros(15)
            U_jl[13:15] = u_reduced_jl

            u1_jl = [U_jl[1]; U_jl[2]; U_jl[3]; U_jl[13]; U_jl[14]; U_jl[15]]
            u2_jl = [U_jl[4]; U_jl[5]; U_jl[6]; U_jl[13]; U_jl[14]; U_jl[15]]
            u3_jl = [U_jl[7]; U_jl[8]; U_jl[9]; U_jl[13]; U_jl[14]; U_jl[15]]
            u4_jl = [U_jl[10]; U_jl[11]; U_jl[12]; U_jl[13]; U_jl[14]; U_jl[15]]

            sigma1_jl = d3_truss_elementstress(E, L1_jl, theta1x, theta1y, theta1z, u1_jl)[1]
            sigma2_jl = d3_truss_elementstress(E, L2_jl, theta2x, theta2y, theta2z, u2_jl)[1]
            sigma3_jl = d3_truss_elementstress(E, L3_jl, theta3x, theta3y, theta3z, u3_jl)[1]
            sigma4_jl = d3_truss_elementstress(E, L4_jl, theta4x, theta4y, theta4z, u4_jl)[1]

            f1_jl = d3_truss_elementforces(E, A, L1_jl, theta1x, theta1y, theta1z, u1_jl)[1]
            f2_jl = d3_truss_elementforces(E, A, L2_jl, theta2x, theta2y, theta2z, u2_jl)[1]
            f3_jl = d3_truss_elementforces(E, A, L3_jl, theta3x, theta3y, theta3z, u3_jl)[1]
            f4_jl = d3_truss_elementforces(E, A, L4_jl, theta4x, theta4y, theta4z, u4_jl)[1]

            strain1_jl = d3_truss_elementstrain(L1_jl, theta1x, theta1y, theta1z, u1_jl)[1]
            strain2_jl = d3_truss_elementstrain(L2_jl, theta2x, theta2y, theta2z, u2_jl)[1]
            strain3_jl = d3_truss_elementstrain(L3_jl, theta3x, theta3y, theta3z, u3_jl)[1]
            strain4_jl = d3_truss_elementstrain(L4_jl, theta4x, theta4y, theta4z, u4_jl)[1]

            # ═══════════════════════════════════════
            # Assertions — MATLAB vs reference values
            # ═══════════════════════════════════════

            # --- Element lengths (textbook values) ---
            @test L1_mat ≈ 5.8310  rtol=1e-4
            @test L2_mat ≈ 5.8310  rtol=1e-4
            @test L3_mat ≈ 5.8310  rtol=1e-4
            @test L4_mat ≈ 6.4031  rtol=1e-4

            # --- Element stiffness matrices (MATLAB reference) ---
            # Element 1: thetax=90, thetay=30.9638, thetaz=59.0362
            k1_expected = 1e4 * [
                0.0     0.0     0.0     0.0     0.0     0.0
                0.0     7.5661  4.5397  0.0    -7.5661 -4.5397
                0.0     4.5397  2.7238  0.0    -4.5397 -2.7238
                0.0     0.0     0.0     0.0     0.0     0.0
                0.0    -7.5661 -4.5397  0.0     7.5661  4.5397
                0.0    -4.5397 -2.7238  0.0     4.5397  2.7238
            ]
            @test k1_mat ≈ k1_expected  rtol=1e-4

            # Element 2: theta2x=59.0362, theta2y=30.9638, theta2z=90
            k2_expected = 1e4 * [
                2.7238  4.5397  0.0    -2.7238 -4.5397  0.0
                4.5397  7.5661  0.0    -4.5397 -7.5661  0.0
                0.0     0.0     0.0     0.0     0.0     0.0
               -2.7238 -4.5397  0.0     2.7238  4.5397  0.0
               -4.5397 -7.5661  0.0     4.5397  7.5661  0.0
                0.0     0.0     0.0     0.0     0.0     0.0
            ]
            @test k2_mat ≈ k2_expected  rtol=1e-4

            # Element 3: theta3x=90, theta3y=30.9638, theta3z=120.9638
            k3_expected = 1e4 * [
                0.0     0.0     0.0     0.0     0.0     0.0
                0.0     7.5661 -4.5397  0.0    -7.5661  4.5397
                0.0    -4.5397  2.7238  0.0     4.5397 -2.7238
                0.0     0.0     0.0     0.0     0.0     0.0
                0.0    -7.5661  4.5397  0.0     7.5661 -4.5397
                0.0     4.5397 -2.7238  0.0    -4.5397  2.7238
            ]
            @test k3_mat ≈ k3_expected  rtol=1e-4

            # Element 4: theta4x=128.6598, theta4y=38.6598, theta4z=90
            k4_expected = 1e4 * [
                3.6568 -4.5709  0.0    -3.6568  4.5709  0.0
               -4.5709  5.7137  0.0     4.5709 -5.7137  0.0
                0.0     0.0     0.0     0.0     0.0     0.0
               -3.6568  4.5709  0.0     3.6568 -4.5709  0.0
                4.5709 -5.7137  0.0    -4.5709  5.7137  0.0
                0.0     0.0     0.0     0.0     0.0     0.0
            ]
            @test k4_mat ≈ k4_expected  rtol=1e-4

            # --- Reduced stiffness matrix (MATLAB reference) ---
            K_reduced_expected = 1e5 * [
                0.6381  -0.0031   0.0
               -0.0031   2.8412   0.0
                0.0      0.0      0.5448
            ]
            @test K_reduced_mat ≈ K_reduced_expected  rtol=1e-4

            # --- Displacement solution (MATLAB reference) ---
            @test u_reduced_mat[1] ≈  0.2351e-3  rtol=1e-4
            @test u_reduced_mat[2] ≈  0.0003e-3  rtol=2e-1  # near-zero; loose tolerance
            @test u_reduced_mat[3] ≈ -0.3671e-3  rtol=1e-4

            # --- Global reaction forces (MATLAB reference) ---
            F_mat = K_mat * U_mat
            @test F_mat[13] ≈  15.0  rtol=1e-4
            @test F_mat[14] ≈   0.0  atol=1e-3
            @test F_mat[15] ≈ -20.0  rtol=1e-4

            # --- Element stresses (MATLAB reference) ---
            @test sigma1_mat ≈ -6.4712e3  rtol=1e-4
            @test sigma2_mat ≈  4.1563e3  rtol=1e-4
            @test sigma3_mat ≈  6.4864e3  rtol=1e-4
            @test sigma4_mat ≈ -4.5808e3  rtol=1e-4

            # --- Element forces (stress × area) ---
            @test f1_mat ≈ -6.4712e3 * A  rtol=1e-4
            @test f2_mat ≈  4.1563e3 * A  rtol=1e-4
            @test f3_mat ≈  6.4864e3 * A  rtol=1e-4
            @test f4_mat ≈ -4.5808e3 * A  rtol=1e-4

            # --- Element strains (stress / E) ---
            @test strain1_mat ≈ -6.4712e3 / E  rtol=1e-4
            @test strain2_mat ≈  4.1563e3 / E  rtol=1e-4
            @test strain3_mat ≈  6.4864e3 / E  rtol=1e-4
            @test strain4_mat ≈ -4.5808e3 / E  rtol=1e-4

            # ═══════════════════════════════════════
            # MATLAB vs Julia: exact match
            # ═══════════════════════════════════════
            @test L1_mat ≈ L1_jl
            @test L2_mat ≈ L2_jl
            @test L3_mat ≈ L3_jl
            @test L4_mat ≈ L4_jl

            @test k1_mat ≈ k1_jl
            @test k2_mat ≈ k2_jl
            @test k3_mat ≈ k3_jl
            @test k4_mat ≈ k4_jl

            @test K_mat ≈ K_jl
            @test K_reduced_mat ≈ K_reduced_jl
            @test u_reduced_mat ≈ u_reduced_jl
            @test U_mat ≈ U_jl

            @test sigma1_mat ≈ sigma1_jl
            @test sigma2_mat ≈ sigma2_jl
            @test sigma3_mat ≈ sigma3_jl
            @test sigma4_mat ≈ sigma4_jl

            @test f1_mat ≈ f1_jl
            @test f2_mat ≈ f2_jl
            @test f3_mat ≈ f3_jl
            @test f4_mat ≈ f4_jl

            @test strain1_mat ≈ strain1_jl
            @test strain2_mat ≈ strain2_jl
            @test strain3_mat ≈ strain3_jl
            @test strain4_mat ≈ strain4_jl
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

            f1_jl = d2_beam_elementforces(E, A, I, L, 90, u1_jl)
            f2_jl = d2_beam_elementforces(E, A, I, L, 0, u2_jl)

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
        # ───────────────────────────────────────────────
        # Problem 10.1 — Eight-element space frame
        #   (Kattan, Solutions Manual)
        #   E=210e6, G=84e6, A=2e-2, Iy=10e-5, Iz=20e-5, J=5e-5
        #   8 corner nodes of a 4×5×4 box, 8 elements
        # ───────────────────────────────────────────────
        @testset "Problem 10.1" begin
            E = 210e6
            G = 84e6
            A = 2e-2
            Iy = 10e-5
            Iz = 20e-5
            J = 5e-5

            # ═══════════════════════
            # MATLAB computation path
            # ═══════════════════════
            # Vertical columns (z=0→5, height 5)
            k1_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 0,0,0, 0,5,0)
            k2_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 0,0,4, 0,5,4)
            k3_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 4,0,4, 4,5,4)
            k4_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 4,0,0, 4,5,0)
            # Beam members at z=5 (horizontal)
            k5_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 0,5,0, 0,5,4)
            k6_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 0,5,4, 4,5,4)
            k7_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 4,5,4, 4,5,0)
            k8_mat = SpaceFrameElementStiffness(E, G, A, Iy, Iz, J, 0,5,0, 4,5,0)

            # Assembly (48 DOF, 8 nodes)
            K_mat = zeros(48, 48)
            K_mat = SpaceFrameAssemble(K_mat, k1_mat, 1, 5)
            K_mat = SpaceFrameAssemble(K_mat, k2_mat, 2, 6)
            K_mat = SpaceFrameAssemble(K_mat, k3_mat, 3, 7)
            K_mat = SpaceFrameAssemble(K_mat, k4_mat, 4, 8)
            K_mat = SpaceFrameAssemble(K_mat, k5_mat, 5, 6)
            K_mat = SpaceFrameAssemble(K_mat, k6_mat, 6, 7)
            K_mat = SpaceFrameAssemble(K_mat, k7_mat, 7, 8)
            K_mat = SpaceFrameAssemble(K_mat, k8_mat, 5, 8)

            # Reduced system: DOFs 25-48 (top nodes unconstrained)
            k_reduced_mat = K_mat[25:48, 25:48]
            f_reduced = zeros(24)
            f_reduced[13] = -15.0  # -15 load at DOF 25+12=37
            u_reduced_mat = k_reduced_mat \ f_reduced

            # Full displacement (nodes 1-4 fixed = zero)
            U_mat = zeros(48)
            U_mat[25:48] = u_reduced_mat

            # Nodal reactions
            F_mat = K_mat * U_mat

            # ═══════════════════════
            # Julia computation path
            # ═══════════════════════
            k1_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,0, 0,5,0)
            k2_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,0,4, 0,5,4)
            k3_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 4,0,4, 4,5,4)
            k4_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 4,0,0, 4,5,0)
            k5_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,5,0, 0,5,4)
            k6_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,5,4, 4,5,4)
            k7_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 4,5,4, 4,5,0)
            k8_jl = d3_beam_elementstiffness(E, G, A, Iy, Iz, J, 0,5,0, 4,5,0)

            K_jl = zeros(48, 48)
            K_jl = d3_beam_assemble(K_jl, k1_jl, 1, 5)
            K_jl = d3_beam_assemble(K_jl, k2_jl, 2, 6)
            K_jl = d3_beam_assemble(K_jl, k3_jl, 3, 7)
            K_jl = d3_beam_assemble(K_jl, k4_jl, 4, 8)
            K_jl = d3_beam_assemble(K_jl, k5_jl, 5, 6)
            K_jl = d3_beam_assemble(K_jl, k6_jl, 6, 7)
            K_jl = d3_beam_assemble(K_jl, k7_jl, 7, 8)
            K_jl = d3_beam_assemble(K_jl, k8_jl, 5, 8)

            k_reduced_jl = K_jl[25:48, 25:48]
            u_reduced_jl = k_reduced_jl \ f_reduced

            U_jl = zeros(48)
            U_jl[25:48] = u_reduced_jl

            F_jl = K_jl * U_jl

            # ═══════════════════════
            # Assertions: MATLAB vs Julia — exact match
            # ═══════════════════════
            @test k1_mat ≈ k1_jl rtol=1e-10
            @test k2_mat ≈ k2_jl rtol=1e-10
            @test k3_mat ≈ k3_jl rtol=1e-10
            @test k4_mat ≈ k4_jl rtol=1e-10
            @test k5_mat ≈ k5_jl rtol=1e-10
            @test k6_mat ≈ k6_jl rtol=1e-10
            @test k7_mat ≈ k7_jl rtol=1e-10
            @test k8_mat ≈ k8_jl rtol=1e-10
            @test K_mat ≈ K_jl rtol=1e-10
            @test k_reduced_mat ≈ k_reduced_jl rtol=1e-10
            @test u_reduced_mat ≈ u_reduced_jl rtol=1e-10
            @test U_mat ≈ U_jl rtol=1e-10
            @test F_mat ≈ F_jl rtol=1e-10

            # ═══════════════════════
            # Assertions: textbook values (from solutions manual, 4 decimal places)
            # ═══════════════════════
            # Reduced displacements (first 12 of 24)
            expected_u = [
                -0.0004,  0.0000, -0.0006,  0.0000, -0.0004,  0.0000,
                -0.0021,  0.0000, -0.0006,  0.0000, -0.0004,  0.0002,
                -0.0021,  0.0000,  0.0006,  0.0000, -0.0004,  0.0002,
                -0.0004,  0.0000,  0.0006,  0.0000, -0.0004,  0.0000,
            ]
            @test u_reduced_mat ≈ expected_u atol=1e-3

            # Key nodal reaction values (at constrained DOFs 1-24)
            # F[1]=1.1599, F[2]=2.5054, F[3]=1.0091, ...
            @test F_mat[1]  ≈ 1.1599  rtol=1e-3
            @test F_mat[2]  ≈ 2.5054  rtol=1e-3
            @test F_mat[3]  ≈ 1.0091  rtol=1e-3
            @test F_mat[4]  ≈ 2.6719  rtol=1e-3
            @test F_mat[5]  ≈ 0.3008  rtol=1e-3
            @test F_mat[6]  ≈ -3.2737 rtol=1e-3
            @test F_mat[7]  ≈ 6.3324  rtol=1e-3
            @test F_mat[8]  ≈ 5.7484  rtol=1e-3
            @test F_mat[9]  ≈ 1.0091  rtol=1e-3
            @test F_mat[10] ≈ 2.6719  rtol=1e-3
            @test F_mat[11] ≈ 0.3008  rtol=1e-3
            @test F_mat[12] ≈ -17.6937 rtol=1e-3
            @test F_mat[13] ≈ 6.3481  rtol=1e-3
            @test F_mat[37] ≈ -15.0   rtol=1e-3
        end

        @testset "SpaceFrame diagram functions" begin
            f = [1000.0, 500.0, 300.0, 200.0, 150.0, 100.0,
                 -1000.0, -500.0, -300.0, -200.0, -150.0, -100.0]
            L = 5.0

            # Axial: z = [-f₁, f₇]
            @test SpaceFrameElementAxialDiagram(f, L) ≈ [-1000.0, -1000.0]
            @test SpaceFrameElementAxialDiagram(f, L) == [-f[1], f[7]]

            # Shear-Y: z = [f₂, -f₈]
            @test SpaceFrameElementShearYDiagram(f, L) ≈ [500.0, 500.0]
            @test SpaceFrameElementShearYDiagram(f, L) == [f[2], -f[8]]

            # Shear-Z: z = [f₃, -f₉]
            @test SpaceFrameElementShearZDiagram(f, L) ≈ [300.0, 300.0]
            @test SpaceFrameElementShearZDiagram(f, L) == [f[3], -f[9]]

            # Moment-Y: z = [f₅, -f₁₁]
            @test SpaceFrameElementMomentYDiagram(f, L) ≈ [150.0, 150.0]
            @test SpaceFrameElementMomentYDiagram(f, L) == [f[5], -f[11]]

            # Moment-Z: z = [f₆, -f₁₂]
            @test SpaceFrameElementMomentZDiagram(f, L) ≈ [100.0, 100.0]
            @test SpaceFrameElementMomentZDiagram(f, L) == [f[6], -f[12]]

            # Torsion: z = [f₄, -f₁₀]
            @test SpaceFrameElementTorsionDiagram(f, L) ≈ [200.0, 200.0]
            @test SpaceFrameElementTorsionDiagram(f, L) == [f[4], -f[10]]

            # Zero force → zero diagram
            f0 = zeros(12)
            @test SpaceFrameElementAxialDiagram(f0, L) == [0.0, 0.0]
            @test SpaceFrameElementShearYDiagram(f0, L) == [0.0, 0.0]
            @test SpaceFrameElementShearZDiagram(f0, L) == [0.0, 0.0]
            @test SpaceFrameElementMomentYDiagram(f0, L) == [0.0, 0.0]
            @test SpaceFrameElementMomentZDiagram(f0, L) == [0.0, 0.0]
            @test SpaceFrameElementTorsionDiagram(f0, L) == [0.0, 0.0]
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
            @test strain ≈ -1.0
            # Cross-check with stress/E identity
            k = d1_truss_elementstiffness(E, A, L)
            stress = d1_truss_elementstress(k, u, A)
            stress_div_E = stress / E
            @test stress_div_E ≈ [1.0, -1.0]
            # strain (scalar) = -stress_div_E[1] for this case
            @test strain ≈ -stress_div_E[1]
            # zero displacement
            @test d1_truss_elementstrain(L, [0.0, 0.0]) ≈ 0.0
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
            f_truss  = d2_truss_elementforces(E, A, L, theta, u)
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
            f1 = d1_truss_elementforces(d1_truss_elementstiffness(0, 1, 1), [1.0, 2.0])
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
            @test d1_truss_elementforces(k1, u0) ≈ [0.0, 0.0]
            # d2 functions
            @test d2_spring_elementforce(1.0, 45.0, u0_4)[1] ≈ 0.0
            @test d2_truss_elementforces(1.0, 1.0, 1.0, 45.0, u0_4)[1] ≈ 0.0
            # strain/stress with zero displacement
            @test d1_truss_elementstrain(1.0, u0) ≈ 0.0
            @test d2_truss_elementstrain(1.0, 0.0, u0_4)[1] ≈ 0.0
        end

    end

end  # @testset "MATLAB comparison"

# ════════════════════════════════════════════════════════════════
# Octave Validation — Live MATLAB .m execution via OctaveRunner
# ════════════════════════════════════════════════════════════════
# Runs each element family's core functions through Octave (GNU
# Octave, an open-source MATLAB-compatible interpreter) and
# compares results against the native LibFEM Julia implementations.
#
# This validates that:
#   1) LibFEM functions match the reference MATLAB .m files
#   2) The OctaveRunner bridge correctly serializes/deserializes
#      inputs and outputs of all shapes (scalars, vectors, matrices)
#   3) The adapter layer (matlab_adapters.jl) correctly maps between
#      Julia and MATLAB calling conventions
#
# When Octave with JSON support is not installed, the tests are
# silently skipped (warns and @test true).
# ════════════════════════════════════════════════════════════════

@testset "Octave validation" begin

    # ── include helpers ──
    include("octave_runner.jl")
    using .OctaveRunner
    include("matlab_adapters.jl")

    mfile_dir = joinpath(@__DIR__, "..", "Doc", "Kattan", "M-Files")

    # ── diagnostic helper ──
    function check_octave(oct_val, jl_val, name; rtol=1e-8, atol=1e-10)
        if isapprox(oct_val, jl_val; rtol=rtol, atol=atol)
            return true
        else
            rel_err = norm(vec(oct_val) .- vec(jl_val)) / max(norm(vec(jl_val)), eps())
            println("    ❌ MISMATCH: ", name)
            println("      Octave: ", oct_val)
            println("      Julia:  ", jl_val)
            println("      Rel err: ", rel_err)
            return false
        end
    end

    # ── detect Octave ──
    oct_info = OctaveRunner.detect_octave()
    if !oct_info.has_json
        @warn "Octave not available or missing JSON support — skipping Octave validation"
        @test true
    else
        @info "Octave $(oct_info.version) detected at $(oct_info.path)"

        # ────────────────────────────────────────────────────
        # 1D Spring (d1_spring)
        # ────────────────────────────────────────────────────
        @testset "Spring (1D)" begin
            k = 200.0

            # SpringElementStiffness
            path = joinpath(mfile_dir, "SpringElementStiffness.m")
            args = adapt_spring_args(k)
            oct_val = OctaveRunner.load_and_call(path, "SpringElementStiffness", args...)
            oct_k = adapt_spring_result(oct_val, 2)
            jl_k = d1_spring_elementstiffness(k)
            @test check_octave(oct_k, jl_k, "SpringElementStiffness")

            # SpringElementForces with zero displacement
            u0 = [0.0, 0.0]
            path = joinpath(mfile_dir, "SpringElementForces.m")
            args = adapt_spring_args(oct_k, u0)
            oct_val = OctaveRunner.load_and_call(path, "SpringElementForces", args...)
            oct_f = adapt_spring_result(oct_val, 2)
            jl_f = d1_spring_elementforce(oct_k, u0)
            @test check_octave(oct_f, jl_f, "SpringElementForces")

            # SpringAssemble into 2-element system
            path = joinpath(mfile_dir, "SpringAssemble.m")
            K0 = zeros(2, 2)
            args = adapt_spring_args(K0, oct_k, 1, 2)
            oct_K = OctaveRunner.load_and_call(path, "SpringAssemble", args...)
            jl_K = d1_spring_assemble(zeros(2, 2), oct_k, 1, 2)
            @test check_octave(oct_K, jl_K, "SpringAssemble")
        end

        # ────────────────────────────────────────────────────
        # 1D Truss (LinearBar / d1_truss)
        # ────────────────────────────────────────────────────
        @testset "LinearBar (1D Truss)" begin
            E, A, L = 70e6, 0.005, 1.0

            # LinearBarElementStiffness
            path = joinpath(mfile_dir, "LinearBarElementStiffness.m")
            args = adapt_truss_args(E, A, L)
            oct_val = OctaveRunner.load_and_call(path, "LinearBarElementStiffness", args...)
            oct_k = adapt_truss_result(oct_val, 2)
            jl_k = d1_truss_elementstiffness(E, A, L)
            @test check_octave(oct_k, jl_k, "LinearBarElementStiffness")

            # LinearBarElementForces (zero displacement)
            path = joinpath(mfile_dir, "LinearBarElementForces.m")
            args = adapt_truss_args(oct_k, [0.0, 0.0])
            oct_val = OctaveRunner.load_and_call(path, "LinearBarElementForces", args...)
            oct_f = adapt_truss_result(oct_val, 2)
            jl_f = d1_truss_elementforces(oct_k, [0.0, 0.0])
            @test check_octave(oct_f, jl_f, "LinearBarElementForces")

            # LinearBarElementStresses (zero displacement)
            path = joinpath(mfile_dir, "LinearBarElementStresses.m")
            args = adapt_truss_args(oct_k, [0.0, 0.0], A)
            oct_val = OctaveRunner.load_and_call(path, "LinearBarElementStresses", args...)
            oct_s = adapt_truss_result(oct_val, 2)
            jl_s = d1_truss_elementstress(oct_k, [0.0, 0.0], A)
            @test check_octave(oct_s, jl_s, "LinearBarElementStresses")

            # LinearBarAssemble
            path = joinpath(mfile_dir, "LinearBarAssemble.m")
            K0 = zeros(2, 2)
            args = adapt_truss_args(K0, oct_k, 1, 2)
            oct_K = OctaveRunner.load_and_call(path, "LinearBarAssemble", args...)
            jl_K = d1_truss_assemble(zeros(2, 2), oct_k, 1, 2)
            @test check_octave(oct_K, jl_K, "LinearBarAssemble")
        end

        # ────────────────────────────────────────────────────
        # 2D Truss (PlaneTruss / d2_truss)
        # ────────────────────────────────────────────────────
        @testset "PlaneTruss (2D Truss)" begin
            # Problem 5.2: E=210e9, A=0.003, element 1→2 at (0,0)→(4,3)
            E, A_truss = 210e9, 0.003
            x1, y1, x2, y2 = 0.0, 0.0, 4.0, 3.0
            L = d2_truss_elementlength(x1, y1, x2, y2)   # 5.0
            theta = rad2deg(atan(y2 - y1, x2 - x1))       # ~36.87°

            # PlaneTrussElementLength
            path = joinpath(mfile_dir, "PlaneTrussElementLength.m")
            args = adapt_truss_length_args(x1, y1, x2, y2)
            oct_val = OctaveRunner.load_and_call(path, "PlaneTrussElementLength", args...)
            oct_L = adapt_truss_result(oct_val, 4)
            jl_L = d2_truss_elementlength(x1, y1, x2, y2)
            @test check_octave(oct_L[1], jl_L, "PlaneTrussElementLength")

            # PlaneTrussElementStiffness
            path = joinpath(mfile_dir, "PlaneTrussElementStiffness.m")
            args = adapt_truss_args(E, A_truss, L, theta)
            oct_val = OctaveRunner.load_and_call(path, "PlaneTrussElementStiffness", args...)
            oct_k = adapt_truss_result(oct_val, 4)
            jl_k = d2_truss_elementstiffness(E, A_truss, L, theta)
            @test check_octave(oct_k, jl_k, "PlaneTrussElementStiffness")

            # PlaneTrussElementForce (zero displacement)
            u0_4 = zeros(4)
            path = joinpath(mfile_dir, "PlaneTrussElementForce.m")
            args = adapt_truss_args(E, A_truss, L, theta, u0_4)
            oct_val = OctaveRunner.load_and_call(path, "PlaneTrussElementForce", args...)
            oct_f = adapt_truss_result(oct_val, 4)
            jl_f = d2_truss_elementforces(E, A_truss, L, theta, u0_4)
            @test check_octave(oct_f, [jl_f], "PlaneTrussElementForce")

            # PlaneTrussElementStress (zero displacement)
            path = joinpath(mfile_dir, "PlaneTrussElementStress.m")
            args = adapt_truss_args(E, L, theta, u0_4)
            oct_val = OctaveRunner.load_and_call(path, "PlaneTrussElementStress", args...)
            oct_s = adapt_truss_result(oct_val, 4)
            jl_s = d2_truss_elementstress(E, L, theta, u0_4)
            @test check_octave(oct_s, [jl_s], "PlaneTrussElementStress")

            # PlaneTrussAssemble
            path = joinpath(mfile_dir, "PlaneTrussAssemble.m")
            K0 = zeros(8, 8)
            args = adapt_truss_args(K0, oct_k, 1, 2)
            oct_K = OctaveRunner.load_and_call(path, "PlaneTrussAssemble", args...)
            jl_K = d2_truss_assemble(zeros(8, 8), oct_k, 1, 2)
            @test check_octave(oct_K, jl_K, "PlaneTrussAssemble")
        end

        # ────────────────────────────────────────────────────
        # 3D Truss (SpaceTruss / d3_truss)
        # ────────────────────────────────────────────────────
        @testset "SpaceTruss (3D Truss)" begin
            # Problem 6.1: E=210e9, A=0.002, element along x-axis
            E, A_truss = 210e9, 0.002
            x1, y1, z1, x2, y2, z2 = 0.0, 0.0, 0.0, 5.0, 0.0, 0.0
            L = d3_truss_elementlength(x1, y1, z1, x2, y2, z2)   # 5.0
            θx, θy, θz = 0.0, 90.0, 90.0

            # SpaceTrussElementLength
            path = joinpath(mfile_dir, "SpaceTrussElementLength.m")
            args = adapt_truss_length_args(x1, y1, z1, x2, y2, z2)
            oct_val = OctaveRunner.load_and_call(path, "SpaceTrussElementLength", args...)
            oct_L = adapt_truss_result(oct_val, 6)
            jl_L = d3_truss_elementlength(x1, y1, z1, x2, y2, z2)
            @test check_octave(oct_L[1], jl_L, "SpaceTrussElementLength")

            # SpaceTrussElementStiffness
            path = joinpath(mfile_dir, "SpaceTrussElementStiffness.m")
            args = adapt_truss_args(E, A_truss, L, θx, θy, θz)
            oct_val = OctaveRunner.load_and_call(path, "SpaceTrussElementStiffness", args...)
            oct_k = adapt_truss_result(oct_val, 6)
            jl_k = d3_truss_elementstiffness(E, A_truss, L, θx, θy, θz)
            @test check_octave(oct_k, jl_k, "SpaceTrussElementStiffness")

            # SpaceTrussElementForce (zero displacement)
            u0_6 = zeros(6)
            path = joinpath(mfile_dir, "SpaceTrussElementForce.m")
            args = adapt_truss_args(E, A_truss, L, θx, θy, θz, u0_6)
            oct_val = OctaveRunner.load_and_call(path, "SpaceTrussElementForce", args...)
            oct_f = adapt_truss_result(oct_val, 6)
            jl_f = d3_truss_elementforces(E, A_truss, L, θx, θy, θz, u0_6)
            @test check_octave(oct_f, [jl_f], "SpaceTrussElementForce")

            # SpaceTrussElementStress (zero displacement)
            path = joinpath(mfile_dir, "SpaceTrussElementStress.m")
            args = adapt_truss_args(E, L, θx, θy, θz, u0_6)
            oct_val = OctaveRunner.load_and_call(path, "SpaceTrussElementStress", args...)
            oct_s = adapt_truss_result(oct_val, 6)
            jl_s = d3_truss_elementstress(E, L, θx, θy, θz, u0_6)
            @test check_octave(oct_s, [jl_s], "SpaceTrussElementStress")

            # SpaceTrussAssemble
            path = joinpath(mfile_dir, "SpaceTrussAssemble.m")
            K0 = zeros(12, 12)
            args = adapt_truss_args(K0, oct_k, 1, 2)
            oct_K = OctaveRunner.load_and_call(path, "SpaceTrussAssemble", args...)
            jl_K = d3_truss_assemble(zeros(12, 12), oct_k, 1, 2)
            @test check_octave(oct_K, jl_K, "SpaceTrussAssemble")
        end

        # ────────────────────────────────────────────────────
        # 2D Beam (PlaneFrame / d2_beam)
        # ────────────────────────────────────────────────────
        @testset "PlaneFrame (2D Beam)" begin
            # Problem 8.1: cantilever, E=210e6, A=4e-2, I=4e-6, L=4, θ=0°
            E, A_beam, I_val, L_beam = 210e6, 4e-2, 4e-6, 4.0
            theta = 0.0

            # PlaneFrameElementLength
            path = joinpath(mfile_dir, "PlaneFrameElementLength.m")
            args = adapt_beam_args(0.0, 0.0, 4.0, 0.0)
            oct_val = OctaveRunner.load_and_call(path, "PlaneFrameElementLength", args...)
            oct_Lval = adapt_beam_result(oct_val, 6)
            jl_Lval = d2_beam_elementlength(0.0, 0.0, 4.0, 0.0)
            @test check_octave(oct_Lval[1], jl_Lval, "PlaneFrameElementLength")

            # PlaneFrameElementStiffness
            path = joinpath(mfile_dir, "PlaneFrameElementStiffness.m")
            args = adapt_beam_args(E, A_beam, I_val, L_beam, theta)
            oct_val = OctaveRunner.load_and_call(path, "PlaneFrameElementStiffness", args...)
            oct_k = adapt_beam_result(oct_val, 6)
            jl_k = d2_beam_elementstiffness(E, A_beam, I_val, L_beam, theta)
            @test check_octave(oct_k, jl_k, "PlaneFrameElementStiffness")

            # PlaneFrameElementForces (zero displacement)
            u0_6 = zeros(6)
            path = joinpath(mfile_dir, "PlaneFrameElementForces.m")
            args = adapt_beam_args(E, A_beam, I_val, L_beam, theta, u0_6)
            oct_val = OctaveRunner.load_and_call(path, "PlaneFrameElementForces", args...)
            oct_f = adapt_beam_result(oct_val, 6)
            jl_f = d2_beam_elementforces(E, A_beam, I_val, L_beam, theta, u0_6)
            @test check_octave(oct_f, jl_f, "PlaneFrameElementForces")

            # PlaneFrameAssemble
            path = joinpath(mfile_dir, "PlaneFrameAssemble.m")
            K0 = zeros(12, 12)
            args = adapt_beam_args(K0, oct_k, 1, 2)
            oct_K = OctaveRunner.load_and_call(path, "PlaneFrameAssemble", args...)
            jl_K = d2_beam_assemble(zeros(12, 12), oct_k, 1, 2)
            @test check_octave(oct_K, jl_K, "PlaneFrameAssemble")
        end

        # ────────────────────────────────────────────────────
        # 3D Beam (SpaceFrame / d3_beam)
        # ────────────────────────────────────────────────────
        @testset "SpaceFrame (3D Beam)" begin
            # Problem 10.1 element: E=210e6, G=84e6, A=2e-2, Iy=10e-5,
            #   Iz=20e-5, J=5e-5, nodes (0,0,0)→(0,5,0)
            E_sf, G_sf = 210e6, 84e6
            A_sf, Iy_sf, Iz_sf, J_sf = 2e-2, 10e-5, 20e-5, 5e-5
            x1, y1, z1 = 0.0, 0.0, 0.0
            x2, y2, z2 = 0.0, 5.0, 0.0

            # SpaceFrameElementLength
            path = joinpath(mfile_dir, "SpaceFrameElementLength.m")
            args = adapt_space_frame_args(x1, y1, z1, x2, y2, z2)
            oct_val = OctaveRunner.load_and_call(path, "SpaceFrameElementLength", args...)
            oct_Lval = adapt_space_frame_result(oct_val, 12)
            jl_Lval = d3_beam_elementlength(x1, y1, z1, x2, y2, z2)
            @test check_octave(oct_Lval[1], jl_Lval, "SpaceFrameElementLength")

            # SpaceFrameElementStiffness
            path = joinpath(mfile_dir, "SpaceFrameElementStiffness.m")
            args = adapt_space_frame_args(E_sf, G_sf, A_sf, Iy_sf, Iz_sf, J_sf,
                                          x1, y1, z1, x2, y2, z2)
            oct_val = OctaveRunner.load_and_call(path, "SpaceFrameElementStiffness", args...)
            oct_k = adapt_space_frame_result(oct_val, 12)
            jl_k = d3_beam_elementstiffness(E_sf, G_sf, A_sf, Iy_sf, Iz_sf, J_sf,
                                             x1, y1, z1, x2, y2, z2)
            @test check_octave(oct_k, jl_k, "SpaceFrameElementStiffness")

            # SpaceFrameElementForces (zero displacement)
            u0_12 = zeros(12)
            path = joinpath(mfile_dir, "SpaceFrameElementForces.m")
            args = adapt_space_frame_args(E_sf, G_sf, A_sf, Iy_sf, Iz_sf, J_sf,
                                          x1, y1, z1, x2, y2, z2, u0_12)
            oct_val = OctaveRunner.load_and_call(path, "SpaceFrameElementForces", args...)
            oct_f = adapt_space_frame_result(oct_val, 12)
            jl_f = d3_beam_elementforces(E_sf, G_sf, A_sf, Iy_sf, Iz_sf, J_sf,
                                          x1, y1, z1, x2, y2, z2, u0_12)
            @test check_octave(oct_f, jl_f, "SpaceFrameElementForces")
        end

    end  # has_json

end  # @testset "Octave validation"
