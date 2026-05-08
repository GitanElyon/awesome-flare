#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Calculator, 1.0.0, GitanElyon, Evaluates quick arithmetic expressions."

QUERY="${1:-}"
expr="$(echo "$QUERY" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

if command -v bc >/dev/null 2>&1; then
    CALC_BACKEND="bc"
elif command -v python3 >/dev/null 2>&1; then
    CALC_BACKEND="python3"
elif command -v awk >/dev/null 2>&1; then
    CALC_BACKEND="awk"
else
    CALC_BACKEND=""
fi

format_number() {
    local n="$1"
    if [[ "$n" =~ ^-?[0-9]+(\.[0-9]+)?([eE][-+]?[0-9]+)?$ ]]; then
        if [[ "$n" == *.* && "$n" != *[eE]* ]]; then
            n="$(echo "$n" | sed -E 's/0+$//; s/\.$//')"
        fi
        echo "$n"
    else
        echo "Error"
    fi
}

calc_eval() {
    local input="$1"

    if [[ "$CALC_BACKEND" == "bc" ]]; then
        input="${input//^/**}"
        input="$(echo "$input" | sed -E \
            -e 's/\<[Ll][Nn][[:space:]]*\(/l(/g' \
            -e 's/\<[Ll][Oo][Gg][[:space:]]*\(/l(/g' \
            -e 's/\<[Ss][Ii][Nn][[:space:]]*\(/s(/g' \
            -e 's/\<[Cc][Oo][Ss][[:space:]]*\(/c(/g' \
            -e 's/\<[Ss][Qq][Rr][Tt][[:space:]]*\(/sqrt(/g')"

        echo "scale=12; $input" | bc -l 2>/dev/null | tail -n1
        return
    fi

    if [[ "$CALC_BACKEND" == "python3" ]]; then
        python3 - "$input" <<'PY'
import math
import re
import sys

expr = sys.argv[1]
expr = expr.replace("^", "**")

replacements = {
    "LN": "log",
    "LOG": "log",
    "SIN": "sin",
    "COS": "cos",
    "TAN": "tan",
    "SQRT": "sqrt",
    "ABS": "abs",
    "PI": "pi",
    "E": "e",
}

for old, new in replacements.items():
    expr = re.sub(rf"\b{old}\b", new, expr, flags=re.IGNORECASE)

safe = {
    "sin": math.sin,
    "cos": math.cos,
    "tan": math.tan,
    "sqrt": math.sqrt,
    "log": math.log,
    "exp": math.exp,
    "floor": math.floor,
    "ceil": math.ceil,
    "pow": pow,
    "abs": abs,
    "pi": math.pi,
    "e": math.e,
}

try:
    value = eval(expr, {"__builtins__": {}}, safe)
    if isinstance(value, bool):
        print("1" if value else "0")
    elif isinstance(value, (int, float)):
        print(f"{value:.12f}")
    else:
        print("")
except Exception:
    print("")
PY
        return
    fi

    if [[ "$CALC_BACKEND" == "awk" ]]; then
        input="$(echo "$input" | sed -E \
            -e 's/\<[Ll][Nn][[:space:]]*\(/log(/g' \
            -e 's/\<[Ll][Oo][Gg][[:space:]]*\(/log(/g' \
            -e 's/\<[Ss][Ii][Nn][[:space:]]*\(/sin(/g' \
            -e 's/\<[Cc][Oo][Ss][[:space:]]*\(/cos(/g' \
            -e 's/\<[Tt][Aa][Nn][[:space:]]*\(/tan(/g' \
            -e 's/\<[Ss][Qq][Rr][Tt][[:space:]]*\(/sqrt(/g' \
            -e 's/\<[Pp][Ii]\>/pi/g' \
            -e 's/\<[Ee]\>/e/g')"

        awk "BEGIN { pi=atan2(0,-1); e=exp(1); printf(\"%.12f\\n\", ($input)) }" 2>/dev/null | tail -n1
        return
    fi

    echo ""
}

numerical_diff() {
    local fx="$1"
    local var="$2"
    local at="$3"
    local h="0.00000001"

    local plus minus
    plus="$(calc_eval "$at + $h")"
    minus="$(calc_eval "$at - $h")"

    local f_plus f_minus
    f_plus="$(calc_eval "${fx//$var/($plus)}")"
    f_minus="$(calc_eval "${fx//$var/($minus)}")"

    calc_eval "($f_plus - $f_minus) / (2 * $h)"
}

numerical_limit() {
    local fx="$1"
    local var="$2"
    local at="$3"
    local h="0.0000000001"

    local left right
    left="$(calc_eval "${fx//$var/($at - $h)}")"
    right="$(calc_eval "${fx//$var/($at + $h)}")"

    calc_eval "($left + $right) / 2"
}

numerical_integrate() {
    local fx="$1"
    local var="$2"
    local a="$3"
    local b="$4"
    local steps=400

    local h
    h="$(calc_eval "($b - $a) / $steps")"

    local sum=0
    local i=0
    while (( i < steps )); do
        local x
        x="$(calc_eval "$a + ($i + 0.5) * $h")"
        local y
        y="$(calc_eval "${fx//$var/($x)}")"
        sum="$(calc_eval "$sum + $y")"
        i=$((i + 1))
    done

    calc_eval "$sum * $h"
}

if [[ -z "$expr" ]]; then
    echo "qst! single |"
    exit 0
fi

if [[ -z "$CALC_BACKEND" ]]; then
    echo "qst! single $expr|Error: install bc, python3, or awk"
    exit 0
fi

lower="${expr,,}"
result=""

if [[ "$lower" =~ ^diff\((.*)\)$ ]]; then
    args="${BASH_REMATCH[1]}"
    IFS=',' read -r fx var at <<< "$args"
    fx="$(echo "$fx" | xargs)"
    var="$(echo "$var" | xargs)"
    at="$(echo "$at" | xargs)"
    result="$(numerical_diff "$fx" "$var" "$at")"
elif [[ "$lower" =~ ^limit\((.*)\)$ ]]; then
    args="${BASH_REMATCH[1]}"
    IFS=',' read -r fx var at <<< "$args"
    fx="$(echo "$fx" | xargs)"
    var="$(echo "$var" | xargs)"
    at="$(echo "$at" | xargs)"
    result="$(numerical_limit "$fx" "$var" "$at")"
elif [[ "$lower" =~ ^integrate\((.*)\)$ ]]; then
    args="${BASH_REMATCH[1]}"
    IFS=',' read -r fx var a b <<< "$args"
    fx="$(echo "$fx" | xargs)"
    var="$(echo "$var" | xargs)"
    a="$(echo "$a" | xargs)"
    b="$(echo "$b" | xargs)"
    result="$(numerical_integrate "$fx" "$var" "$a" "$b")"
else
    result="$(calc_eval "$expr")"
fi

formatted="$(format_number "$result")"
if [[ "$formatted" == "" || "$formatted" == "Error" ]]; then
    echo "qst! single $expr|Error"
else
    echo "qst! single $expr|$formatted"
fi
