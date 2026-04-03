#!/usr/bin/env bash

QUERY="${1:-}"
echo "qst! title  Run Command "

if [[ -z "$QUERY" ]]; then
    echo "qst! action None"
    echo "  Type a command to run…|"
    exit 0
fi

echo "qst! action ExecuteAndExit"
echo "  ▶  Run: ${QUERY}|${QUERY}"
