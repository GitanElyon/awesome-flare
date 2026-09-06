#!/usr/bin/env bash
echo "qst! meta Script Loader, 2.1.0, GitanElyon, Browses and installs awesome-qst scripts."
set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
RAW_QUERY="$*"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
QST_DIR="${CONFIG_HOME}/qst"
SCRIPT_DIR="${QST_DIR}/scripts"
ALIAS_FILE="${QST_DIR}/alias.toml"
STORAGE_DIR="${QST_DIR}/storage/loader"
CACHE_FILE="${QST_DIR}/storage/catalog.tsv"

REPO_OWNER="GitanElyon"
REPO_NAME="awesome-qst"
REPO_BRANCH="main"
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

quote_shell_args() {
	local arg command=""
	for arg in "$@"; do
		command+="$(printf '%q ' "$arg")"
	done
	printf '%s' "${command% }"
}

ensure_store() {
	mkdir -p "$STORAGE_DIR" "$SCRIPT_DIR"
}

ensure_catalog() {
	[[ -f "$CACHE_FILE" ]]
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

local_script_version() {
	local path="$1"
	local meta name version author description
	meta="$(read_script_metadata "$(local_script_path "$path")")" || return 1
	IFS=$'\t' read -r name version author description <<< "$meta"
	printf '%s' "$version"
}

catalog_row() {
	local target="$1"
	local file name version author description
	while IFS=$'\t' read -r file name version author description; do
		if [[ "$file" == "$target" ]]; then
			printf '%s\t%s\t%s\t%s\t%s' "$file" "$name" "$version" "$author" "$description"
			return 0
		fi
	done < "$CACHE_FILE"
	return 1
}

catalog_version() {
	local path="$1"
	local row file name version author description
	row="$(catalog_row "$path")" || return 1
	IFS=$'\t' read -r file name version author description <<< "$row"
	printf '%s' "$version"
}

verlt() {
	local a="$1" b="$2"
	[[ -n "$a" && -n "$b" ]] || return 1
	if sort -V </dev/null >/dev/null 2>&1; then
		[[ "$a" != "$b" ]] && printf '%s\n%s\n' "$a" "$b" | sort -V -C
	else
		[[ "$a" < "$b" ]]
	fi
}

is_outdated() {
	local path="$1"
	local local_version remote_version
	[[ -f "$(local_script_path "$path")" ]] || return 1
	local_version="$(local_script_version "$path")" || return 1
	remote_version="$(catalog_version "$path")" || return 1
	verlt "$local_version" "$remote_version"
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
	local file name version author description key

	[[ -n "$query_lower" ]] || return 1
	[[ -f "$CACHE_FILE" ]] || return 1

	while IFS=$'\t' read -r file name version author description; do
		[[ -z "$file" ]] && continue
		key="$(script_key_from_path "$file")"
		if [[ "${name,,}" == "$query_lower" || "${file,,}" == "$query_lower" || "${key,,}" == "$query_lower" ]]; then
			printf '%s' "$file"
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

render_catalog_list() {
	local directive="$1"
	local script_query="$2"
	local param="${3:-}"
	local -a terms=()
	local count=0
	local file name version author description key alias title meta row_value

	load_aliases
	if ! ensure_catalog; then
		echo "qst! title  Script Loader "
		echo "qst! action None"
		echo "  Catalog not downloaded yet.|"
		echo "  Open qst once or run qst --refresh-catalog.|"
		return 0
	fi

	if [[ -n "$script_query" ]]; then
		read -r -a terms <<< "$script_query"
	fi

	if [[ -n "$directive" ]]; then
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
				u|install|r|remove)
					render_summary "$exact_path"
					return 0
					;;
				a|alias)
					if [[ -n "$param" ]]; then
						set_alias "$exact_path" "$param"
					else
						remove_alias "$exact_path"
					fi
					render_summary "$exact_path"
					return 0
					;;
				x|unalias)
					remove_alias "$exact_path"
					render_summary "$exact_path"
					return 0
					;;
			esac
		fi

		if [[ "$directive" == r || "$directive" == remove ]]; then
			if [[ -f "$(local_script_path "$script_query")" ]]; then
				render_summary "$script_query"
				return 0
			fi
		fi
	fi

	echo "qst! title  Script Loader "
	echo "qst! action SetSearchQuery"

	while IFS=$'\t' read -r file name version author description; do
		[[ -z "$file" ]] && continue
		key="$(script_key_from_path "$file")"
		alias="$(alias_for_path "$file")"
		if ! matches_terms "${name} ${file} ${alias}" "${terms[@]}"; then
			continue
		fi

		count=$((count + 1))
		title="$(sanitize_text "${name:-$key}")"
		meta="@meta:meta=remote"
		if is_installed "$file"; then
			meta="${meta} @meta:active=true @meta:meta=installed"
		fi
		if is_outdated "$file"; then
			meta="${meta} @meta:urgent=true"
		fi
		if [[ -n "$alias" ]]; then
			title="${title} [$(sanitize_text "$alias")]"
			meta="${meta} @meta:meta=alias"
		fi
		if [[ -n "$directive" ]]; then
			row_value="$(build_loader_value "$directive" "$file" "$param")"
		else
			row_value="loader v ${file}"
		fi
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
	echo "  loader a <script>         remove the alias|"
	echo "  loader x <script>         remove an alias|"
	echo "  loader refresh            refresh the catalog via qst|"
}

render_title_line() {
	local path="$1"
	local name alias version installed local_version
	path="${path#scripts/}"
	alias="$(alias_for_path "$path")"
	installed="no"
	if is_installed "$path"; then
		installed="yes"
	fi

	local row=""
	if row="$(catalog_row "$path")"; then
		local file catalog_name catalog_version catalog_author catalog_description
		IFS=$'\t' read -r file catalog_name catalog_version catalog_author catalog_description <<< "$row"
		name="${catalog_name:-$(script_key_from_path "$path")}"
		version="$catalog_version"
	else
		name="$(script_key_from_path "$path")"
		version=""
	fi

	local display_version="$version"
	if [[ "$installed" == "yes" ]]; then
		if local_version="$(local_script_version "$path")"; then
			[[ -n "$local_version" ]] && display_version="$local_version"
		fi
	fi

	local title="$(sanitize_text "$name")"
	if [[ -n "$alias" ]]; then
		title="${title} [$(sanitize_text "$alias")]"
	fi
	if [[ -n "$display_version" ]]; then
		title="${title} - ${display_version}"
	fi

	printf 'qst! title  %s \n' "$title"
}

render_state_row() {
	local path="$1"
	local version
	path="${path#scripts/}"

	if ! is_installed "$path"; then
		echo "qst! item  Install|$(quote_shell_args qst --install "$path")|Execute,RefreshResults"
	elif is_outdated "$path"; then
		version="$(catalog_version "$path")"
		echo "qst! item  Update to ${version}|$(quote_shell_args qst --update "$path")|Execute,RefreshResults"
	else
		echo "  Installed|Installed|None @meta:nonselectable=true"
	fi
}

render_summary() {
	local path="$1"
	local alias installed
	path="${path#scripts/}"
	alias="$(alias_for_path "$path")"
	installed="no"
	if is_installed "$path"; then
		installed="yes"
	fi

	render_title_line "$path"
	echo "qst! action None"

	render_state_row "$path"

	if [[ "$installed" == "yes" ]]; then
		echo "qst! item  Remove|$(quote_shell_args qst --remove "$path")|Execute,RefreshResults"
	else
		echo "qst! item  Remove|$(quote_shell_args qst --remove "$path")|None @meta:nonselectable=true"
	fi
	echo "qst! item  Add alias|loader a ${path} |SetSearchQuery"
	echo "qst! item  More info|loader ? ${path}|SetSearchQuery"
	echo "qst! item  ← Back to catalog|loader|SetSearchQuery @meta:permanent=true"
}

render_info() {
	local path="$1"
	local alias installed local_path remote_url row file name version author description
	path="${path#scripts/}"
	local_path="$(local_script_path "$path")"
	remote_url="${RAW_BASE}/${path}"
	alias="$(alias_for_path "$path")"
	installed="no"
	if is_installed "$path"; then
		installed="yes"
	fi

	name="$(script_key_from_path "$path")"
	author=""
	description=""
	if row="$(catalog_row "$path")"; then
		IFS=$'\t' read -r file name version author description <<< "$row"
	fi

	render_title_line "$path"
	echo "qst! action None"

	render_state_row "$path"

	[[ -n "$author" ]] && echo "  Author: ${author}|${author}|None @meta:nonselectable=true"
	[[ -n "$description" ]] && echo "  Description: ${description}|${description}|None @meta:nonselectable=true"
	echo "  Script: ${path}|${path}|None @meta:nonselectable=true"
	echo "  Remote: ${remote_url}|${remote_url}|None @meta:nonselectable=true"
	echo "  Local: ${local_path}|${local_path}|None @meta:nonselectable=true"

	if [[ "$installed" == "yes" ]]; then
		echo "qst! item  Remove|$(quote_shell_args qst --remove "$path")|Execute,RefreshResults"
	else
		echo "qst! item  Remove|$(quote_shell_args qst --remove "$path")|None @meta:nonselectable=true"
	fi
	echo "qst! item  Add alias|loader a ${path} |SetSearchQuery"
	if [[ -n "$alias" ]]; then
		echo "qst! item  Remove alias|$(quote_shell_args "$SCRIPT_PATH" x "$path")|Execute,RefreshResults"
	else
		echo "qst! item  Remove alias|$(quote_shell_args "$SCRIPT_PATH" x "$path")|None @meta:nonselectable=true"
	fi
	echo "qst! item  ← Back to catalog|loader v ${path}|SetSearchQuery @meta:permanent=true"
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
			echo "qst! title  Script Loader "
			echo "qst! action None"
			echo "qst! item  Refresh catalog now|$(quote_shell_args qst --refresh-catalog)|Execute,RefreshResults"
			echo "qst! item  Browse catalog|loader |SetSearchQuery"
			echo "qst! item  ← Back to catalog|loader|SetSearchQuery @meta:permanent=true"
			return 0
			;;
		help|h)
			render_help
			return 0
			;;
		search|browse)
			render_catalog_list "" "$rest" ""
			return 0
			;;
		v|view|show|details|detail)
			if [[ -z "$script_query" ]]; then
				render_catalog_list "" "" ""
				return 0
			fi
			render_catalog_list "$command" "$script_query"
			return 0
			;;
		\?|info)
			if [[ -z "$script_query" ]]; then
				render_catalog_list "" "" ""
				return 0
			fi
			render_catalog_list "$command" "$script_query"
			return 0
			;;
		u|install)
			if [[ -n "$script_query" ]]; then
				render_catalog_list "$command" "$script_query"
			else
				render_catalog_list "" "" ""
			fi
			return 0
			;;
		r|remove)
			if [[ -n "$script_query" ]]; then
				render_catalog_list "$command" "$script_query"
			else
				render_catalog_list "" "" ""
			fi
			return 0
			;;
		a|alias)
			if [[ -z "$script_query" ]]; then
				render_catalog_list "" "" ""
				return 0
			fi
			if [[ -n "$param" ]]; then
				render_catalog_list "$command" "$script_query" "$param"
			else
				render_catalog_list "$command" "$script_query"
			fi
			return 0
			;;
		x|unalias)
			if [[ -n "$script_query" ]]; then
				render_catalog_list "$command" "$script_query"
			else
				render_catalog_list "" "" ""
			fi
			return 0
			;;
		*)
			render_catalog_list "" "$command${rest:+ $rest}" ""
			return 0
			;;
	esac
}

dispatch() {
	local input="$1"
	local normalized command rest
	input="$(trim "$input")"
	if [[ -z "$input" ]]; then
		render_catalog_list "" "" ""
		return 0
	fi

	if [[ "$input" == loader ]]; then
		render_catalog_list "" "" ""
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
			render_catalog_list "" "$normalized" ""
			;;
	esac
}

main() {
	ensure_store
	load_aliases
	dispatch "$RAW_QUERY"
}

main "$@"
