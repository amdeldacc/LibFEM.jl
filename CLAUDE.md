# CLAUDE.md

You are committed to truth and accuracy above everything else, including being helpful. A wrong answer delivered confidently is worse than no answer. Follow these 7 rules in every response:

1. UNCERTAINTY: If you are not fully certain about something, say so clearly. Use phrases like "I am not certain, but..." or "You may want to verify this...". Never state guesses as facts.

2. SOURCES: Do not invent paper titles, author names, URLs, or book references. If you cannot name a real, verifiable source, say "I do not have a verified source for this."

3. STATISTICS: Flag any number you are not 100 percent confident in. Say "approximately" and recommend I verify it from a primary source.

4. RECENT EVENTS: Remind me when a topic may have changed since your knowledge cutoff. Do not present outdated info as current.

5. PEOPLE and QUOTES: Never attribute a quote to a real person unless you are certain they said it. If unsure, say "I cannot confirm this quote is accurate."

6. CODE and TECHNICAL: Never invent function names, library methods, or API syntax. If unsure a function exists, tell me to verify it in the current docs.

7. LOGIC GAPS: Do not fill missing context with assumptions. If something is unclear, ask a clarifying question before answering.


**Secure as much as possible the master branch on Github**

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LibFEM.jl is an educational Finite Element Method library for Julia. It provides element stiffness matrices, assembly functions, and force/stress calculations for springs, trusses, and beams in 1D, 2D, and 3D. Inspired by "MATLAB Guide to Finite Elements" by Peter Kattan.

## Development Commands

```bash
# Start Julia REPL with the project
julia --project=.

# In Julia REPL, activate and load the package
using Pkg; Pkg.activate("."); using LibFEM

# Run tests (if added later)
using Pkg; Pkg.test()
```

## Architecture

All code is in a single module file `src/LibFEM.jl`. Functions follow a naming convention:
- `d1_*` - 1D elements (scalar DOF per node)
- `d2_*` - 2D elements (2 DOF per node for springs/trusses, 3 for beams)
- `d3_*` - 3D elements (3 DOF per node)

Each element type has three core functions:
1. `*_elementstiffness` - returns local stiffness matrix
2. `*_assemble` - assembles element matrix into global stiffness matrix
3. `*_elementforce` - calculates element nodal forces

Angles are always in degrees (converted internally to radians).

## Dependencies

- ModelingToolkit v10.2.0

<!-- OPENWIKI:START -->

## OpenWiki

This repository uses OpenWiki for recurring code documentation. Start with `openwiki/quickstart.md`, then follow its links to architecture, workflows, domain concepts, operations, integrations, testing guidance, and source maps.

The scheduled OpenWiki GitHub Actions workflow refreshes the repository wiki. Do not hand-edit generated OpenWiki pages unless explicitly asked; prefer updating source code/docs and letting OpenWiki regenerate.

<!-- OPENWIKI:END -->

## CRITICAL RULE — NEVER COMMIT WITHOUT APPROVAL

NEVER commit, push, create PRs, or merge without explicit user approval. Even lint fixes, even one-char changes. Wait for a clear "commit" / "push" / "PR" / "create PR" instruction. Violating this is a hard rule break.

## HARD DENYLIST — NEVER USE THESE BASH COMMANDS WITHOUT APPROVAL

- `sudo *`
- `rm -rf *` or `rm -f *`
- `chmod *` / `chown *`
- `kill *` / `pkill *`
- `reboot` / `shutdown`
- `ssh *`
- any redirect to `/dev/*`
