#!/usr/bin/env bash
echo "qst! meta Clock, 1.0.0, GitanElyon, Shows clocks, timers, and alarms."
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
QUERY="${1:-}"
STORAGE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/qst/storage/clock"
TIMERS_FILE="$STORAGE_DIR/timers.tsv"
ALARMS_FILE="$STORAGE_DIR/alarms.tsv"
LOCK_FILE="$STORAGE_DIR/.lock"

ensure_store() {
	mkdir -p "$STORAGE_DIR"
	touch "$TIMERS_FILE"
}

with_lock() {
	exec 9>"$LOCK_FILE"
	flock 9
	"$@"
}

trim() {
	local value="$1"
	value="${value#"${value%%[![:space:]]*}"}"
	value="${value%"${value##*[![:space:]]}"}"
	printf '%s' "$value"
}

sanitize_text() {
	local value="$1"
	value="${value//$'\n'/ }"
	value="${value//|/¦}"
	printf '%s' "$value"
}

quote_shell_args() {
	local arg command=""
	for arg in "$@"; do
		command+="$(printf '%q ' "$arg")"
	done
	printf '%s' "${command% }"
}

b64_encode() {
	printf '%s' "$1" | base64 -w 0
}

b64_decode() {
	printf '%s' "$1" | base64 -d 2>/dev/null || true
}

format_duration() {
	local total_seconds="$1"
	printf '%02d:%02d:%02d' "$((total_seconds / 3600))" "$(((total_seconds / 60) % 60))" "$((total_seconds % 60))"
}

parse_duration() {
	local input="${1,,}"
	local total=0

	if [[ "$input" =~ ^[0-9]+$ ]]; then
		printf '%s' "$input"
		return 0
	fi

	while [[ -n "$input" ]]; do
		if [[ "$input" =~ ^([0-9]+)([hms])(.*)$ ]]; then
			local value="${BASH_REMATCH[1]}"
			local unit="${BASH_REMATCH[2]}"
			input="${BASH_REMATCH[3]}"
			case "$unit" in
				h) total=$((total + value * 3600)) ;;
				m) total=$((total + value * 60)) ;;
				s) total=$((total + value)) ;;
			esac
		else
			return 1
		fi
	done

	(( total > 0 )) || return 1
	printf '%s' "$total"
}

parse_alarm_time() {
	local input="${1,,}"
	local hour minute second=0

	if [[ "$input" =~ ^([0-9]{1,2})$ ]]; then
		hour="${BASH_REMATCH[1]}"
		minute=0
	elif [[ "$input" =~ ^([0-9]{1,2})h$ ]]; then
		hour="${BASH_REMATCH[1]}"
		minute=0
	elif [[ "$input" =~ ^([0-9]{1,2}):([0-9]{2})(:([0-9]{2}))?$ ]]; then
		hour="${BASH_REMATCH[1]}"
		minute="${BASH_REMATCH[2]}"
		second="${BASH_REMATCH[4]:-0}"
	elif [[ "$input" =~ ^([0-9]+)h([0-9]+)m([0-9]+)s?$ ]]; then
		hour="${BASH_REMATCH[1]}"
		minute="${BASH_REMATCH[2]}"
		second="${BASH_REMATCH[3]:-0}"
	elif [[ "$input" =~ ^([0-9]+)h([0-9]+)m$ ]]; then
		hour="${BASH_REMATCH[1]}"
		minute="${BASH_REMATCH[2]}"
	else
		return 1
	fi

	if (( hour > 23 || minute > 59 || second > 59 )); then
		return 1
	fi

	printf '%02d:%02d:%02d' "$hour" "$minute" "$second"
}

glyph_rows() {
	case "$1" in
		0) printf '%s' '█▀█|█ █|▀▀▀' ;;
		1) printf '%s' '  █|  █|  ▀' ;;
		2) printf '%s' '▀▀█|█▀▀|▀▀▀' ;;
		3) printf '%s' '▀▀█|▀▀█|▀▀▀' ;;
		4) printf '%s' '█ █|▀▀█|  ▀' ;;
		5) printf '%s' '█▀▀|▀▀█|▀▀▀' ;;
		6) printf '%s' '█▀▀|█▀█|▀▀▀' ;;
		7) printf '%s' '▀▀█|  █|  ▀' ;;
		8) printf '%s' '█▀█|█▀█|▀▀▀' ;;
		9) printf '%s' '█▀█|▀▀█|▀▀▀' ;;
		:) printf '%s' '▄|▄| ' ;;
		*) printf '%s' '█▀█|█ █|█▄█' ;;
	esac
}

emit_clock_rows() {
	local display_time="${1:-$(date +%H:%M:%S)}"
	local row output glyph char i first_part second_part third_part
	for row in 1 2 3; do
		output=""
		for ((i = 0; i < ${#display_time}; i++)); do
			char="${display_time:i:1}"
			glyph="$(glyph_rows "$char")"
			first_part="${glyph%%|*}"
			second_part="${glyph#*|}"
			second_part="${second_part%%|*}"
			third_part="${glyph##*|}"
			case "$row" in
				1) output+="${first_part} " ;;
				2) output+="${second_part} " ;;
				3) output+="${third_part} " ;;
		esac
		done
		printf 'qst! item  %s|%s|None @meta:nonselectable=true @meta:center=true\n' "$output" "$output"
	done
}

emit_date_line() {
	local date_text
	date_text="$(date '+%a, %d %b %Y')"
	echo "qst! item  ${date_text}|${date_text}|None @meta:nonselectable=true @meta:center=true"
}

emit_separator() {
	local line='───────────────────────────'
	echo "qst! item  ${line}|${line}|None @meta:nonselectable=true @meta:center=true"
}

parse_alarm_query() {
	local query_text="$1"
	if [[ "$query_text" =~ ^(a|alarm)[[:space:]]+([^[:space:]]+)([[:space:]]+(.*))?$ ]]; then
		printf '%s\t%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[4]:-Alarm}"
		return 0
	fi
	return 1
}

parse_timer_query() {
	local query_text="$1"
	if [[ "$query_text" =~ ^(t|timer)[[:space:]]+([^[:space:]]+)([[:space:]]+(.*))?$ ]]; then
		printf '%s\t%s\n' "${BASH_REMATCH[2]}" "${BASH_REMATCH[4]:-Timer}"
		return 0
	fi
	return 1
}

build_start_command() {
	local duration_text="$1"
	local label_text="${2:-Timer}"
	if [[ -n "$label_text" && "$label_text" != "Timer" ]]; then
		quote_shell_args "$SCRIPT_PATH" --start "$duration_text" "$label_text"
	else
		quote_shell_args "$SCRIPT_PATH" --start "$duration_text"
	fi
}

build_alarm_command() {
	local time_text="$1"
	local label_text="${2:-Alarm}"
	if [[ -n "$label_text" && "$label_text" != "Alarm" ]]; then
		quote_shell_args "$SCRIPT_PATH" --alarm-start "$time_text" "$label_text"
	else
		quote_shell_args "$SCRIPT_PATH" --alarm-start "$time_text"
	fi
}

read_timers() {
	[[ -f "$TIMERS_FILE" ]] || return 0
	while IFS=$'\t' read -r id end_epoch duration_seconds encoded_label; do
		[[ -z "${id:-}" ]] && continue
		printf '%s\t%s\t%s\t%s\n' "$id" "$end_epoch" "$duration_seconds" "$(b64_decode "$encoded_label")"
	done < "$TIMERS_FILE"
}

read_alarms() {
	[[ -f "$ALARMS_FILE" ]] || return 0
	while IFS=$'\t' read -r id target_epoch time_text encoded_label; do
		[[ -z "${id:-}" ]] && continue
		printf '%s\t%s\t%s\t%s\n' "$id" "$target_epoch" "$time_text" "$(b64_decode "$encoded_label")"
	done < "$ALARMS_FILE"
}

emit_timers() {
	local now_epoch="$(date +%s)"
	local count=0

	while IFS=$'\t' read -r id end_epoch duration_seconds label; do
		[[ -z "${id:-}" ]] && continue
		if (( end_epoch <= now_epoch )); then
			continue
		fi

		local remaining label_text duration_text
		remaining=$((end_epoch - now_epoch))
		label_text="${label:-Timer}"
		duration_text="$(format_duration "$duration_seconds")"
		printf 'qst! item  %s · %s left · %s|%s|None @meta:nonselectable=true\n' \
			"$(sanitize_text "$label_text")" \
			"$(format_duration "$remaining")" \
			"$duration_text" \
			"$(sanitize_text "$label_text") · ${duration_text} left · ${remaining}s remaining"
		count=$((count + 1))
	done < <(read_timers | sort -n -k2,2)

	if (( count == 0 )); then
		printf 'qst! item  No running timers|No running timers|None @meta:nonselectable=true @meta:center=true\n'
	fi
}

emit_alarms() {
	local now_epoch="$(date +%s)"
	local count=0

	while IFS=$'\t' read -r id target_epoch time_text label; do
		[[ -z "${id:-}" ]] && continue
		if (( target_epoch <= now_epoch )); then
			continue
		fi

		local remaining label_text
		remaining=$((target_epoch - now_epoch))
		label_text="${label:-Alarm}"
		printf 'qst! item  %s · %s · %s left|%s|None @meta:nonselectable=true\n' \
			"$(sanitize_text "$label_text")" \
			"$(sanitize_text "$time_text")" \
			"$(format_duration "$remaining")" \
			"$(sanitize_text "$label_text") · ${time_text} · ${remaining}s remaining"
		count=$((count + 1))
	done < <(read_alarms | sort -n -k2,2)

	if (( count == 0 )); then
		printf 'qst! item  No scheduled alarms|No scheduled alarms|None @meta:nonselectable=true @meta:center=true\n'
	fi
}

notify_timer() {
	local label="$1"
	local duration_seconds="$2"
	local summary="${label:-Timer}"
	local duration_text
	duration_text="$(format_duration "$duration_seconds")"

	if command -v notify-send >/dev/null 2>&1; then
		notify-send -a qst 'Clock timer finished' "${summary} is up (${duration_text})"
	else
		printf 'Timer is up: %s (%s)\n' "$summary" "$duration_text" >&2
	fi
}

finish_timer() {
	local timer_id="$1"
	local label="$2"
	local duration_seconds="$3"
	local removed=0
	local tmp_file
	tmp_file="$(mktemp "${STORAGE_DIR}/.timers.XXXXXX")"
	: > "$tmp_file"

	while IFS=$'\t' read -r id end_epoch stored_duration encoded_label; do
		[[ -z "${id:-}" ]] && continue
		if [[ "$id" == "$timer_id" ]]; then
			removed=1
			continue
		fi
		printf '%s\t%s\t%s\t%s\n' "$id" "$end_epoch" "$stored_duration" "$encoded_label" >> "$tmp_file"
	done < "$TIMERS_FILE"

	if (( removed == 1 )); then
		mv "$tmp_file" "$TIMERS_FILE"
		notify_timer "$label" "$duration_seconds"
	else
		rm -f "$tmp_file"
	fi
}

append_timer() {
	local timer_id="$1"
	local end_epoch="$2"
	local duration_seconds="$3"
	local encoded_label="$4"
	printf '%s\t%s\t%s\t%s\n' "$timer_id" "$end_epoch" "$duration_seconds" "$encoded_label" >> "$TIMERS_FILE"
}

append_alarm() {
	local alarm_id="$1"
	local target_epoch="$2"
	local time_text="$3"
	local encoded_label="$4"
	printf '%s\t%s\t%s\t%s\n' "$alarm_id" "$target_epoch" "$time_text" "$encoded_label" >> "$ALARMS_FILE"
}

worker_main() {
	local timer_id="${TIMER_ID:-}"
	local duration_seconds="${TIMER_SECONDS:-}"
	local label="${TIMER_LABEL:-Timer}"

	[[ -n "$timer_id" && -n "$duration_seconds" ]] || exit 0
	sleep "$duration_seconds"
	ensure_store
	with_lock finish_timer "$timer_id" "$label" "$duration_seconds"
}

start_timer() {
	local duration_text="$1"
	local label_text="${2:-Timer}"
	local duration_seconds
	duration_seconds="$(parse_duration "$duration_text")"

	ensure_store
	local now_epoch end_epoch timer_id encoded_label
	now_epoch="$(date +%s)"
	end_epoch=$((now_epoch + duration_seconds))
	timer_id="$(date +%s%N)"
	encoded_label="$(b64_encode "$label_text")"

	with_lock append_timer "$timer_id" "$end_epoch" "$duration_seconds" "$encoded_label"
	TIMER_ID="$timer_id" TIMER_SECONDS="$duration_seconds" TIMER_LABEL="$label_text" nohup "$SCRIPT_PATH" --worker >/dev/null 2>&1 &
}

notify_alarm() {
	local label="$1"
	local time_text="$2"
	local summary="${label:-Alarm}"

	if command -v notify-send >/dev/null 2>&1; then
		notify-send -a qst 'Clock alarm' "${summary} is going off at ${time_text}"
	else
		printf 'Alarm is going off: %s at %s\n' "$summary" "$time_text" >&2
	fi
}

finish_alarm() {
	local alarm_id="$1"
	local label="$2"
	local time_text="$3"
	local removed=0
	local tmp_file
	tmp_file="$(mktemp "${STORAGE_DIR}/.alarms.XXXXXX")"
	: > "$tmp_file"

	while IFS=$'\t' read -r id target_epoch stored_time encoded_label; do
		[[ -z "${id:-}" ]] && continue
		if [[ "$id" == "$alarm_id" ]]; then
			removed=1
			continue
		fi
		printf '%s\t%s\t%s\t%s\n' "$id" "$target_epoch" "$stored_time" "$encoded_label" >> "$tmp_file"
	done < "$ALARMS_FILE"

	if (( removed == 1 )); then
		mv "$tmp_file" "$ALARMS_FILE"
		notify_alarm "$label" "$time_text"
	else
		rm -f "$tmp_file"
	fi
}

start_alarm() {
	local time_text="$1"
	local label_text="${2:-Alarm}"
	local normalized_time target_epoch alarm_id encoded_label now_epoch delay_seconds
	normalized_time="$(parse_alarm_time "$time_text")"
	now_epoch="$(date +%s)"
	target_epoch="$(date -d "today ${normalized_time}" +%s)"
	if (( target_epoch <= now_epoch )); then
		target_epoch="$(date -d "tomorrow ${normalized_time}" +%s)"
	fi
	delay_seconds=$((target_epoch - now_epoch))

	ensure_store
	alarm_id="$(date +%s%N)"
	encoded_label="$(b64_encode "$label_text")"

	with_lock append_alarm "$alarm_id" "$target_epoch" "$normalized_time" "$encoded_label"
	ALARM_ID="$alarm_id" ALARM_TIME="$normalized_time" ALARM_LABEL="$label_text" ALARM_DELAY="$delay_seconds" nohup "$SCRIPT_PATH" --alarm-worker >/dev/null 2>&1 &
}

worker_alarm_main() {
	local alarm_id="${ALARM_ID:-}"
	local time_text="${ALARM_TIME:-}"
	local label="${ALARM_LABEL:-Alarm}"
	local delay_seconds="${ALARM_DELAY:-}"

	[[ -n "$alarm_id" && -n "$time_text" && -n "$delay_seconds" ]] || exit 0
	sleep "$delay_seconds"
	ensure_store
	with_lock finish_alarm "$alarm_id" "$label" "$time_text"
}

render_help() {
	echo 'qst! title Clock'
	echo 'qst! action None'
	echo 'qst! item  clock                 show the current clock and running timers|clock|None @meta:nonselectable=true'
	echo 'qst! item  clock t <duration>     preview a timer and press enter to start it|clock t 5m30s|None @meta:nonselectable=true'
	echo 'qst! item  clock t <duration> <label>  start a labeled timer|clock t 5m30s tea|None @meta:nonselectable=true'
	echo 'qst! item  clock a <time>         preview an alarm and press enter to start it|clock a 16|None @meta:nonselectable=true'
	echo 'qst! item  clock a <time> <label>  start a labeled alarm|clock a 16 tea|None @meta:nonselectable=true'
	echo 'qst! item  clock h                show this help|clock h|None @meta:nonselectable=true'
}

render_timer_preview() {
	local duration_text="$1"
	local label_text="${2:-Timer}"
	local duration_seconds display_duration start_command safe_label
	if ! duration_seconds="$(parse_duration "$duration_text")"; then
		echo 'qst! item  Type a duration (XXhYYmZZs)|Type a duration (XXhYYmZZs)|None @meta:nonselectable=true @meta:center=true'
		return 0
	fi

	display_duration="$(format_duration "$duration_seconds")"
	safe_label="$(sanitize_text "$label_text")"
	start_command="$(build_start_command "$duration_text" "$label_text")"

	if [[ "$label_text" != "Timer" ]]; then
		echo "qst! item  Start timer: ${display_duration} · ${safe_label}|${start_command}|Execute,RefreshResults"
	else
		echo "qst! item  Start timer: ${display_duration}|${start_command}|Execute,RefreshResults"
	fi
}

render_alarm_preview() {
	local time_text="$1"
	local label_text="${2:-Alarm}"
	local normalized_time start_command safe_label

	if ! normalized_time="$(parse_alarm_time "$time_text")"; then
		echo 'qst! item  Type an alarm time (HH or HHhMMm or HH:MM)|Type an alarm time (HH or HHhMMm or HH:MM)|None @meta:nonselectable=true @meta:center=true'
		return 0
	fi

	safe_label="$(sanitize_text "$label_text")"
	start_command="$(build_alarm_command "$time_text" "$label_text")"

	if [[ "$label_text" != "Alarm" ]]; then
		echo "qst! item  Start alarm: ${normalized_time} · ${safe_label}|${start_command}|Execute,RefreshResults"
	else
		echo "qst! item  Start alarm: ${normalized_time}|${start_command}|Execute,RefreshResults"
	fi
}

emit_clock_section() {
	emit_clock_rows
	emit_date_line
	if [[ -n "${1:-}" ]]; then
		echo "qst! item  ${1}|${1}|None @meta:nonselectable=true @meta:active=true"
	fi
}

main() {
	if [[ "${1:-}" == "--worker" ]]; then
		worker_main
		exit 0
	fi

	if [[ "${1:-}" == "--alarm-worker" ]]; then
		worker_alarm_main
		exit 0
	fi

	if [[ "${1:-}" == "--start" ]]; then
		start_timer "${2:-}" "${3:-Timer}"
		exit 0
	fi

	if [[ "${1:-}" == "--alarm-start" ]]; then
		start_alarm "${2:-}" "${3:-Alarm}"
		exit 0
	fi

	local query
	query="$(trim "$QUERY")"

	if [[ "$query" == "-h" || "$query" == "--help" || "$query" == "help" || "$query" == "h" ]]; then
		render_help
		exit 0
	fi

	if [[ "$query" =~ ^(a|alarm)[[:space:]]+ ]]; then
		local alarm_query time_text label_text
		if alarm_query="$(parse_alarm_query "$query")"; then
			time_text="${alarm_query%%$'\t'*}"
			label_text="${alarm_query#*$'\t'}"
		fi

		echo 'qst! title Clock'
		echo 'qst! action None'
		emit_clock_rows
		emit_date_line
		if [[ -n "${time_text:-}" ]]; then
			render_alarm_preview "$time_text" "${label_text:-Alarm}"
		else
			echo 'qst! item  Type an alarm time (HH or HHhMMm or HH:MM)|Type an alarm time (HH or HHhMMm or HH:MM)|None @meta:nonselectable=true @meta:center=true'
		fi
		emit_separator
		emit_timers
		emit_alarms
		exit 0
	fi

	if [[ "$query" =~ ^(t|timer)[[:space:]]+ ]]; then
		local timer_query duration_text label_text
		if timer_query="$(parse_timer_query "$query")"; then
			duration_text="${timer_query%%$'\t'*}"
			label_text="${timer_query#*$'\t'}"
		fi

		echo 'qst! title Clock'
		echo 'qst! action None'
		emit_clock_rows
		emit_date_line
		if [[ -n "${duration_text:-}" ]]; then
			render_timer_preview "$duration_text" "${label_text:-Timer}"
		else
			echo 'qst! item  Type a duration (XXhYYmZZs)|Type a duration (XXhYYmZZs)|None @meta:nonselectable=true @meta:center=true'
		fi
		emit_separator
		emit_timers
		exit 0
	fi

	ensure_store
	echo 'qst! title Clock'
	echo 'qst! action None'
	emit_clock_rows
	emit_date_line
	emit_separator
	emit_timers
	emit_alarms
}

main "$@"
