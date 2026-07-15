# Draft: MATLAB-Julia Comparison Tests

## Metadata
- **Intent**: CLEAR
- **Review required**: No
- **Status**: awaiting-approval

## Decision Record
- **Test input source**: Solutions Manual problems (Problems 2.x, 5.2, 7.x, 8.x)
- **Approach**: Transcribe MATLAB algorithms into Julia reference code in `test/comparison.jl`, compare outputs at rtol=1e-10
- **Julia-only extensions** (no MATLAB counterpart): `d1_truss_elementstrain`, `d2_truss_elementstrain`, `d2_spring_*` — verified by mathematical identity with equivalent formulas
- **Diagram functions**: Verify data vectors (z) only, not plot aesthetics

## Scope
All 24 d1\*/d2\* Julia functions compared against MATLAB references.

## Key Findings

### Mapping Summary
| Julia Group | MATLAB Counterpart | Problems |
|---|---|---|
| `d1_spring_*` | `SpringElement*` | 2.1, 2.2 |
| `d1_truss_*` | `LinearBarElement*` | 5.2 (simpler part) |
| `d2_spring_*` | No MATLAB (Julia extension) | — |
| `d2_truss_*` | `PlaneTrussElement*` | 5.2, 7.x |
| `d2_beam_*` | `PlaneFrameElement*` (NOT `BeamElement*`) | 8.1, 8.2 |

### Critical Distinction
MATLAB `BeamElement*` is 4×4 (2 DOF/node, pure bending) → no Julia counterpart.
MATLAB `PlaneFrameElement*` is 6×6 (3 DOF/node) → maps to Julia `d2_beam_*`.

### Test Data Available

**Problem 2.1 (Springs)**:
k=200, k=250, 3-node assembly, f=[10] at node 2 → u=0.0222, F=[-4.4444; 10; -5.5556], f1=[-4.4444; 4.4444], f2=[5.5556; -5.5556]

**Problem 5.2 (Mixed/Plane Truss)**:
E=70e6, A=0.01, nodes at (0,0),(4,0),(4,-4),(4,3), L1=5 (theta=36.87°), L2=4 (theta=0), L3=5.6569 (theta=315°)
k1 = E*A/L1 * [C² CS -C² -CS; ...] with C=0.8, S=0.6 → 8.96e4 6.72e4 ...
k2 = [175000 0 -175000 0; ...]
k3 = 6.1872e4*(-1) pattern for theta=315°

**Problem 8.1 (Plane Frame)**:
E=210e6, A=4e-2, I=4e-6, L=4
k1 (theta=90): 1.0e6 * [0.0002 0 -0.0003 -0.0002 0 -0.0003; ...]
k2 (theta=0): 1.0e6 * [2.1 0 0 -2.1 0 0; 0 0.0002 0.0003 ...]
Assembly, solve: U, f1, f2 all available
Diagram data: z=[-f1; f4] (axial), z=[-f3; f6] (moment), z=[f2; -f5] (shear)

### Files
- `test/comparison.jl` — to be created (comparison tests with MATLAB reference implementations)
- `test/runtests.jl` — add `include("comparison.jl")`
- `Doc/Kattan/M-Files/*.m` — read-only MATLAB references
- `Doc/Kattan/Solutions Manual/Solutions to Problems.rtf` — read-only test data source
