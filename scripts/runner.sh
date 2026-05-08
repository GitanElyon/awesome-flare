#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Run Command, 1.0.0, GitanElyon, Runs an arbitrary shell command."

QUERY="${1:-}"
echo "qst! title  Run Command "

if [[ -z "$QUERY" ]]; then
    echo "qst! action None"
    echo "  Type a command to run…|"
    exit 0
fi

echo "qst! action Execute,ExitApp"
echo "  ▶  Run: ${QUERY}|${QUERY}"
