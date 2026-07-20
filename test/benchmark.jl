using LibFEM
using BenchmarkTools
using LinearAlgebra

const SUITE = BenchmarkGroup()

# =====================
# Group 1: Element Stiffness Construction
# =====================
const STIFF = SUITE["stiffness"] = BenchmarkGroup()

# d1_spring: stiffness k = 1000
STIFF["d1_spring"] = @benchmarkable d1_spring_elementstiffness(1000)

# d2_spring: k = 1000, theta = 30 degrees
STIFF["d2_spring"] = @benchmarkable d2_spring_elementstiffness(1000, 30)

# d3_spring: k = 1000, thetax = 30, thetay = 45, thetaz = 60 degrees
STIFF["d3_spring"] = @benchmarkable d3_spring_elementstiffness(1000, 30, 45, 60)

# d1_truss: E = 200e9 Pa, A = 0.01 m², L = 2.0 m
STIFF["d1_truss"] = @benchmarkable d1_truss_elementstiffness(200e9, 0.01, 2.0)

# d2_truss: E = 200e9, A = 0.01, L = 2.0, theta = 30 degrees
STIFF["d2_truss"] = @benchmarkable d2_truss_elementstiffness(200e9, 0.01, 2.0, 30)

# d3_truss: E = 200e9, A = 0.01, L = 2.0, thetax = 30, thetay = 45, thetaz = 60
STIFF["d3_truss"] = @benchmarkable d3_truss_elementstiffness(200e9, 0.01, 2.0, 30, 45, 60)

# d2_beam: E = 200e9, A = 0.01, I = 2e-4, L = 2.0, theta = 0 (horizontal)
STIFF["d2_beam"] = @benchmarkable d2_beam_elementstiffness(200e9, 0.01, 2e-4, 2.0, 0)

# d3_beam: E = 3e10, G = 1.15e8, A = 0.01, Iy = 1e-4, Iz = 2e-4, J = 1e-5, (0,0,0)→(4,0,0)
STIFF["d3_beam"] = @benchmarkable d3_beam_elementstiffness(3e10, 1.15e8, 0.01, 1e-4, 2e-4, 1e-5, 0, 0, 0, 4, 0, 0)

# =====================
# Group 2: Assembly into ~1000 DOF system
# =====================
const ASSEMBLE = SUITE["assembly"] = BenchmarkGroup()

# 500 elements connecting 501 nodes in a chain → 501 * 2 = 1002 DOF
const n_elements = 500
const n_nodes = n_elements + 1
K_global = zeros(2 * n_nodes, 2 * n_nodes)

# Pre-create all element stiffness matrices (horizontal truss, theta = 0)
k_elements = [d2_truss_elementstiffness(200e9, 0.01, 2.0, 0.0) for _ in 1:n_elements]

ASSEMBLE["d2_truss"] = @benchmarkable begin
    fill!($K_global, 0.0)
    for idx in 1:$n_elements
        d2_truss_assemble($K_global, $k_elements[idx], idx, idx + 1)
    end
end

# d1_spring: 500 elements, 501 nodes, 1 DOF/node → 501 DOF
const n_d1s = 500
const n_d1s_nodes = n_d1s + 1
K_d1s = zeros(1 * n_d1s_nodes, 1 * n_d1s_nodes)
k_d1s_elements = [d1_spring_elementstiffness(1000) for _ in 1:n_d1s]
ASSEMBLE["d1_spring"] = @benchmarkable begin
    fill!($K_d1s, 0.0)
    for idx in 1:$n_d1s
        d1_spring_assemble($K_d1s, $k_d1s_elements[idx], idx, idx + 1)
    end
end

# d2_spring: 500 elements, 501 nodes, 2 DOF/node → 1002 DOF
const n_d2s = 500
const n_d2s_nodes = n_d2s + 1
K_d2s = zeros(2 * n_d2s_nodes, 2 * n_d2s_nodes)
k_d2s_elements = [d2_spring_elementstiffness(1000, 30) for _ in 1:n_d2s]
ASSEMBLE["d2_spring"] = @benchmarkable begin
    fill!($K_d2s, 0.0)
    for idx in 1:$n_d2s
        d2_spring_assemble($K_d2s, $k_d2s_elements[idx], idx, idx + 1)
    end
end

# d3_spring: 500 elements, 501 nodes, 3 DOF/node → 1503 DOF
const n_d3s = 500
const n_d3s_nodes = n_d3s + 1
K_d3s = zeros(3 * n_d3s_nodes, 3 * n_d3s_nodes)
k_d3s_elements = [d3_spring_elementstiffness(1000, 30, 45, 60) for _ in 1:n_d3s]
ASSEMBLE["d3_spring"] = @benchmarkable begin
    fill!($K_d3s, 0.0)
    for idx in 1:$n_d3s
        d3_spring_assemble($K_d3s, $k_d3s_elements[idx], idx, idx + 1)
    end
end

# d1_truss: 500 elements, 501 nodes, 1 DOF/node → 501 DOF
const n_d1t = 500
const n_d1t_nodes = n_d1t + 1
K_d1t = zeros(1 * n_d1t_nodes, 1 * n_d1t_nodes)
k_d1t_elements = [d1_truss_elementstiffness(200e9, 0.01, 2.0) for _ in 1:n_d1t]
ASSEMBLE["d1_truss"] = @benchmarkable begin
    fill!($K_d1t, 0.0)
    for idx in 1:$n_d1t
        d1_truss_assemble($K_d1t, $k_d1t_elements[idx], idx, idx + 1)
    end
end

# d2_beam: 500 elements, 501 nodes, 3 DOF/node → 1503 DOF
const n_d2b = 500
const n_d2b_nodes = n_d2b + 1
K_d2b = zeros(3 * n_d2b_nodes, 3 * n_d2b_nodes)
k_d2b_elements = [d2_beam_elementstiffness(200e9, 0.01, 2e-4, 2.0, 0) for _ in 1:n_d2b]
ASSEMBLE["d2_beam"] = @benchmarkable begin
    fill!($K_d2b, 0.0)
    for idx in 1:$n_d2b
        d2_beam_assemble($K_d2b, $k_d2b_elements[idx], idx, idx + 1)
    end
end

# d3_truss: 500 elements, 501 nodes, 3 DOF/node → 1503 DOF
const n_d3t = 500
const n_d3t_nodes = n_d3t + 1
K_d3t = zeros(3 * n_d3t_nodes, 3 * n_d3t_nodes)
k_d3t_elements = [d3_truss_elementstiffness(200e9, 0.01, 2.0, 30, 45, 60) for _ in 1:n_d3t]
ASSEMBLE["d3_truss"] = @benchmarkable begin
    fill!($K_d3t, 0.0)
    for idx in 1:$n_d3t
        d3_truss_assemble($K_d3t, $k_d3t_elements[idx], idx, idx + 1)
    end
end

# =====================
# Group 3: Solve random linear system
# =====================
const SOLVE = SUITE["solve"] = BenchmarkGroup()

# Random SPD matrix: n = 200, K = A' * A + I, f = randn
const n_solve = 200
const A_rand = randn(n_solve, n_solve)
const K_spd = A_rand' * A_rand + I
const f_vec = randn(n_solve)

SOLVE["dense"] = @benchmarkable $K_spd \ $f_vec

# =====================
# d3_beam: Element forces
# =====================
const FORCES = SUITE["forces"] = BenchmarkGroup()
const E_bm = 3e10
const G_bm = 1.15e8
const A_bm = 0.01
const Iy_bm = 1e-4
const Iz_bm = 2e-4
const J_bm = 1e-5
const u_bm = [0.001; zeros(11)]

FORCES["d3_beam"] = @benchmarkable d3_beam_elementforces($E_bm, $G_bm, $A_bm, $Iy_bm, $Iz_bm, $J_bm, 0, 0, 0, 4, 0, 0, $u_bm)

# d1_spring: Ke = d1_spring_elementstiffness(1000), u = [0.001; 0.0]
const Ke_s1 = d1_spring_elementstiffness(1000)
const u_s1 = [0.001; 0.0]
FORCES["d1_spring"] = @benchmarkable d1_spring_elementforce($Ke_s1, $u_s1)

# d2_spring: k = 1000, theta = 30, u (4-element)
const u_s2 = [0.001; zeros(3)]
FORCES["d2_spring"] = @benchmarkable d2_spring_elementforce(1000, 30, $u_s2)

# d3_spring: k = 1000, thetax = 30, thetay = 45, thetaz = 60, u (6-element)
const u_s3 = [0.001; zeros(5)]
FORCES["d3_spring"] = @benchmarkable d3_spring_elementforce(1000, 30, 45, 60, $u_s3)

# d1_truss: Ke = d1_truss_elementstiffness(200e9, 0.01, 2.0), u = [0.001; 0.0]
const Ke_t1 = d1_truss_elementstiffness(200e9, 0.01, 2.0)
const u_t1 = [0.001; 0.0]
FORCES["d1_truss"] = @benchmarkable d1_truss_elementforces($Ke_t1, $u_t1)

# d2_truss: E = 200e9, A = 0.01, L = 2.0, theta = 30, u (4-element)
const u_t2 = [0.001; zeros(3)]
FORCES["d2_truss"] = @benchmarkable d2_truss_elementforces(200e9, 0.01, 2.0, 30, $u_t2)

# d3_truss: E = 200e9, A = 0.01, L = 2.0, thetax = 30, thetay = 45, thetaz = 60, u (6-element)
const u_t3 = [0.001; zeros(5)]
FORCES["d3_truss"] = @benchmarkable d3_truss_elementforces(200e9, 0.01, 2.0, 30, 45, 60, $u_t3)

# d2_beam: E = 200e9, A = 0.01, I = 2e-4, L = 2.0, theta = 0, u (6-element)
const u_b2 = [0.001; zeros(5)]
FORCES["d2_beam"] = @benchmarkable d2_beam_elementforces(200e9, 0.01, 2e-4, 2.0, 0, $u_b2)

# =====================
# Group 4: d3_beam Assembly into ~3000 DOF system
# =====================
const D3_ASSEMBLE = SUITE["d3_assembly"] = BenchmarkGroup()

# 500 elements → 501 nodes × 6 DOF = 3006 DOF
const n_d3_elements = 500
const n_d3_nodes = n_d3_elements + 1
const K_d3_global = zeros(6 * n_d3_nodes, 6 * n_d3_nodes)

const k_d3_elements = [d3_beam_elementstiffness(E_bm, G_bm, A_bm, Iy_bm, Iz_bm, J_bm, 0, 0, 0, 4, 0, 0) for _ in 1:n_d3_elements]

D3_ASSEMBLE["d3_beam"] = @benchmarkable begin
    fill!($K_d3_global, 0.0)
    for idx in 1:$n_d3_elements
        d3_beam_assemble($K_d3_global, $k_d3_elements[idx], idx, idx + 1)
    end
end

# =====================
# Run benchmarks
# =====================
println("Tuning benchmarks...")
tune!(SUITE)

println("Running benchmarks...")
results = run(SUITE, verbose=true)
display(results)
