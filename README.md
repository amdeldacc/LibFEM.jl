# LibFEM.jl
A lightweight educational Finite Element library in Julia for 1D/2D/3D springs, trusses, and beams (see `Doc/Kattan/M-Files/` for the MATLAB reference).

## Installation
```bash
git clone https://github.com/amdeldacc/LibFEM.jl.git
cd LibFEM.jl
julia --project=. -e 'using LibFEM'
```
(Or `using Pkg; Pkg.activate("."); using LibFEM` in an existing Julia session.)

## Quick Start
```julia
using LibFEM
k = d1_spring_elementstiffness(200)
K = zeros(3,3)
K = d1_spring_assemble(K, k, 1, 2)
K = d1_spring_assemble(K, k, 2, 3)
u = [0; K[2,2] \ 10; 0]
```
## Core Naming Pattern
`d{N}_{domain}_{operation}` where  
- `N` = 1/2/3 spatial dimensions  
- `domain` = spring, truss, beam  
- `operation` = elementstiffness, assemble, elementforce, elementstress, elementstrain, …  

Each element type provides:
1. `*_elementstiffness` – stiffness matrix  
2. `*_assemble` – add to global matrix  
3. one of `*_elementforce`, `*_elementstress`, `*_elementstrain`

## Project Layout
```
src/
  LibFEM.jl      # module, exports
  types.jl       # abstract types & structs
  errors.jl      # custom errors
  utils.jl       # deg2rad, helpers
  assembly.jl    # shared assembly logic
  spring.jl      # 1‑3‑D spring functions
  truss.jl       # 1‑3‑D truss functions
  beam.jl        # 2‑3‑D beam functions
  plot.jl        # diagram helpers (Plots.jl)
```
## Testing
```bash
julia --project=. test/runtests.jl   # full suite (~668 tests)
```
## License
MIT (see `LICENSE`).  

---  
The library follows Peter Kattan’s MATLAB *Finite Elements* textbook; see `openwiki/reference/kattan-mapping.md` for the MATLAB‑→‑Julia mapping.