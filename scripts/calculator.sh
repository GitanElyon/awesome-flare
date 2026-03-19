#!/usr/bin/env bash

QUERY="${1:-}"
expr="$(echo "$QUERY" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"

format_number() {
    local n="$1"
    if [[ "$n" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        if [[ "$n" == *.* ]]; then
            n="$(echo "$n" | sed -E 's/0+$//; s/\.$//')"
        fi
        echo "$n"
    else
        echo "Error"
    fi
}

calc_eval() {
    local input="$1"
    input="${input//^/**}"
    input="${input//ln(/l(}"
    input="${input//LOG(/l(}"
    input="${input//SIN(/s(}"
    input="${input//COS(/c(}"
    input="${input//SQRT(/sqrt(}"

    local out
    out="$(echo "scale=12; $input" | bc -l 2>/dev/null | tail -n1)"
    echo "$out"
}

numerical_diff() {
    local fx="$1"
    local var="$2"
    local at="$3"
    local h="0.00000001"

    local plus minus
    plus="$(echo "scale=12; $at + $h" | bc -l 2>/dev/null)"
    minus="$(echo "scale=12; $at - $h" | bc -l 2>/dev/null)"

    local f_plus f_minus
    f_plus="$(calc_eval "${fx//$var/($plus)}")"
    f_minus="$(calc_eval "${fx//$var/($minus)}")"

    echo "scale=12; ($f_plus - $f_minus) / (2 * $h)" | bc -l 2>/dev/null
}

numerical_limit() {
    local fx="$1"
    local var="$2"
    local at="$3"
    local h="0.0000000001"

    local left right
    left="$(calc_eval "${fx//$var/($at - $h)}")"
    right="$(calc_eval "${fx//$var/($at + $h)}")"

    echo "scale=12; ($left + $right) / 2" | bc -l 2>/dev/null
}

numerical_integrate() {
    local fx="$1"
    local var="$2"
    local a="$3"
    local b="$4"
    local steps=400

    local h
    h="$(echo "scale=12; ($b - $a) / $steps" | bc -l 2>/dev/null)"

    local sum=0
    local i=0
    while (( i < steps )); do
        local x
        x="$(echo "scale=12; $a + ($i + 0.5) * $h" | bc -l 2>/dev/null)"
        local y
        y="$(calc_eval "${fx//$var/($x)}")"
        sum="$(echo "scale=12; $sum + $y" | bc -l 2>/dev/null)"
        i=$((i + 1))
    done

    echo "scale=12; $sum * $h" | bc -l 2>/dev/null
}

if [[ -z "$expr" ]]; then
    echo "f! single |"
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
    echo "f! single $expr|Error"
else
    echo "f! single $expr|$formatted"
fi
