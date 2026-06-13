#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta IP Info, 1.0.0, GitanElyon, Shows public IP, local IPs, interfaces, and DNS info."

QUERY="${1:-}"
echo "qst! title IP & Network Info"

sanitize_text() {
    local text="$1"
    text="${text//$'\n'/ }"
    text="${text//|/¦}"
    printf '%s' "$text"
}

emit_row() {
    local title="$1"
    local value="$2"
    local meta="${3:-}"
    local display
    display="$(sanitize_text "$value")"
    printf 'qst! item  %s  %s|%s|None @meta:nonselectable=true @meta:display=%s  %s%s\n' "$title" "$display" "$title" "$title" "$display" "$meta"
}

emit_center_row() {
    local text="$1"
    printf 'qst! item  %s|%s|None @meta:nonselectable=true @meta:center=true\n' "$text" "$text"
}

get_public_ip() {
    curl -sf4 https://api.ipify.org 2>/dev/null || curl -sf6 https://api6.ipify.org 2>/dev/null || echo "Unreachable"
}

get_public_ip_info() {
    curl -sf https://ipapi.co/json/ 2>/dev/null || echo ""
}

if [[ "$QUERY" == "port" || "$QUERY" == "ports" ]]; then
    echo "qst! title Listening Ports"
    if command -v ss >/dev/null 2>&1; then
        echo "qst! action None"
        ss -tlnp4 2>/dev/null | awk 'NR>1 {
            split($4, a, ":")
            port = a[length(a)]
            proto = "tcp"
            printf "qst! item  %s  :%s|%s|None @meta:nonselectable=true\n", proto, port, port
        }'
        ss -ulnp4 2>/dev/null | awk 'NR>1 {
            split($4, a, ":")
            port = a[length(a)]
            proto = "udp"
            printf "qst! item  %s  :%s|%s|None @meta:nonselectable=true\n", proto, port, port
        }'
        ss -tlnp6 2>/dev/null | awk 'NR>1 {
            split($4, a, ":")
            port = a[length(a)]
            proto = "tcp6"
            printf "qst! item  %s  :%s|%s|None @meta:nonselectable=true\n", proto, port, port
        }'
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tulpn 2>/dev/null | awk 'NR>2 {
            split($4, a, ":")
            port = a[length(a)]
            printf "qst! item  %s  %s|%s|None @meta:nonselectable=true\n", $1, $4, port
        }'
    else
        echo "qst! item  ss or netstat not available||None @meta:nonselectable=true @meta:center=true"
    fi
    exit 0
fi

if [[ "$QUERY" == "dns" ]]; then
    echo "qst! title DNS Info"
    echo "qst! action None"
    if [[ -f /etc/resolv.conf ]]; then
        while IFS= read -r line; do
            case "$line" in
                nameserver*)
                    value="${line#nameserver }"
                    value="$(sanitize_text "$value")"
                    printf 'qst! item  DNS  %s|%s|None @meta:nonselectable=true\n' "$value" "$value"
                    ;;
            esac
        done < /etc/resolv.conf
    fi
    if command -v resolvectl >/dev/null 2>&1; then
        resolvectl status 2>/dev/null | awk '/DNS Servers:/ { found=1; next } found && /^[[:space:]]/ { gsub(/^[[:space:]]+/, ""); printf "qst! item  resolvectl  %s|%s|None @meta:nonselectable=true\n", $0, $0; next } /^[[:alnum:]]/ { found=0 }'
    fi
    exit 0
fi

emit_center_row "IP Information"

public_ip="$(get_public_ip)"
emit_row "Public IP" "$public_ip"

if [[ "$public_ip" != "Unreachable" ]]; then
    ip_info="$(get_public_ip_info)"
    if [[ -n "$ip_info" ]]; then
        city="$(echo "$ip_info" | awk -F'"' '/"city"/ {print $4}')"
        region="$(echo "$ip_info" | awk -F'"' '/"region"/ {print $4}')"
        country="$(echo "$ip_info" | awk -F'"' '/"country_name"/ {print $4}')"
        isp="$(echo "$ip_info" | awk -F'"' '/"org"/ {print $4}')"
        [[ -n "$city" && -n "$region" ]] && emit_row "Location" "$city, $region, $country"
        [[ -n "$isp" ]] && emit_row "ISP" "$isp"
    fi
fi

hostname_text="$(hostname 2>/dev/null || uname -n)"
emit_row "Hostname" "$hostname_text"

if command -v ip >/dev/null 2>&1; then
    while IFS= read -r line; do
        if [[ "$line" =~ ^[0-9]+:\ ([^:@]+):\ \<([^>]+)\> ]]; then
            current_iface="${BASH_REMATCH[1]}"
            current_flags="${BASH_REMATCH[2]}"
            [[ "$current_iface" == "lo" ]] && continue
            current_ip=""
            current_state="DOWN"
            [[ "$current_flags" == *"UP"* ]] && current_state="UP"
        elif [[ -n "${current_iface:-}" && "$current_iface" != "lo" && "$line" =~ ^[[:space:]]+inet\ ([0-9.]+)/([0-9]+) ]]; then
            current_ip="${BASH_REMATCH[1]}"
            meta=""
            if [[ "$current_state" == "DOWN" ]]; then
                meta=" @meta:urgent=true"
            fi
            display_name="${current_iface}  (${current_state})"
            emit_row "$display_name" "$current_ip" "$meta"
        fi
    done < <(ip addr show 2>/dev/null)
elif command -v ifconfig >/dev/null 2>&1; then
    emit_row "Interfaces" "Use iproute2 (ip command)"
fi

emit_center_row "---"

echo "qst! action None"
echo "qst! item  Listening Ports  port||SetSearchQuery @meta:nonselectable=true"
echo "qst! item  DNS Info        dns||SetSearchQuery @meta:nonselectable=true"
