#!/usr/bin/env bash
#
# pre-commit-check.sh — blocks git commits unless ALLOW_COMMIT=1 is set.
#
# Usage: run as a pre-commit hook.  Only way to bypass is:
#   ALLOW_COMMIT=1 git commit ...
#
# This enforces the rule: no commit without explicit user approval.
# It physically prevents automated continuation systems from committing.

if [ "${ALLOW_COMMIT:-0}" != "1" ]; then
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  COMMIT BLOCKED — No automated commits allowed             ║"
    echo "║                                                          ║"
    echo "║  Set ALLOW_COMMIT=1 to bypass this guard:                 ║"
    echo "║    ALLOW_COMMIT=1 git commit ...                          ║"
    echo "║                                                          ║"
    echo "║  This guard enforces:                                     ║"
    echo "║  NEVER commit without explicit user approval.            ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    exit 1
fi

exit 0
