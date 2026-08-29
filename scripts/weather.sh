#!/usr/bin/env bash
echo "qst! meta Weather, 1.0.0, GitanElyon, Shows current weather and forecast for your area."
set -euo pipefail

QUERY="${1:-}"

sanitize_text() {
    local text="$1"
    text="${text//$'\n'/ }"
    text="${text//|/¦}"
    printf '%s' "$text"
}

emit_row() {
    local title="$1" value="$2"
    local display
    display="$(sanitize_text "$value")"
    printf 'qst! item  %s  %s|%s|None @meta:nonselectable=true @meta:display=%s  %s\n' "$title" "$display" "$title" "$title" "$display"
}

section() {
    local json="$1" name="$2"
    printf '%s\n' "$json" | awk -v n="\"$name\":" '
        index($0, n " [") { found=1; next }
        found && /^  \],?$/ { exit }
        found { print }
    '
}

field() {
    local json="$1" key="$2"
    printf '%s\n' "$json" | awk -v k="\"$key\":" '
        index($0, k " \"") {
            line=$0
            sub(/^.*": "/, "", line)
            sub(/",?$/, "", line)
            print line
            exit
        }'
}

first_value() {
    local json="$1"
    printf '%s\n' "$json" | awk '
        index($0, "\"value\": \"") {
            line=$0
            sub(/^.*": "/, "", line)
            sub(/",?$/, "", line)
            print line
            exit
        }'
}

day_block() {
    local json="$1" n="$2"
    printf '%s\n' "$json" | awk -v n="$n" '
        /"astronomy": \[/ { d++ }
        d == n { print }
        d > n { exit }
    '
}

max_rain() {
    local json="$1" rain
    rain="$(printf '%s\n' "$json" | grep -o '"chanceofrain": *"[0-9]*"' | grep -o '[0-9]*' | sort -n | tail -1)" || rain="0"
    printf '%s' "$rain"
}

render_help() {
    echo "qst! title  Weather Help "
    echo "qst! action None"
    echo 'qst! item  weather                current conditions for your area|weather|None @meta:nonselectable=true'
    echo 'qst! item  weather <location>     current conditions for a place|weather Tokyo|None @meta:nonselectable=true'
    echo 'qst! item  weather f              three-day forecast|weather f|None @meta:nonselectable=true'
    echo 'qst! item  weather f <location>   forecast for a place|weather f Tokyo|None @meta:nonselectable=true'
    echo 'qst! item  weather h              show this help|weather h|None @meta:nonselectable=true'
}

MODE="current"
LOCATION=""
case "$QUERY" in
    h|help|--help) MODE="help" ;;
    v|version|--version) MODE="version" ;;
    f|forecast) MODE="forecast" ;;
    f\ *|forecast\ *) MODE="forecast"; LOCATION="${QUERY#* }" ;;
    *) LOCATION="$QUERY" ;;
esac

if [[ "$MODE" == "help" ]]; then
    render_help
    exit 0
fi

if [[ "$MODE" == "version" ]]; then
    echo "qst! single Weather 1.0.0|1.0.0"
    exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "qst! single |Error: curl is required for weather"
    exit 0
fi

location_url="${LOCATION// /%20}"
location_url="${location_url//,/%2C}"

JSON="$(curl -sf --max-time 10 "https://wttr.in/${location_url}?format=j1&u")" || JSON=""

if [[ -z "$JSON" || "$JSON" != *"current_condition"* ]]; then
    echo "qst! single |Location not found or no network access"
    exit 0
fi

CURRENT="$(section "$JSON" current_condition)"
AREA="$(section "$JSON" nearest_area)"

location_text="$(first_value "$AREA")"
region="$(field "$AREA" region)"
if [[ -n "$region" && "$region" != "$location_text" ]]; then
    location_text="${location_text}, ${region}"
fi

if [[ "$MODE" == "forecast" ]]; then
    echo "qst! title  Weather Forecast - ${location_text} "
    echo "qst! action None"

    for day in 1 2 3; do
        block="$(day_block "$JSON" "$day")"
        [[ -z "$block" ]] && continue

        date_raw="$(field "$block" date)"
        display_date="$(date -d "$date_raw" "+%a %d %b" 2>/dev/null)" || display_date="$date_raw"
        avg_temp="$(field "$block" avgtempC)"
        max_temp="$(field "$block" maxtempC)"
        min_temp="$(field "$block" mintempC)"
        rain="$(max_rain "$block")"

        display="${avg_temp}°C (${min_temp}/${max_temp}) · rain ${rain}%"
        emit_row "$display_date" "$display"
    done
    exit 0
fi

temp="$(field "$CURRENT" temp_C)"
feels="$(field "$CURRENT" FeelsLikeC)"
desc="$(first_value "$CURRENT")"
wind_dir="$(field "$CURRENT" winddir16Point)"
wind_km="$(field "$CURRENT" windspeedKmph)"
humidity="$(field "$CURRENT" humidity)"
uv="$(field "$CURRENT" uvIndex)"
visibility="$(field "$CURRENT" visibility)"

sunrise=""
sunset=""
if block="$(day_block "$JSON" 1)"; then
    sunrise="$(field "$block" sunrise)"
    sunset="$(field "$block" sunset)"
fi

echo "qst! title  Weather - ${location_text} "
echo "qst! action None"

[[ -n "$desc" ]] && emit_row "Condition" "$desc"
[[ -n "$temp" ]] && emit_row "Temperature" "${temp}°C (feels ${feels}°C)"
[[ -n "$wind_dir" || -n "$wind_km" ]] && emit_row "Wind" "${wind_dir} ${wind_km} km/h"
[[ -n "$humidity" ]] && emit_row "Humidity" "${humidity}%"
[[ -n "$uv" ]] && emit_row "UV Index" "$uv"
[[ -n "$visibility" ]] && emit_row "Visibility" "${visibility} km"
[[ -n "$sunrise" ]] && emit_row "Sunrise" "$sunrise"
[[ -n "$sunset" ]] && emit_row "Sunset" "$sunset"
