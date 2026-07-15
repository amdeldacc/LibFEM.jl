# Assembly Functions Refactor: `_assemble!` Helper

## Change Summary

**Date**: 2026-07-15
**Files modified**: `src/LibFEM.jl`
**Lines added**: ~25 (`_assemble!` helper)
**Lines removed**: ~140 (duplicated assembly code)

## What Changed

### Added `_assemble!` (private helper)

A generic assembly function that replaces the 7 nearly-identical `*_assemble` functions:

```julia
function _assemble!(K, k, i, j, dofs)
    ii = (dofs * (i - 1) + 1):(dofs * i)
    jj = (dofs * (j - 1) + 1):(dofs * j)
    K[ii, ii] .+= k[1:dofs, 1:dofs]
    K[ii, jj] .+= k[1:dofs, (dofs + 1):(2 * dofs)]
    K[jj, ii] .+= k[(dofs + 1):(2 * dofs), 1:dofs]
    K[jj, jj] .+= k[(dofs + 1):(2 * dofs), (dofs + 1):(2 * dofs)]
    return K
end
```

It assembles element stiffness `k` into global `K` by mapping element DOFs to global DOFs using the `dofs` parameter:
- `dofs=1`: 1D spring/truss (4 scalar additions)
- `dofs=2`: 2D spring/truss (4 block-adds of 2×2 submatrices)
- `dofs=3`: 2D beam / 3D spring/truss (4 block-adds of 3×3 submatrices)

### Simplified 7 public functions

Each `*_assemble` function now delegates to `_assemble!`:

| Function | DOFs | Before | After |
|---|---|---|---|
| `d1_spring_assemble` | 1 | 6-line body | 1-liner |
| `d1_truss_assemble` | 1 | 6-line body | 1-liner |
| `d2_spring_assemble` | 2 | 18-line body | 1-liner |
| `d2_truss_assemble` | 2 | 18-line body | 1-liner |
| `d2_beam_assemble` | 3 | 38-line body | 1-liner |
| `d3_spring_assemble` | 3 | 38-line body | 1-liner |
| `d3_truss_assemble` | 3 | 38-line body | 1-liner |

### What stayed the same

- All public API signatures are unchanged
- All docstrings are unchanged (each retains element-specific terminology)
- All behavior is identical (verified by test suite)
- `_assemble!` is private (underscore prefix, not exported)

## Verification

All 109 existing tests pass without modification.

## File Size Impact

| Metric | Before | After | Delta |
|---|---|---|---|
| Source lines | 714 | 597 | **-117** |

## Future Considerations

The same `_assemble!` helper can support any new element type by passing the appropriate `dofs` parameter — no additional assembly boilerplate needed.
