# Plan: MATLAB-Julia Comparison Tests

## TL;DR (For humans)

Create `test/comparison.jl` with transcribed-MATLAB reference implementations and compare against all 24 d1\*/d2\* Julia functions using textbook Solutions Manual problem data. This permanently captures numerical equivalence verification in the test suite.

## Work Units

### ~~WU-1: Create test/comparison.jl — reference infrastructure + 1D Spring comparisons~~ ✅

- Reference functions transcribed: SpringElementStiffness, SpringElementForces, SpringAssemble
- Problem 2.1 (3-spring) tests pass: k=200/250, assembly, forces match textbook
- Problem 2.2 (4-spring) tests pass: k=170, 4-node assembly
- QA: 46 Spring comparison tests pass

---

### ~~WU-2: d1_truss + d2_truss element-level comparison~~ ✅

- Reference functions transcribed: LinearBarElementStiffness/Forces/Stresses/Assemble, PlaneTrussElementLength/Stiffness/Force/Stress/Assemble
- Problem 5.2 tests pass: E=70e6, A=0.01, 3 truss elements + spring, full assembly→reduced→stress
- 49 truss comparison tests pass (19 element-level + 30 Problem 5.2)
- QA: all 95 comparison + 109 original = 204 tests pass

---

### ~~WU-3: d2_beam (PlaneFrame) element-level comparison~~ ✅

**Files**: `test/comparison.jl` (extend)

**MATLAB references to transcribe**:
- `PlaneFrameElementStiffness(E,A,I,L,theta)` → w1..w5 calculation, 6×6 matrix (identical to Julia `d2_beam_elementstiffness`)
- `PlaneFrameAssemble(K,k,i,j)` → block-add k into K at 3-DOF indices (identical to `_assemble!(K,k,i,j,3)`)
- `PlaneFrameElementForces(E,A,I,L,theta,u)` → kprime*T*u with w1..w5 and T rotation matrix
- `PlaneFrameElementLength` → same as truss
- `PlaneFrameElementAxialDiagram` → z=[-f1; f4]
- `PlaneFrameElementMomentDiagram` → z=[-f3; f6]
- `PlaneFrameElementShearDiagram` → z=[f2; -f5]

**Test cases from Problem 8.1**:
- E=210e6, A=4e-2, I=4e-6, L=4
- k1 (theta=90): 1.0e6 * [0.0002 0 -0.0003 ...]
- k2 (theta=0): 1.0e6 * [2.1 0 0 -2.1 0 0; ...]
- Assemble into 9×9 global K
- With reduced k (5×5) and f=[0;0;15;20;0], solve for u
- u1 → f1 = [-4.6875; 20; 46.2501; 4.6875; -20; 33.7499]
- u2 → f2 = [-20; -4.6875; -18.7499; 20; 4.6875; -0.0000]
- Diagram data: verify z vectors match expected sign/values

**Critical distinction**: Verify Julia `d2_beam_*` matches MATLAB `PlaneFrameElement*` NOT `BeamElement*` (BeamElement is 4×4 pure bending with no Julia counterpart)

**QA**: All beam/frame tests pass

**Commit message**: `test(comparison): add d2_beam (PlaneFrame) MATLAB comparison tests`

---

### ~~WU-4: Julia-only extensions + edge case sweep~~ ✅

**Files**: `test/comparison.jl` (extend)

**Julia-only extensions to verify** (no MATLAB counterpart):
- `d1_truss_elementstrain(L,u)` = `1/L * u` — verify formula is mathematically correct
- `d2_truss_elementstrain(L,theta,u)` = `1/L*[-C -S C S]*u` — verify against strain = stress/E identity
- `d2_spring_elementstiffness(k,theta)` = `k * [C² CS -C² -CS; ...]` — verify against PlaneTruss elementstiffness with E*A/L=1 (should be identical)
- `d2_spring_elementforce(k,theta,u)` = `k*[-C -S C S]*u` — verify against PlaneTruss elementforce with E*A/L=1

**Edge case sweep**:
- Zero stiffness (k=0) → zero matrix/vector
- Zero length (L=0) → handle gracefully
- Theta = 0, 90, 180, 360 → C/S at extremes
- Negative theta → same as positive (periodic)
- Boundary node indices (i=1, j=2 or i=large, j=large+1)
- Non-square element stiffness (should be 2×2, 4×4, or 6×6)
- Non-vector element displacement (should be length 2, 4, or 6)

**QA**: Edge cases don't produce errors, all assertions pass

**Commit message**: `test(comparison): verify Julia-only extensions and edge cases`

---

### ~~WU-5: Full suite verification~~ ✅

**Files**: none (run only)

**Actions**:
1. Restart Julia session
2. Run `julia --project=. test/runtests.jl`
3. Confirm original 109 tests + all comparison tests pass

**Acceptance**: Total test count = 109 (original) + N (comparison). All green.

**Commit message**: `chore: finalize MATLAB comparison test suite`

---

## Must-NOT-Have
- Do NOT modify MATLAB files in Doc/Kattan/ (read-only)
- Do NOT install MATLAB or attempt to run `.m` files directly
- Do NOT change any Julia function signatures or behavior
- Do NOT test Plot rendering — only the data vectors for diagram functions
