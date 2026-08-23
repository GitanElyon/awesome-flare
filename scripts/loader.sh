#!/usr/bin/env bash
echo "qst! meta Script Loader, 1.0.0, GitanElyon, Browses and installs awesome-qst scripts."
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
RAW_QUERY="$*"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
QST_DIR="${CONFIG_HOME}/qst"
SCRIPT_DIR="${QST_DIR}/scripts"
ALIAS_FILE="${QST_DIR}/alias.toml"
STORAGE_DIR="${QST_DIR}/storage/loader"
CACHE_FILE="${STORAGE_DIR}/catalog.tsv"

REPO_OWNER="GitanElyon"
REPO_NAME="awesome-qst"
REPO_BRANCH="main"
API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/scripts?ref=${REPO_BRANCH}"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${REPO_BRANCH}/scripts"

declare -A ALIASES=()

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

read_script_metadata() {
	local script_path="$1"
	local line name version author description

	line="$(sed -n 's/^echo "qst! meta //p' "$script_path" 2>/dev/null | head -n1)"
	[[ -n "$line" ]] || return 1
	line="${line%\"}"
	IFS=',' read -r name version author description <<< "$line"
	printf '%s\t%s\t%s\t%s' \
		"$(sanitize_text "$(trim "$name")")" \
		"$(sanitize_text "$(trim "$version")")" \
		"$(sanitize_text "$(trim "$author")")" \
		"$(sanitize_text "$(trim "$description")")"
}

emit_script_metadata_rows() {
	local script_path="$1"
	local meta name version author description

	meta="$(read_script_metadata "$script_path")" || return 0
	IFS=$'\t' read -r name version author description <<< "$meta"

	if [[ -n "$name" ]]; then
		echo "  Name: ${name}|${name}|None @meta:nonselectable=true"
	fi
	if [[ -n "$version" ]]; then
		echo "  Version: ${version}|${version}|None @meta:nonselectable=true"
	fi
	if [[ -n "$author" ]]; then
		echo "  Author: ${author}|${author}|None @meta:nonselectable=true"
	fi
	if [[ -n "$description" ]]; then
		echo "  Description: ${description}|${description}|None @meta:nonselectable=true"
	fi
}

quote_shell_args() {
	local arg command=""
	for arg in "$@"; do
		command+="$(printf '%q ' "$arg")"
	done
	printf '%s' "${command% }"
}

http_get() {
	local url="$1"
	if command -v curl >/dev/null 2>&1; then
		curl -fsSL --retry 2 "$url"
		return 0
	fi
	if command -v wget >/dev/null 2>&1; then
		wget -qO- "$url"
		return 0
	fi
	return 1
}

ensure_store() {
	mkdir -p "$STORAGE_DIR" "$SCRIPT_DIR"
}

refresh_catalog_cache() {
	local tmp_json tmp_tsv
	tmp_json="$(mktemp "${STORAGE_DIR}/catalog.XXXXXX.json")"
	tmp_tsv="$(mktemp "${STORAGE_DIR}/catalog.XXXXXX.tsv")"

	if ! http_get "$API_URL" > "$tmp_json"; then
		rm -f "$tmp_json" "$tmp_tsv"
		return 1
	fi

	awk '
		function flush_entry() {
			if (type == "file" && name != "" && repo_path != "" && download_url != "") {
				print name "\t" repo_path "\t" download_url "\t" html_url
			}
			name = repo_path = download_url = html_url = type = ""
		}

		/^[[:space:]]*"name": / {
			name = $0
			sub(/^[[:space:]]*"name": "/, "", name)
			sub(/",?$/, "", name)
			next
		}

		/^[[:space:]]*"path": / {
			repo_path = $0
			sub(/^[[:space:]]*"path": "/, "", repo_path)
			sub(/",?$/, "", repo_path)
			next
		}

		/^[[:space:]]*"download_url": / {
			download_url = $0
			sub(/^[[:space:]]*"download_url": /, "", download_url)
			sub(/,[[:space:]]*$/, "", download_url)
			sub(/^null$/, "", download_url)
			sub(/^"/, "", download_url)
			sub(/"$/, "", download_url)
			next
		}

		/^[[:space:]]*"html_url": / {
			html_url = $0
			sub(/^[[:space:]]*"html_url": "/, "", html_url)
			sub(/",?$/, "", html_url)
			next
		}

		/^[[:space:]]*"type": / {
			type = $0
			sub(/^[[:space:]]*"type": "/, "", type)
			sub(/",?$/, "", type)
			flush_entry()
			next
		}
	' "$tmp_json" | sort -t $'\t' -k1,1 > "$tmp_tsv"

	mv "$tmp_tsv" "$CACHE_FILE"
	rm -f "$tmp_json"
}

ensure_catalog() {
	local cache_age max_age=86400
	ensure_store
	if [[ ! -f "$CACHE_FILE" ]]; then
		refresh_catalog_cache
		return $?
	fi
	cache_age="$(($(date +%s) - $(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)))"
	if [[ "$cache_age" -ge "$max_age" ]]; then
		refresh_catalog_cache
		return $?
	fi
	return 0
}

load_aliases() {
	ALIASES=()
	[[ -f "$ALIAS_FILE" ]] || return 0

	local has_scripts_section=0 in_scripts_section=0 section line key value
	if grep -Fq "[scripts]" "$ALIAS_FILE"; then
		has_scripts_section=1
	fi

	while IFS= read -r line; do
		[[ "$line" =~ ^[[:space:]]*# ]] && continue

		if [[ "$line" =~ ^[[:space:]]*\[(.*)\][[:space:]]*$ ]]; then
			section="${BASH_REMATCH[1]}"
			if [[ "$section" == "scripts" ]]; then
				in_scripts_section=1
			else
				in_scripts_section=0
			fi
			continue
		fi

		[[ "$line" != *"="* ]] && continue

		if [[ "$has_scripts_section" -gt 0 && "$in_scripts_section" == 0 ]]; then
			continue
		fi

		key="${line%%=*}"
		value="${line#*=}"
		key="$(trim "$key")"
		value="$(trim "$value")"
		key="${key%\"}"
		key="${key#\"}"
		value="${value%\"}"
		value="${value#\"}"
		key="${key%.sh}"
		[[ -z "$key" || -z "$value" ]] && continue
		ALIASES["$key"]="$value"
	done < "$ALIAS_FILE"
}

script_key_from_path() {
	local path="$1"
	path="${path#scripts/}"
	local base="${path##*/}"
	printf '%s' "${base%.sh}"
}

local_script_path() {
	local path="$1"
	path="${path#scripts/}"
	printf '%s/%s' "$SCRIPT_DIR" "$path"
}

alias_for_path() {
	local path="$1"
	local key
	key="$(script_key_from_path "$path")"
	printf '%s' "${ALIASES[$key]:-}"
}

is_installed() {
	[[ -f "$(local_script_path "$1")" ]]
}

toml_escape() {
	local value="$1"
	value="${value//\\/\\\\}"
	value="${value//\"/\\\"}"
	value="${value//$'\n'/ }"
	printf '%s' "$value"
}

rewrite_alias_file() {
	local mode="$1"
	local target_key="$2"
	local alias_value="${3:-}"
	local tmp
	tmp="$(mktemp "${STORAGE_DIR}/alias.XXXXXX")"
	mkdir -p "$QST_DIR"
	touch "$ALIAS_FILE"

	awk -v mode="$mode" -v target="$target_key" -v alias_value="$alias_value" '
		function normalize_key(raw, clean) {
			clean = raw
			gsub(/^[[:space:]]+/, "", clean)
			gsub(/[[:space:]]+$/, "", clean)
			if (clean ~ /^".*"$/) {
				sub(/^"/, "", clean)
				sub(/"$/, "", clean)
			}
			sub(/\.sh$/, "", clean)
			return clean
		}

		function emit_new_alias() {
			if (mode == "set") {
				print target " = \"" alias_value "\""
			}
		}

		BEGIN {
			in_scripts = 0
			seen_scripts = 0
			inserted = 0
		}

		{
			line = $0
			if (line ~ /^[[:space:]]*\[scripts\][[:space:]]*$/) {
				seen_scripts = 1
				in_scripts = 1
				print line
				next
			}

			if (line ~ /^[[:space:]]*\[[^]]+\][[:space:]]*$/) {
				if (in_scripts && !inserted) {
					emit_new_alias()
					inserted = 1
				}
				in_scripts = 0
				print line
				next
			}

			if (in_scripts) {
				if (line ~ /^[[:space:]]*#/ || line ~ /^[[:space:]]*$/) {
					print line
					next
				}

				if (match(line, /^[[:space:]]*("[^"]+"|[^=[:space:]]+)[[:space:]]*=/, m)) {
					if (normalize_key(m[1]) == target) {
						next
					}
				}
			}

			print line
		}

		END {
			if (mode == "set") {
				if (seen_scripts && !inserted) {
					emit_new_alias()
				} else if (!seen_scripts) {
					if (NR > 0) {
						print ""
					}
					print "[scripts]"
					emit_new_alias()
				}
			}
		}
	' "$ALIAS_FILE" > "$tmp"
	mv "$tmp" "$ALIAS_FILE"
}

set_alias() {
	local path="$1"
	local alias_value="$2"
	local key
	key="$(script_key_from_path "$path")"
	rewrite_alias_file set "$key" "$(toml_escape "$alias_value")"
}

remove_alias() {
	local path="$1"
	local key
	key="$(script_key_from_path "$path")"
	rewrite_alias_file delete "$key"
}

install_script() {
	local path="$1"
	local url="$2"
	local dest tmp dest_dir
	dest="$(local_script_path "$path")"
	dest_dir="$(dirname "$dest")"
	mkdir -p "$dest_dir"
	tmp="$(mktemp "${STORAGE_DIR}/download.XXXXXX")"

	if ! http_get "$url" > "$tmp"; then
		rm -f "$tmp"
		return 1
	fi

	mv "$tmp" "$dest"
	chmod +x "$dest"
}

remove_script() {
	local path="$1"
	remove_alias "$path"
	if [[ "$path" == /* ]]; then
		rm -f "$path"
	else
		rm -f "$(local_script_path "$path")"
	fi
}

matches_terms() {
	local haystack="$1"
	shift
	local term
	local lowered_haystack="${haystack,,}"
	for term in "$@"; do
		[[ -z "$term" ]] && continue
		term="${term,,}"
		[[ "$lowered_haystack" == *"$term"* ]] || return 1
	done
	return 0
}

catalog_exact_script_path() {
	local query="$1"
	local query_lower="${query,,}"
	local name path download_url html_url script_path key

	[[ -n "$query_lower" ]] || return 1
	[[ -f "$CACHE_FILE" ]] || return 1

	while IFS=$'\t' read -r name path download_url html_url; do
		[[ -z "$name" ]] && continue
		script_path="${path#scripts/}"
		key="$(script_key_from_path "$script_path")"
		if [[ "${name,,}" == "$query_lower" || "${script_path,,}" == "$query_lower" || "${key,,}" == "$query_lower" ]]; then
			printf '%s' "$script_path"
			return 0
		fi
	done < "$CACHE_FILE"

	return 1
}

build_loader_value() {
	local directive="$1"
	local script_path="$2"
	local param="${3:-}"

	case "$directive" in
		a)
			if [[ -n "$param" ]]; then
				printf 'loader a %s %s' "$script_path" "$param"
			else
				printf 'loader a %s ' "$script_path"
			fi
			;;
		*)
			printf 'loader %s %s' "$directive" "$script_path"
			;;
	esac
}

render_script_matches() {
	local directive="$1"
	local script_query="$2"
	local param="${3:-}"
	local -a terms=()
	local count=0
	local name path script_path download_url html_url alias title meta row_value

	load_aliases
	if ! ensure_catalog; then
		echo "qst! title  Script Loader "
		echo "qst! action None"
		echo "  Unable to load the awesome-qst catalog right now.|"
		echo "  Try again when network access is available.|"
		return 0
	fi

	if [[ -n "$script_query" ]]; then
		read -r -a terms <<< "$script_query"
	fi

	local exact_path=""
	if exact_path="$(catalog_exact_script_path "$script_query")"; then
		case "$directive" in
			v)
				render_summary "$exact_path"
				return 0
				;;
			\?|info)
				render_info "$exact_path"
				return 0
				;;
			u|install)
				install_script "$exact_path" "${RAW_BASE}/${exact_path}"
				render_summary "$exact_path"
				return 0
				;;
			r|remove)
				remove_script "$exact_path"
				render_browse "$script_query"
				return 0
				;;
			a|alias)
				if [[ -n "$param" ]]; then
					set_alias "$exact_path" "$param"
					render_summary "$exact_path"
				else
					render_summary "$exact_path"
				fi
				return 0
				;;
			x|unalias)
				remove_alias "$exact_path"
				render_summary "$exact_path"
				return 0
				;;
		esac
	fi

	if [[ "$directive" == r || "$directive" == remove || "$directive" == x || "$directive" == unalias ]]; then
		if [[ -f "$(local_script_path "$script_query")" ]]; then
			exact_path="$(local_script_path "$script_query")"
			remove_script "$exact_path"
			render_summary "$script_query"
			return 0
		fi
	fi

	echo "qst! title  Script Loader "
	echo "qst! action SetSearchQuery"

	while IFS=$'\t' read -r name path download_url html_url; do
		[[ -z "$name" ]] && continue
		script_path="${path#scripts/}"
		alias="$(alias_for_path "$script_path")"
		if ! matches_terms "${name} ${script_path} ${alias}" "${terms[@]}"; then
			continue
		fi

		count=$((count + 1))
		title="$(sanitize_text "$name")"
		meta="@meta:meta=remote"
		if is_installed "$path"; then
			title="${title} [installed]"
			meta="${meta} @meta:meta=installed"
		fi
		if [[ -n "$alias" ]]; then
			title="${title} [alias: ${alias}]"
			meta="${meta} @meta:meta=alias"
		fi
		row_value="$(build_loader_value "$directive" "$script_path" "$param")"
		echo "qst! item  ${title}|${row_value}|SetSearchQuery ${meta}"
	done < "$CACHE_FILE"

	if [[ "$count" -eq 0 ]]; then
		echo "  No matching scripts found.|"
	fi
}

render_help() {
	echo "qst! title  Script Loader Help "
	echo "qst! action None"
	echo "  loader                    browse the catalog|"
	echo "  loader <terms>            filter the catalog|"
	echo "  loader v <script>         open the clean script view|"
	echo "  loader ? <script>         show extra script info|"
	echo "  loader u <script>         install or update a script|"
	echo "  loader r <script>         remove the script locally|"
	echo "  loader a <script> <alias> set or replace an alias|"
	echo "  loader x <script>         remove an alias|"
	echo "  loader refresh            force refresh the catalog from GitHub|"
}

render_browse() {
	local search_text="$1"
	local -a terms=()
	local count=0
	local name path script_path download_url html_url alias title meta

	load_aliases
	if ! ensure_catalog; then
		echo "qst! title  Script Loader "
		echo "qst! action None"
		echo "  Unable to load the awesome-qst catalog right now.|"
		echo "  Try again when network access is available.|"
		return 0
	fi

	if [[ -n "$search_text" ]]; then
		read -r -a terms <<< "$search_text"
	fi

	echo "qst! title  Script Loader "
	echo "qst! action SetSearchQuery"

	while IFS=$'\t' read -r name path download_url html_url; do
		[[ -z "$name" ]] && continue
		script_path="${path#scripts/}"
		alias="$(alias_for_path "$script_path")"
		if ! matches_terms "${name} ${script_path} ${alias}" "${terms[@]}"; then
			continue
		fi

		count=$((count + 1))
		title="$(sanitize_text "$name")"
		meta="@meta:meta=remote"
		if is_installed "$path"; then
			title="${title} [installed]"
			meta="${meta} @meta:meta=installed"
		fi
		if [[ -n "$alias" ]]; then
			title="${title} [alias: ${alias}]"
			meta="${meta} @meta:meta=alias"
		fi
		echo "qst! item  ${title}|loader v ${script_path}|SetSearchQuery ${meta}"
	done < "$CACHE_FILE"

	if [[ "$count" -eq 0 ]]; then
		echo "  No matching scripts found.|"
	fi
}

render_summary() {
	local path="$1"
	local alias installed local_path
	path="${path#scripts/}"
	local_path="$(local_script_path "$path")"
	alias="$(alias_for_path "$path")"
	installed="no"
	if is_installed "$path"; then
		installed="yes"
	fi

	echo "qst! title  Script Loader "
	echo "qst! action None"
	echo "qst! item  ← Back to catalog|loader|SetSearchQuery @meta:permanent=true"
	echo "  Installed: ${installed}|${installed}|None @meta:nonselectable=true"
	if [[ -n "$alias" ]]; then
		echo "  Alias: ${alias}|${alias}|None @meta:nonselectable=true"
	else
		echo "  Alias: (none)|Alias: (none)|None @meta:nonselectable=true"
	fi
	if [[ -f "$local_path" ]]; then
		emit_script_metadata_rows "$local_path"
	fi
	echo "qst! item  Install|$(quote_shell_args "$SCRIPT_PATH" u "$path")|Execute,RefreshResults"
	if [[ "$installed" == "yes" ]]; then
		echo "qst! item  Remove|$(quote_shell_args "$SCRIPT_PATH" r "$path")|Execute,RefreshResults"
	else
		echo "qst! item  Remove|$(quote_shell_args "$SCRIPT_PATH" r "$path")|None @meta:nonselectable=true"
	fi
	echo "qst! item  Add alias|loader a ${path} |SetSearchQuery"
	echo "qst! item  More info|loader ? ${path}|SetSearchQuery"

}

render_info() {
	local path="$1"
	local alias local_path remote_url installed alias_display
	path="${path#scripts/}"
	local_path="$(local_script_path "$path")"
	remote_url="${RAW_BASE}/${path}"
	alias="$(alias_for_path "$path")"
	installed="no"
	if is_installed "$path"; then
		installed="yes"
	fi

	echo "qst! title  Script Loader Info "
	echo "qst! action None"
	echo "qst! item  ← Back to clean view|loader v ${path}|SetSearchQuery @meta:permanent=true"
	echo "  Installed: ${installed}|${installed}|None @meta:nonselectable=true"
	if [[ -n "$alias" ]]; then
		alias_display="$alias"
	else
		alias_display="(none)"
	fi
	echo "  Alias: ${alias_display}|${alias_display}|None @meta:nonselectable=true"
	echo "  Script: ${path}|${path}|None @meta:nonselectable=true"
	echo "  Remote: ${remote_url}|${remote_url}|None @meta:nonselectable=true"
	echo "  Local: ${local_path}|${local_path}|None @meta:nonselectable=true"
	if [[ -f "$local_path" ]]; then
		emit_script_metadata_rows "$local_path"
	fi
	echo "qst! item  Install|$(quote_shell_args "$SCRIPT_PATH" u "$path")|Execute,RefreshResults"
	if [[ "$installed" == "yes" ]]; then
		echo "qst! item  Remove|$(quote_shell_args "$SCRIPT_PATH" r "$path")|Execute,RefreshResults"
	else
		echo "qst! item  Remove|$(quote_shell_args "$SCRIPT_PATH" r "$path")|None @meta:nonselectable=true"
	fi
	echo "qst! item  Add alias|loader a ${path} |SetSearchQuery"
	if [[ -n "$alias" ]]; then
		echo "qst! item  Remove alias|$(quote_shell_args "$SCRIPT_PATH" x "$path")|Execute,RefreshResults"
	else
		echo "qst! item  Remove alias|$(quote_shell_args "$SCRIPT_PATH" x "$path")|None @meta:nonselectable=true"
	fi
	echo "qst! item  More info|loader ? ${path}|SetSearchQuery"
}

run_direct_command() {
	local command="$1"
	local rest="${2:-}"
	local script_query param path alias_input
	script_query="${rest%% *}"
	if [[ -z "$rest" || "$rest" == "$script_query" ]]; then
		param=""
	else
		param="${rest#${script_query}}"
		param="$(trim "${param# }")"
	fi

	case "$command" in
		refresh)
			refresh_catalog_cache
			render_browse ""
			return 0
			;;
		help|h)
			render_help
			return 0
			;;
		search|browse)
			render_browse "$rest"
			return 0
			;;
		v|view|show|details|detail)
			if [[ -z "$script_query" ]]; then
				render_browse ""
				return 0
			fi
			render_script_matches "$command" "$script_query"
			return 0
			;;
		\?|info)
			if [[ -z "$script_query" ]]; then
				render_browse ""
				return 0
			fi
			render_script_matches "$command" "$script_query"
			return 0
			;;
		u|install)
			if [[ -n "$script_query" ]]; then
				render_script_matches "$command" "$script_query"
			else
				render_browse ""
			fi
			return 0
			;;
		r|remove)
			if [[ -n "$script_query" ]]; then
				render_script_matches "$command" "$script_query"
			else
				render_browse ""
			fi
			return 0
			;;
		a|alias)
			if [[ -z "$script_query" ]]; then
				render_browse ""
				return 0
			fi
			if [[ -n "$param" ]]; then
				render_script_matches "$command" "$script_query" "$param"
			else
				render_script_matches "$command" "$script_query"
			fi
			return 0
			;;
		x|unalias)
			if [[ -n "$script_query" ]]; then
				render_script_matches "$command" "$script_query"
			else
				render_browse ""
			fi
			return 0
			;;
		*)
			render_browse "$command${rest:+ $rest}"
			return 0
			;;
	esac
}

dispatch() {
	local input="$1"
	local normalized command rest
	input="$(trim "$input")"
	if [[ -z "$input" ]]; then
		render_browse ""
		return 0
	fi

	if [[ "$input" == loader ]]; then
		render_browse ""
		return 0
	fi

	if [[ "$input" == loader\ * ]]; then
		input="${input#loader }"
		input="$(trim "$input")"
	fi

	normalized="$input"
	command="${normalized%% *}"
	rest="${normalized#${command}}"
	rest="$(trim "$rest")"

	case "$command" in
		help|h|refresh|search|browse|v|view|show|details|detail|u|install|r|remove|a|alias|x|unalias|\?|info)
			run_direct_command "$command" "$rest"
			;;
		*)
			render_browse "$normalized"
			;;
	esac
}

main() {
	ensure_store
	load_aliases
	dispatch "$RAW_QUERY"
}

main "$@"