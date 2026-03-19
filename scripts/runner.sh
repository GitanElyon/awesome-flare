#!/usr/bin/env bash

QUERY="${1:-}"
echo "f! title  Run Command "

if [[ -z "$QUERY" ]]; then
    echo "f! action None"
    echo "  Type a command to run…|"
    exit 0
fi

echo "f! action ExecuteAndExit"
echo "  ▶  Run: ${QUERY}|${QUERY}"
