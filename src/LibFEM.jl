module LibFEM
using Plots

"""
    deg2rad(theta::Real)

Convert degrees to radians.
"""
deg2rad(theta::Real) = theta * pi / 180

"""
    _assemble!(K, k, i, j, dofs)

Assemble element stiffness matrix k of a finite element
into the global stiffness matrix K. The element has nodes
i and j, with `dofs` degrees of freedom per node
(1: 1D spring/truss; 2: 2D spring/truss; 3: 2D beam / 3D spring/truss).
Returns the modified global stiffness matrix K.
"""
function _assemble!(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer, dofs::Integer)
    ii = (dofs * (i - 1) + 1):(dofs * i)
    jj = (dofs * (j - 1) + 1):(dofs * j)
    K[ii, ii] .+= k[1:dofs, 1:dofs]
    K[ii, jj] .+= k[1:dofs, (dofs + 1):(2 * dofs)]
    K[jj, ii] .+= k[(dofs + 1):(2 * dofs), 1:dofs]
    K[jj, jj] .+= k[(dofs + 1):(2 * dofs), (dofs + 1):(2 * dofs)]
    return K
end

"""
    function declaration: d1_spring_assemble(K,k,i,j)

This function assembles the element stiffness
matrix k of the spring with nodes i & j into the
global stiffness matrix K.
This function returns the global stiffness matrix K
after the element stiffness matrix k is assembled.
"""
function d1_spring_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)
end
export d1_spring_assemble
"""
    function declaration: d1_spring_elementforce(k,u)

This function returns the element nodal force
vector given the element stiffness matrix k
and the element nodal displacement vector u.
"""
function d1_spring_elementforce(k::AbstractMatrix, u::AbstractVector)
    return k * u
end
export d1_spring_elementforce
"""
    function declaration: d1_spring_elementstiffness(k)

This function returns the element stiffness
matrix for a spring with stiffness k.
The size of the element stiffness matrix
is 2 x 2.
"""
function d1_spring_elementstiffness(k::Real)
    return [k -k; -k k]
end
export d1_spring_elementstiffness
"""
    function declaration: d1_truss_assemble(K,k,i,j)

This function assembles the element stiffness
matrix k of the linear bar with nodes i & j
into the global stiffness matrix K.
This function returns the global stiffness
matrix K after the element stiffness matrix
k is assembled.
"""
function d1_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 1)
end
export d1_truss_assemble
"""
    function declaration: d1_truss_elementforce(k,u)

This function returns the element nodal
force vector given the element stiffness
matrix k & the element nodal displacement
vector u.
"""
function d1_truss_elementforce(k::AbstractMatrix, u::AbstractVector)
    return k * u
end
export d1_truss_elementforce
"""
    function declaration: d1_truss_elementstiffness(E,A,L)

This function returns the element
stiffness matrix for a linear bar with
modulus of elasticity E; cross-sectional
area A; & length L. The size of the
element stiffness matrix is 2 x 2.
"""
function d1_truss_elementstiffness(E::Real, A::Real, L::Real)
    return [E * A / L -E * A / L; -E * A / L E * A / L]
end
export d1_truss_elementstiffness
"""
    function declaration: d1_truss_elementstress(k,u,A)

This function returns the element nodal
stress vector given the element stiffness
matrix k; the element nodal displacement
vector u; & the cross-sectional area A.
"""
function d1_truss_elementstress(k::AbstractMatrix, u::AbstractVector, A::Real)
    return k * u / A
end
export d1_truss_elementstress
"""
    function declaration: d1_truss_elementstrain(L,u)

This function returns the element nodal
strain vector given the element length L
and the element nodal displacement vector u.
"""
function d1_truss_elementstrain(L::Real, u::AbstractVector)
    return 1/L * u 
end
export d1_truss_elementstrain
"""
    function declaration: d2_beam_assemble(K,k,i,j)

This function assembles the element stiffness
matrix k of the plane beam element with nodes
i & j into the global stiffness matrix K.
This function returns the global stiffness
matrix K after the element stiffness matrix
k is assembled.    
"""
function d2_beam_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
export d2_beam_assemble
"""
    function declaration: d2_beam_elementaxialdiagram(f, L)

This function plots and returns the axial force
diagram for the plane beam element
with nodal force vector f & length L.
"""
function d2_beam_elementaxialdiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [-f[1], f[4]]
    p = plot(x, z, title="Axial Force Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end
export d2_beam_elementaxialdiagram
"""
    function declaration: d2_beam_elementforce(E,A,I,L,theta,u)

This function returns the element force
vector given the modulus of elasticity E
the cross-sectional area A; the moment of
inertia I; the length L; the angle theta
(in degrees), & the element nodal
displacement vector u.
"""
function d2_beam_elementforce(E::Real, A::Real, I::Real, L::Real, theta::Real, u::AbstractVector)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    w1 = E * A / L
    w2 = 12 * E * I / (L * L * L)
    w3 = 6 * E * I / (L * L)
    w4 = 4 * E * I / L
    w5 = 2 * E * I / L
    kprime = [
        w1 0 0 -w1 0 0
        0 w2 w3 0 -w2 w3
        0 w3 w4 0 -w3 w5
        -w1 0 0 w1 0 0
        0 -w2 -w3 0 w2 -w3
        0 w3 w5 0 -w3 w4
    ]
    T = [
        C S 0 0 0 0
        -S C 0 0 0 0
        0 0 1 0 0 0
        0 0 0 C S 0
        0 0 0 -S C 0
        0 0 0 0 0 1
    ]
    return kprime * T * u
end
export d2_beam_elementforce
"""
    function declaration: d2_beam_elementlength(x1,y1,x2,y2)

This function returns the length of the
plane beam element whose first node has
coordinates [x1,y1] & second node has
coordinates [x2,y2].
"""
function d2_beam_elementlength(x1::Real, y1::Real, x2::Real, y2::Real)
    return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
end
export d2_beam_elementlength
"""
    function declaration: d2_beam_elementmomentdiagram(f, L)

This function plots and returns the bending
moment diagram for the plane beam
element with nodal force vector f & length L.
"""
function d2_beam_elementmomentdiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [-f[3], f[6]]
    p = plot(x, z, title="Bending Moment Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end
export d2_beam_elementmomentdiagram
"""
    function declaration: d2_beam_elementsheardiagram(f, L)

This function plots and returns the shear force
diagram for the plane beam element
with nodal force vector f & length L.
"""
function d2_beam_elementsheardiagram(f::AbstractVector, L::Real)
    x = [0, L]
    z = [f[2], -f[5]]
    p = plot(x, z, title="Shear Force Diagram")
    y1 = [0, 0]
    plot!(p, x, y1, color=:black)
    return p
end
export d2_beam_elementsheardiagram
"""
    function declaration: d2_beam_elementstiffness(E,A,I,L,theta)

This function returns the element
stiffness matrix for a plane beam
element with modulus of elasticity E;
cross-sectional area A; moment of
inertia I; length L; & angle
    theta [in degrees].
The size of the element stiffness matrix is 6 x 6.
"""
function d2_beam_elementstiffness(E::Real, A::Real, I::Real, L::Real, theta::Real)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    w1 = A * C * C + 12 * I * S * S / (L * L)
    w2 = A * S * S + 12 * I * C * C / (L * L)
    w3 = (A - 12 * I / (L * L)) * C * S
    w4 = 6 * I * S / L
    w5 = 6 * I * C / L
    return E / L * [
        w1 w3 -w4 -w1 -w3 -w4
        w3 w2 w5 -w3 -w2 w5
        -w4 w5 4 * I w4 -w5 2 * I
        -w1 -w3 w4 w1 w3 w4
        -w3 -w2 -w5 w3 w2 -w5
        -w4 w5 2 * I w4 -w5 4 * I
    ]
end
export d2_beam_elementstiffness
"""
    function declaration: d2_spring_assemble(K,k,i,j)

This function assembles the element stiffness
matrix k of the 2D spring element with nodes
i & j into the global stiffness matrix K.
This function returns the global stiffness
matrix K after the element stiffness matrix
k is assembled.
"""
function d2_spring_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 2)
end
export d2_spring_assemble
"""
    function declaration: d2_spring_elementforce(k,theta,u)

This function returns the element force
given the stiffness k &
the angle theta [in degrees], and the
element nodal displacement vector u.
"""
function d2_spring_elementforce(k::Real, theta::Real, u::AbstractVector)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return k * [-C -S C S] * u
end
export d2_spring_elementforce
"""
    function declaration: d2_spring_elementstiffness(k,theta)

This function returns the element
stiffness matrix for a 2D spring
with stiffness k &
angle theta [in degrees].
The size of the element stiffness
matrix is 4 x 4.
"""
function d2_spring_elementstiffness(k::Real, theta::Real)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return k * [
        C * C C * S -C * C -C * S
        C * S S * S -C * S -S * S
        -C * C -C * S C * C C * S
        -C * S -S * S C * S S * S
    ]
end
export d2_spring_elementstiffness
"""
    function declaration: d2_truss_assemble(K,k,i,j)

This function assembles the element stiffness
matrix k of the plane truss element with nodes
i & j into the global stiffness matrix K.
This function returns the global stiffness
matrix K after the element stiffness matrix
k is assembled.
"""
function d2_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 2)
end
export d2_truss_assemble
"""
    function declaration: d2_truss_elementforce(E,A,L,theta,u)

This function returns the element force
given the modulus of elasticity E; the
cross-sectional area A; the length L;
the angle theta [in degrees], & the
element nodal displacement vector u.
"""
function d2_truss_elementforce(E::Real, A::Real, L::Real, theta::Real, u::AbstractVector)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return E * A / L * [-C -S C S] * u
end
export d2_truss_elementforce
"""
    function declaration: d2_truss_elementlength(x1,y1,x2,y2)

This function returns the length of the
plane truss element whose first node has
coordinates [x1,y1] & second node has
coordinates [x2,y2].
"""
function d2_truss_elementlength(x1::Real, y1::Real, x2::Real, y2::Real)
    return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
end
export d2_truss_elementlength
"""
    function declaration: d2_truss_elementstiffness(E,A,L,theta)

This function returns the element
stiffness matrix for a plane truss
element with modulus of elasticity E;
cross-sectional area A; length L; &
angle theta [in degrees].
The size of the element stiffness
matrix is 4 x 4.
"""
function d2_truss_elementstiffness(E::Real, A::Real, L::Real, theta::Real)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return E * A / L * [
        C * C C * S -C * C -C * S
        C * S S * S -C * S -S * S
        -C * C -C * S C * C C * S
        -C * S -S * S C * S S * S
    ]
end
export d2_truss_elementstiffness
"""
    function declaration: d2_truss_elementstrain(L,theta,u)

This function returns the element strain
given the length L; the angle theta [in degrees]
and the element nodal displacement vector u.
"""
function d2_truss_elementstrain(L::Real, theta::Real, u::AbstractVector)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return 1 / L * [-C -S C S] * u
end
export d2_truss_elementstrain
"""
    function declaration: d2_truss_elementstress(E,L,theta,u)

This function returns the element stress
given the modulus of elasticity E; the
length L; the angle theta (in
degrees); & the element nodal
displacement vector u.
"""
function d2_truss_elementstress(E::Real, L::Real, theta::Real, u::AbstractVector)
    x = deg2rad(theta)
    C = cos(x)
    S = sin(x)
    return E / L * [-C -S C S] * u
end
export d2_truss_elementstress
"""
    function declaration: d3_spring_assemble(K,k,i,j)

This function assembles the element stiffness
matrix k of the 3D spring element with nodes
i & j into the global stiffness matrix K.
This function returns the global stiffness
matrix K after the element stiffness matrix
k is assembled.
"""
function d3_spring_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
export d3_spring_assemble
"""
    function declaration: d3_spring_elementforce(k,thetax,thetay,thetaz,u)

This function returns the element force
given the stiffness k;
the angles thetax; thetay; thetaz
(in degrees), & the element nodal
displacement vector u.
"""
function d3_spring_elementforce(k::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    x = deg2rad(thetax)
    w = deg2rad(thetay)
    v = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return k * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_spring_elementforce
"""
    function declaration: d3_spring_elementstiffness(k,thetax,thetay,thetaz)

This function returns the element
stiffness matrix for a 3D spring
element with stiffness k;
angles thetax; thetay; thetaz
(in degrees). The size of the element
stiffness matrix is 6 x 6.
"""
function d3_spring_elementstiffness(k::Real, thetax::Real, thetay::Real, thetaz::Real)
    x = deg2rad(thetax)
    u = deg2rad(thetay)
    v = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(u)
    Cz = cos(v)
    w = [
        Cx * Cx Cx * Cy Cx * Cz
        Cy * Cx Cy * Cy Cy * Cz
        Cz * Cx Cz * Cy Cz * Cz
    ]
    return k * [w -w; -w w]
end
export d3_spring_elementstiffness
"""
    function declaration: d3_truss_assemble(K,k,i,j)

This function assembles the element stiffness
matrix k of the space truss element with nodes
i & j into the global stiffness matrix K.
This function returns the global stiffness
matrix K after the element stiffness matrix
k is assembled.
"""
function d3_truss_assemble(K::AbstractMatrix, k::AbstractMatrix, i::Integer, j::Integer)
    return _assemble!(K, k, i, j, 3)
end
export d3_truss_assemble
"""
    function declaration: d3_truss_elementforce(E,A,L,thetax,thetay,thetaz,u)

This function returns the element force
given the modulus of elasticity E; the
cross-sectional area A; the length L;
the angles thetax; thetay; thetaz
(in degrees), & the element nodal
displacement vector u.
"""
function d3_truss_elementforce(E::Real, A::Real, L::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    x = deg2rad(thetax)
    w = deg2rad(thetay)
    v = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return E * A / L * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_truss_elementforce
"""
    function declaration: d3_truss_elementlength(x1,y1,z1,x2,y2,z2)

This function returns the length of the
space truss element whose first node has
coordinates [x1,y1,z1] & second node has
coordinates [x2,y2,z2].
"""
function d3_truss_elementlength(x1::Real, y1::Real, z1::Real, x2::Real, y2::Real, z2::Real)
    return sqrt(
        (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1),
    )
end
export d3_truss_elementlength
"""
    function declaration: d3_truss_elementstiffness(E,A,L,thetax,thetay,thetaz)

This function returns the element
stiffness matrix for a space truss
element with modulus of elasticity E;
cross-sectional area A; length L; &
angles thetax; thetay; thetaz
(in degrees). The size of the element
stiffness matrix is 6 x 6.
"""
function d3_truss_elementstiffness(E::Real, A::Real, L::Real, thetax::Real, thetay::Real, thetaz::Real)
    x = deg2rad(thetax)
    u = deg2rad(thetay)
    v = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(u)
    Cz = cos(v)
    w = [
        Cx * Cx Cx * Cy Cx * Cz
        Cy * Cx Cy * Cy Cy * Cz
        Cz * Cx Cz * Cy Cz * Cz
    ]
    return E * A / L * [w -w; -w w]
end
export d3_truss_elementstiffness
"""
    function declaration: d3_truss_elementstrain(L,thetax,thetay,thetaz,u)

This function returns the element strain
given the length L; the angles thetax; thetay;
thetaz [in degrees], & the element
nodal displacement vector u.
"""
function d3_truss_elementstrain(L::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    x = deg2rad(thetax)
    w = deg2rad(thetay)
    v = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return 1 / L * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_truss_elementstrain
"""
    function declaration: d3_truss_elementstress(E,L,thetax,thetay,thetaz,u)

This function returns the element stress
given the modulus of elasticity E; the
length L; the angles thetax; thetay;
thetaz [in degrees], & the element
nodal displacement vector u.
"""
function d3_truss_elementstress(E::Real, L::Real, thetax::Real, thetay::Real, thetaz::Real, u::AbstractVector)
    x = deg2rad(thetax)
    w = deg2rad(thetay)
    v = deg2rad(thetaz)
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return E / L * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_truss_elementstress
end # module