#!/usr/bin/env bash
# Pre-commit hook helper: run ocr review on staged .jl / .m files.
#
# Usage:
#   scripts/pre-commit-ocr.sh         # advisory mode (never blocks)
#   scripts/pre-commit-ocr.sh --block # blocks commit if OCR finds issues
set -euo pipefail

# --- config ---
EXTENSIONS="\.jl$|\.m$"
BACKGROUND="LibFEM.jl Julia FEA. Check type stability, dims, assembly, docstrings, test coverage. Pre-commit hook."
BLOCK=false
if [ "${1:-}" = "--block" ]; then
    BLOCK=true
fi

# --- check staged files for relevant extensions ---
STAGED=$(git diff --cached --name-only --diff-filter=ACMR | grep -E "$EXTENSIONS" || true)

if [ -z "$STAGED" ]; then
    exit 0
fi

echo ""
echo "━━━ OCR pre-commit review ━━━"
echo "Staged files to review:"
echo "$STAGED" | sed 's/^/  • /'
echo ""

# --- stash unstaged changes to review only staged content ---
STASH_NAME="ocr-pre-commit-$(date +%s)"
if ! git diff --quiet && ! git diff --cached --quiet; then
    git stash push --keep-index --message "$STASH_NAME" --quiet
    STASHED=true
else
    STASHED=false
fi

# --- run OCR ---
if [ "$BLOCK" = true ]; then
    # Run in JSON mode to count comments for blocking decision
    REVIEW_JSON=$(ocr review --format json --audience agent --background "$BACKGROUND" 2>/dev/null || true)
    echo "$REVIEW_JSON"

    COMMENT_COUNT=$(echo "$REVIEW_JSON" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    comments = data.get('comments', [])
    print(len(comments))
except Exception:
    print(-1)
" 2>/dev/null || echo -1)

    echo ""
    if [ "$COMMENT_COUNT" -gt 0 ] 2>/dev/null; then
        if [ "$COMMENT_COUNT" -eq 1 ]; then
            echo "✋ 1 OCR finding — commit BLOCKED. Review above, fix, then commit again."
        else
            echo "✋ $COMMENT_COUNT OCR findings — commit BLOCKED. Review above, fix, then commit again."
        fi
        BLOCKED=true
    else
        echo "✓ No OCR findings."
        BLOCKED=false
    fi
else
    # Advisory mode: human-readable output, never blocks
    ocr review --background "$BACKGROUND" || true
    BLOCKED=false
fi

# --- restore unstaged changes ---
if [ "$STASHED" = true ]; then
    git stash pop --quiet 2>/dev/null || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ "$BLOCKED" = true ]; then
    exit 1
fi
