#!/usr/bin/env bash

QUERY="${1:-}"

echo "f! title Sudo"
echo "f! action SetSearchQuery"

if [[ -z "$QUERY" ]]; then
    echo "  Prefix command with sudo authentication|sudo "
    echo "  Example: sudo gparted|sudo gparted"
    exit 0
fi

echo "  Run with sudo: ${QUERY}|sudo ${QUERY} @meta:urgent=true"