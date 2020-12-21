module LibFEM
"""
function declaration: "d1_spring_assemble(K,k,i,j)"
This function assembles the element stiffness
matrix k of the spring with nodes i & j into the
global stiffness matrix K.
This function returns the global stiffness matrix K
after the element stiffness matrix k is assembled.
"""
function d1_spring_assemble(K, k, i, j)
    K[i, i] = K[i, i] + k[1, 1]
    K[i, j] = K[i, j] + k[1, 2]
    K[j, i] = K[j, i] + k[2, 1]
    K[j, j] = K[j, j] + k[2, 2]
    return K
end
export d1_spring_assemble
function d1_spring_elementforce(k, u)
    #function prototype: d1_spring_elementforce(k,u)
    #This function returns the element nodal force
    #vector given the element stiffness matrix k
    #and the element nodal displacement vector u.
    return k * u
end
export d1_spring_elementforce
function d1_spring_elementstiffness(k)
    #function prototype: d1_spring_elementstiffness(k)
    #This function returns the element stiffness
    #matrix for a spring with stiffness k.
    #The size of the element stiffness matrix
    #is 2 x 2.
    return [k -k; -k k]
end
export d1_spring_elementstiffness
function d1_truss_assemble(K, k, i, j)
    #function prototype:d1_truss_assemble(K,k,i,j)
    #This function assembles the element stiffness
    #matrix k of the linear bar with nodes i & j
    #into the global stiffness matrix K.
    #This function returns the global stiffness
    #matrix K after the element stiffness matrix
    #k is assembled.
    K[i, i] = K[i, i] + k[1, 1]
    K[i, j] = K[i, j] + k[1, 2]
    K[j, i] = K[j, i] + k[2, 1]
    K[j, j] = K[j, j] + k[2, 2]
    return K
end
export d1_truss_assemble
function d1_truss_elementforce(k, u)
    #function prototype: d1_truss_elementforce(k,u)
    #This function returns the element nodal
    #force vector given the element stiffness
    #matrix k & the element nodal displacement
    #vector u.
    return k * u
end
export d1_truss_elementforce
function d1_truss_elementstiffness(E, A, L)
    #function prototype: d1_truss_elementstiffness(E,A,L)
    #This function returns the element
    #stiffness matrix for a linear bar with
    #modulus of elasticity E; cross-sectional
    #area A; & length L. The size of the
    #element stiffness matrix is 2 x 2.
    return [E * A / L -E * A / L; -E * A / L E * A / L]
end
export d1_truss_elementstiffness
function d1_truss_elementstress(k, u, A)
    #function prototype: d1_truss_elementstress(k,u,A)
    #This function returns the element nodal
    #stress vector given the element stiffness
    #matrix k; the element nodal displacement
    #vector u; & the cross-sectional area A.
    return k * u / A
end
export d1_truss_elementstress
function d1_truss_elementstrain(L, u)
    #function prototype: d1_truss_elementstrain(k,u,A)
    #This function returns the element nodal
    #stress vector given the element stiffness
    #matrix k; the element nodal displacement
    #vector u; & the cross-sectional area A.
    return 1/L * u 
end
export d1_truss_elementstrain
function d2_beam_assemble(K, k, i, j)
    #function prototype: d2_beam_assemble(K,k,i,j)
    #This function assembles the element stiffness
    #matrix k of the plane beam element with nodes
    #i & j into the global stiffness matrix K.
    #This function returns the global stiffness
    #matrix K after the element stiffness matrix
    #k is assembled.
    K[3*i-2, 3*i-2] = K[3*i-2, 3*i-2] + k[1, 1]
    K[3*i-2, 3*i-1] = K[3*i-2, 3*i-1] + k[1, 2]
    K[3*i-2, 3*i] = K[3*i-2, 3*i] + k[1, 3]
    K[3*i-2, 3*j-2] = K[3*i-2, 3*j-2] + k[1, 4]
    K[3*i-2, 3*j-1] = K[3*i-2, 3*j-1] + k[1, 5]
    K[3*i-2, 3*j] = K[3*i-2, 3*j] + k[1, 6]
    K[3*i-1, 3*i-2] = K[3*i-1, 3*i-2] + k[2, 1]
    K[3*i-1, 3*i-1] = K[3*i-1, 3*i-1] + k[2, 2]
    K[3*i-1, 3*i] = K[3*i-1, 3*i] + k[2, 3]
    K[3*i-1, 3*j-2] = K[3*i-1, 3*j-2] + k[2, 4]
    K[3*i-1, 3*j-1] = K[3*i-1, 3*j-1] + k[2, 5]
    K[3*i-1, 3*j] = K[3*i-1, 3*j] + k[2, 6]
    K[3*i, 3*i-2] = K[3*i, 3*i-2] + k[3, 1]
    K[3*i, 3*i-1] = K[3*i, 3*i-1] + k[3, 2]
    K[3*i, 3*i] = K[3*i, 3*i] + k[3, 3]
    K[3*i, 3*j-2] = K[3*i, 3*j-2] + k[3, 4]
    K[3*i, 3*j-1] = K[3*i, 3*j-1] + k[3, 5]
    K[3*i, 3*j] = K[3*i, 3*j] + k[3, 6]
    K[3*j-2, 3*i-2] = K[3*j-2, 3*i-2] + k[4, 1]
    K[3*j-2, 3*i-1] = K[3*j-2, 3*i-1] + k[4, 2]
    K[3*j-2, 3*i] = K[3*j-2, 3*i] + k[4, 3]
    K[3*j-2, 3*j-2] = K[3*j-2, 3*j-2] + k[4, 4]
    K[3*j-2, 3*j-1] = K[3*j-2, 3*j-1] + k[4, 5]
    K[3*j-2, 3*j] = K[3*j-2, 3*j] + k[4, 6]
    K[3*j-1, 3*i-2] = K[3*j-1, 3*i-2] + k[5, 1]
    K[3*j-1, 3*i-1] = K[3*j-1, 3*i-1] + k[5, 2]
    K[3*j-1, 3*i] = K[3*j-1, 3*i] + k[5, 3]
    K[3*j-1, 3*j-2] = K[3*j-1, 3*j-2] + k[5, 4]
    K[3*j-1, 3*j-1] = K[3*j-1, 3*j-1] + k[5, 5]
    K[3*j-1, 3*j] = K[3*j-1, 3*j] + k[5, 6]
    K[3*j, 3*i-2] = K[3*j, 3*i-2] + k[6, 1]
    K[3*j, 3*i-1] = K[3*j, 3*i-1] + k[6, 2]
    K[3*j, 3*i] = K[3*j, 3*i] + k[6, 3]
    K[3*j, 3*j-2] = K[3*j, 3*j-2] + k[6, 4]
    K[3*j, 3*j-1] = K[3*j, 3*j-1] + k[6, 5]
    K[3*j, 3*j] = K[3*j, 3*j] + k[6, 6]
    return K
end
export d2_beam_assemble
function d2_beam_elementaxialdiagram(f, L)
    #function prototype: d2_beam_elementaxialdiagram(f, L)
    #This function plots the axial force
    #diagram for the plane beam element
    #with nodal force vector f & length L.
    x = [0 L]'
    z = [-f[1] f[4]]'
    #hold on
    title("Axial Force Diagram")
    plot(x, z)
    y1 = [0 0]'
    plot(x, y1, 'k')
end
export d2_beam_elementaxialdiagram
function d2_beam_elementforce(E, A, I, L, theta, u)
    #function prototype d2_beam_elementforce(E,A,I,L,theta,u)
    #This function returns the element force
    #vector given the modulus of elasticity E
    #the cross-sectional area A; the moment of
    #inertia I; the length L; the angle theta
    #(in degrees), & the element nodal
    #displacement vector u.
    x = theta * pi / 180
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
function d2_beam_elementlength(x1, y1, x2, y2)
    #function prototype: d2_beam_elementlength(x1,y1,x2,y2)
    #This function returns the length of the
    #plane beam element whose first node has
    #coordinates [x1,y1] & second node has
    #coordinates [x2,y2].
    return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
end
export d2_beam_elementlength
function d2_beam_elementmomentdiagram(f, L)
    #function prototype: d2_beam_elementmomentdiagram(f, L)
    #This function plots the bending
    #moment diagram for the plane beam
    #element with nodal force vector f & length L.
    x = [0 L]'
    z = [-f[3] f[6]]'
    #hold on
    title("Bending Moment Diagram")
    plot(x, z)
    y1 = [0 0]'
    plot(x, y1, 'k')
end
export d2_beam_elementmomentdiagram
function d2_beam_elementsheardiagram(f, L)
    #function prototype: d2_beam_elementsheardiagram(f, L)
    #This function plots the shear force
    #diagram for the plane beam element
    #with nodal force vector f & length L.
    x = [0 L]'
    z = [f[2] -f[5]]'
    #hold on
    title("Shear Force Diagram")
    plot(x, z)
    y1 = [0 0]'
    plot(x, y1, 'k')
end
export d2_beam_elementsheardiagram
function d2_beam_elementstiffness(E, A, I, L, theta)
    #function prototype: d2_beam_elementstiffness(E,A,I,L,theta)
    #This function returns the element
    #stiffness matrix for a plane beam
    #element with modulus of elasticity E;
    #cross-sectional area A; moment of
    #inertia I; length L; & angle()
    #theta [in degrees].
    #The size of the element stiffness matrix is 6 x 6.
    x = theta * pi / 180
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
function d2_spring_assemble(K, k, i, j)
    #function prototype:  d2_spring_assemble(K,k,i,j)
    #This function assembles the element stiffness
    #matrix k of the 2D spring element with nodes
    #i & j into the global stiffness matrix K.
    #This function returns the global stiffness
    #matrix K after the element stiffness matrix
    #k is assembled.
    K[2*i-1, 2*i-1] = K[2*i-1, 2*i-1] + k[1, 1]
    K[2*i-1, 2*i] = K[2*i-1, 2*i] + k[1, 2]
    K[2*i-1, 2*j-1] = K[2*i-1, 2*j-1] + k[1, 3]
    K[2*i-1, 2*j] = K[2*i-1, 2*j] + k[1, 4]
    K[2*i, 2*i-1] = K[2*i, 2*i-1] + k[2, 1]
    K[2*i, 2*i] = K[2*i, 2*i] + k[2, 2]
    K[2*i, 2*j-1] = K[2*i, 2*j-1] + k[2, 3]
    K[2*i, 2*j] = K[2*i, 2*j] + k[2, 4]
    K[2*j-1, 2*i-1] = K[2*j-1, 2*i-1] + k[3, 1]
    K[2*j-1, 2*i] = K[2*j-1, 2*i] + k[3, 2]
    K[2*j-1, 2*j-1] = K[2*j-1, 2*j-1] + k[3, 3]
    K[2*j-1, 2*j] = K[2*j-1, 2*j] + k[3, 4]
    K[2*j, 2*i-1] = K[2*j, 2*i-1] + k[4, 1]
    K[2*j, 2*i] = K[2*j, 2*i] + k[4, 2]
    K[2*j, 2*j-1] = K[2*j, 2*j-1] + k[4, 3]
    K[2*j, 2*j] = K[2*j, 2*j] + k[4, 4]
    return K
end
export  d2_spring_assemble
function d2_spring_elementforce(k, theta, u)
    #function prototype: d2_spring_elementforce(k,theta,u)
    #This function returns the element force
    #given the stiffness k &
    #the angle theta [in degrees], and the
    #element nodal displacement vector u.
    x = theta * pi / 180
    C = cos(x)
    S = sin(x)
    return k * [-C -S C S] * u
end
export d2_spring_elementforce
function d2_spring_elementstiffness(k, theta)
    #function prototype: d2_spring_elementstiffness(k,theta)
    #This function returns the element
    #stiffness matrix for a 2D spring
    #with stiffness k &
    #angle theta [in degrees].
    #The size of the element stiffness
    #matrix is 4 x 4.
    x = theta * pi / 180
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
function d2_truss_assemble(K, k, i, j)
    #function prototype : D2_TrussAssemble(K,k,i,j)
    #This function assembles the element stiffness
    #matrix k of the plane truss element with nodes
    #i & j into the global stiffness matrix K.
    #This function returns the global stiffness
    #matrix K after the element stiffness matrix
    #k is assembled.
    K[2*i-1, 2*i-1] = K[2*i-1, 2*i-1] + k[1, 1]
    K[2*i-1, 2*i] = K[2*i-1, 2*i] + k[1, 2]
    K[2*i-1, 2*j-1] = K[2*i-1, 2*j-1] + k[1, 3]
    K[2*i-1, 2*j] = K[2*i-1, 2*j] + k[1, 4]
    K[2*i, 2*i-1] = K[2*i, 2*i-1] + k[2, 1]
    K[2*i, 2*i] = K[2*i, 2*i] + k[2, 2]
    K[2*i, 2*j-1] = K[2*i, 2*j-1] + k[2, 3]
    K[2*i, 2*j] = K[2*i, 2*j] + k[2, 4]
    K[2*j-1, 2*i-1] = K[2*j-1, 2*i-1] + k[3, 1]
    K[2*j-1, 2*i] = K[2*j-1, 2*i] + k[3, 2]
    K[2*j-1, 2*j-1] = K[2*j-1, 2*j-1] + k[3, 3]
    K[2*j-1, 2*j] = K[2*j-1, 2*j] + k[3, 4]
    K[2*j, 2*i-1] = K[2*j, 2*i-1] + k[4, 1]
    K[2*j, 2*i] = K[2*j, 2*i] + k[4, 2]
    K[2*j, 2*j-1] = K[2*j, 2*j-1] + k[4, 3]
    K[2*j, 2*j] = K[2*j, 2*j] + k[4, 4]
    return K
end
export d2_truss_assemble
function d2_truss_elementforce(E, A, L, theta, u)
    #function prototype: d2_truss_elementforce(E,A,L,theta,u)
    #This function returns the element force
    #given the modulus of elasticity E; the
    #cross-sectional area A; the length L;
    #the angle theta [in degrees], & the
    #element nodal displacement vector u.
    x = theta * pi / 180
    C = cos(x)
    S = sin(x)
    return E * A / L * [-C -S C S] * u
end
export d2_truss_elementforce
function d2_truss_elementlength(x1, y1, x2, y2)
    #function prototype: d2_truss_elementlength(x1,y1,x2,y2)
    #This function returns the length of the
    #plane truss element whose first node has
    #coordinates [x1,y1] & second node has
    #coordinates [x2,y2].
    return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
end
export d2_truss_elementlength
function d2_truss_elementstiffness(E, A, L, theta)
    #function prototype: d2_truss_elementstiffness(E,A,L,theta)
    #This function returns the element
    #stiffness matrix for a plane truss
    #element with modulus of elasticity E;
    #cross-sectional area A; length L; &
    #angle theta [in degrees].
    #The size of the element stiffness
    #matrix is 4 x 4.
    x = theta * pi / 180
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
function d2_truss_elementstrain(L, theta, u)
    #function prototype d2_truss_elementstrain(L,theta,u)
    #This function returns the element strain
    #given the length L,the angle theta [in degrees]
    #and the element nodal displacement vector u.
    x = theta * pi / 180
    C = cos(x)
    S = sin(x)
    return 1 / L * [-C -S C S] * u
end
export d2_truss_elementstrain
function d2_truss_elementstress(E, L, theta, u)
    #function prototype: d2_truss_elementstress(E,L,theta,u)
    #This function returns the element stress
    #given the modulus of elasticity E; the
    #the length L; the angle theta (in
    #degrees); & the element nodal
    #displacement vector u.
    x = theta * pi / 180
    C = cos(x)
    S = sin(x)
    return E / L * [-C -S C S] * u
end
export d2_truss_elementstress
function d3_spring_assemble(K, k, i, j)
    #function prototype: d3_spring_assemble(K,k,i,j)
    #This function assembles the element stiffness
    #matrix k of the 3D spring element with nodes
    #i & j into the global stiffness matrix K.
    #This function returns the global stiffness
    #matrix K after the element stiffness matrix
    #k is assembled.
    K[3*i-2, 3*i-2] = K[3*i-2, 3*i-2] + k[1, 1]
    K[3*i-2, 3*i-1] = K[3*i-2, 3*i-1] + k[1, 2]
    K[3*i-2, 3*i] = K[3*i-2, 3*i] + k[1, 3]
    K[3*i-2, 3*j-2] = K[3*i-2, 3*j-2] + k[1, 4]
    K[3*i-2, 3*j-1] = K[3*i-2, 3*j-1] + k[1, 5]
    K[3*i-2, 3*j] = K[3*i-2, 3*j] + k[1, 6]
    K[3*i-1, 3*i-2] = K[3*i-1, 3*i-2] + k[2, 1]
    K[3*i-1, 3*i-1] = K[3*i-1, 3*i-1] + k[2, 2]
    K[3*i-1, 3*i] = K[3*i-1, 3*i] + k[2, 3]
    K[3*i-1, 3*j-2] = K[3*i-1, 3*j-2] + k[2, 4]
    K[3*i-1, 3*j-1] = K[3*i-1, 3*j-1] + k[2, 5]
    K[3*i-1, 3*j] = K[3*i-1, 3*j] + k[2, 6]
    K[3*i, 3*i-2] = K[3*i, 3*i-2] + k[3, 1]
    K[3*i, 3*i-1] = K[3*i, 3*i-1] + k[3, 2]
    K[3*i, 3*i] = K[3*i, 3*i] + k[3, 3]
    K[3*i, 3*j-2] = K[3*i, 3*j-2] + k[3, 4]
    K[3*i, 3*j-1] = K[3*i, 3*j-1] + k[3, 5]
    K[3*i, 3*j] = K[3*i, 3*j] + k[3, 6]
    K[3*j-2, 3*i-2] = K[3*j-2, 3*i-2] + k[4, 1]
    K[3*j-2, 3*i-1] = K[3*j-2, 3*i-1] + k[4, 2]
    K[3*j-2, 3*i] = K[3*j-2, 3*i] + k[4, 3]
    K[3*j-2, 3*j-2] = K[3*j-2, 3*j-2] + k[4, 4]
    K[3*j-2, 3*j-1] = K[3*j-2, 3*j-1] + k[4, 5]
    K[3*j-2, 3*j] = K[3*j-2, 3*j] + k[4, 6]
    K[3*j-1, 3*i-2] = K[3*j-1, 3*i-2] + k[5, 1]
    K[3*j-1, 3*i-1] = K[3*j-1, 3*i-1] + k[5, 2]
    K[3*j-1, 3*i] = K[3*j-1, 3*i] + k[5, 3]
    K[3*j-1, 3*j-2] = K[3*j-1, 3*j-2] + k[5, 4]
    K[3*j-1, 3*j-1] = K[3*j-1, 3*j-1] + k[5, 5]
    K[3*j-1, 3*j] = K[3*j-1, 3*j] + k[5, 6]
    K[3*j, 3*i-2] = K[3*j, 3*i-2] + k[6, 1]
    K[3*j, 3*i-1] = K[3*j, 3*i-1] + k[6, 2]
    K[3*j, 3*i] = K[3*j, 3*i] + k[6, 3]
    K[3*j, 3*j-2] = K[3*j, 3*j-2] + k[6, 4]
    K[3*j, 3*j-1] = K[3*j, 3*j-1] + k[6, 5]
    K[3*j, 3*j] = K[3*j, 3*j] + k[6, 6]
    return K
end
export d3_spring_assemble
function d3_spring_elementforce(k, thetax, thetay, thetaz, u)
    #function prototype: d3_spring_elementforce(k,thetax,thetay,thetaz,u)
    #This function returns the element force
    #given the stiffness k;
    #the angles thetax; thetay; thetaz
    #(in degrees), & the element nodal
    #displacement vector u.
    x = thetax * pi / 180
    w = thetay * pi / 180
    v = thetaz * pi / 180
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return k * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_spring_elementforce
function d3_spring_elementstiffness(k, thetax, thetay, thetaz)
    #function prototype: d3_spring_elementstiffness(k,thetax,thetay,thetaz)
    #This function returns the element
    #stiffness matrix for a 3D spring
    #element with stiffness k;
    #angles thetax; thetay; thetaz
    #(in degrees). The size of the element
    #stiffness matrix is 6 x 6.
    x = thetax * pi / 180
    u = thetay * pi / 180
    v = thetaz * pi / 180
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
function d3_truss_assemble(K, k, i, j)
    #function prototype: d3_truss_assemble(K,k,i,j)
    #This function assembles the element stiffness
    #matrix k of the space truss element with nodes
    #i & j into the global stiffness matrix K.
    #This function returns the global stiffness
    #matrix K after the element stiffness matrix
    #k is assembled.
    K[3*i-2, 3*i-2] = K[3*i-2, 3*i-2] + k[1, 1]
    K[3*i-2, 3*i-1] = K[3*i-2, 3*i-1] + k[1, 2]
    K[3*i-2, 3*i] = K[3*i-2, 3*i] + k[1, 3]
    K[3*i-2, 3*j-2] = K[3*i-2, 3*j-2] + k[1, 4]
    K[3*i-2, 3*j-1] = K[3*i-2, 3*j-1] + k[1, 5]
    K[3*i-2, 3*j] = K[3*i-2, 3*j] + k[1, 6]
    K[3*i-1, 3*i-2] = K[3*i-1, 3*i-2] + k[2, 1]
    K[3*i-1, 3*i-1] = K[3*i-1, 3*i-1] + k[2, 2]
    K[3*i-1, 3*i] = K[3*i-1, 3*i] + k[2, 3]
    K[3*i-1, 3*j-2] = K[3*i-1, 3*j-2] + k[2, 4]
    K[3*i-1, 3*j-1] = K[3*i-1, 3*j-1] + k[2, 5]
    K[3*i-1, 3*j] = K[3*i-1, 3*j] + k[2, 6]
    K[3*i, 3*i-2] = K[3*i, 3*i-2] + k[3, 1]
    K[3*i, 3*i-1] = K[3*i, 3*i-1] + k[3, 2]
    K[3*i, 3*i] = K[3*i, 3*i] + k[3, 3]
    K[3*i, 3*j-2] = K[3*i, 3*j-2] + k[3, 4]
    K[3*i, 3*j-1] = K[3*i, 3*j-1] + k[3, 5]
    K[3*i, 3*j] = K[3*i, 3*j] + k[3, 6]
    K[3*j-2, 3*i-2] = K[3*j-2, 3*i-2] + k[4, 1]
    K[3*j-2, 3*i-1] = K[3*j-2, 3*i-1] + k[4, 2]
    K[3*j-2, 3*i] = K[3*j-2, 3*i] + k[4, 3]
    K[3*j-2, 3*j-2] = K[3*j-2, 3*j-2] + k[4, 4]
    K[3*j-2, 3*j-1] = K[3*j-2, 3*j-1] + k[4, 5]
    K[3*j-2, 3*j] = K[3*j-2, 3*j] + k[4, 6]
    K[3*j-1, 3*i-2] = K[3*j-1, 3*i-2] + k[5, 1]
    K[3*j-1, 3*i-1] = K[3*j-1, 3*i-1] + k[5, 2]
    K[3*j-1, 3*i] = K[3*j-1, 3*i] + k[5, 3]
    K[3*j-1, 3*j-2] = K[3*j-1, 3*j-2] + k[5, 4]
    K[3*j-1, 3*j-1] = K[3*j-1, 3*j-1] + k[5, 5]
    K[3*j-1, 3*j] = K[3*j-1, 3*j] + k[5, 6]
    K[3*j, 3*i-2] = K[3*j, 3*i-2] + k[6, 1]
    K[3*j, 3*i-1] = K[3*j, 3*i-1] + k[6, 2]
    K[3*j, 3*i] = K[3*j, 3*i] + k[6, 3]
    K[3*j, 3*j-2] = K[3*j, 3*j-2] + k[6, 4]
    K[3*j, 3*j-1] = K[3*j, 3*j-1] + k[6, 5]
    K[3*j, 3*j] = K[3*j, 3*j] + k[6, 6]
    return K
end
export d3_truss_assemble
function d3_truss_elementforce(E, A, L, thetax, thetay, thetaz, u)
    #function prototype: d3_truss_elementforce(E,A,L,thetax,thetay,thetaz,u)
    #This function returns the element force
    #given the modulus of elasticity E; the
    #cross-sectional area A; the length L;
    #the angles thetax; thetay; thetaz
    #(in degrees), & the element nodal
    #displacement vector u.
    x = thetax * pi / 180
    w = thetay * pi / 180
    v = thetaz * pi / 180
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return E * A / L * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_truss_elementforce
function d3_truss_elementlength(x1, y1, z1, x2, y2, z2)
    #function prototype: d3_truss_elementlength(x1,y1,z1,x2,y2,z2)
    #This function returns the length of the
    #space truss element whose first node has
    #coordinates [x1,y1,z1] & second node has
    #coordinates [x2,y2,z2].
    return sqrt(
        (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1),
    )
end
export d3_truss_elementlength
function d3_truss_elementstiffness(E, A, L, thetax, thetay, thetaz)
    #function prototype: d3_truss_elementstiffness(E,A,L,thetax,thetay,thetaz)
    #This function returns the element
    #stiffness matrix for a space truss
    #element with modulus of elasticity E;
    #cross-sectional area A; length L; &
    #angles thetax; thetay; thetaz
    #(in degrees). The size of the element
    #stiffness matrix is 6 x 6.
    x = thetax * pi / 180
    u = thetay * pi / 180
    v = thetaz * pi / 180
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
function d3_truss_elementstrain(L, thetax, thetay, thetaz, u)
    #function prototype: export d3_truss_elementstrain(L,thetax,thetay,thetaz,u)
    #This function returns the element strain
    #the length L; the angles thetax; thetay;
    #thetaz [in degrees], & the element
    #nodal displacement vector u.
    x = thetax * pi / 180
    w = thetay * pi / 180
    v = thetaz * pi / 180
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return 1 / L * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_truss_elementstrain
function d3_truss_elementstress(E, L, thetax, thetay, thetaz, u)
    #function prototype: d3_truss_elementstress(E,L,thetax,thetay,thetaz,u)
    #This function returns the element stress
    #given the modulus of elasticity E; the
    #length L; the angles thetax; thetay;
    #thetaz [in degrees], & the element
    #nodal displacement vector u.
    x = thetax * pi / 180
    w = thetay * pi / 180
    v = thetaz * pi / 180
    Cx = cos(x)
    Cy = cos(w)
    Cz = cos(v)
    return E / L * [-Cx -Cy -Cz Cx Cy Cz] * u
end
export d3_truss_elementstress
end #module