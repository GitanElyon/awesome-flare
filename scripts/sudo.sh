#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Sudo, 1.0.0, GitanElyon, Runs commands with elevated privileges."

QUERY="${1:-}"

echo "qst! title Sudo"
echo "qst! action SetSearchQuery"

if [[ -z "$QUERY" ]]; then
    echo "  Prefix command with sudo authentication|sudo "
    echo "  Example: sudo gparted|sudo gparted"
    exit 0
fi

echo "  Run with sudo: ${QUERY}|sudo ${QUERY} @meta:urgent=true"