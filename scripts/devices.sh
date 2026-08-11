#!/usr/bin/env bash
set -euo pipefail
echo "qst! meta Devices, 1.0.0, GitanElyon, Shows connected Bluetooth and USB peripherals."

QUERY="${1:-}"

if ! command -v bluetoothctl >/dev/null 2>&1 && ! command -v lsusb >/dev/null 2>&1; then
    echo "qst! title  Devices "
    echo "qst! action None"
    echo "  bluetoothctl/lsusb not found. Please install bluez and usbutils. @meta:center=true|"
    exit 0
fi

is_mac() {
    [[ "$1" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]
}

connected_list() {
    bluetoothctl devices Connected 2>/dev/null
}

info_field() {
    local info="$1" field="$2"
    <<<"$info" grep -i "^\s*${field}:" | head -1 | sed -E "s/^[[:space:]]*${field}:[[:space:]]*//I" | tr -d '\r'
}

battery_of() {
    local mac="$1"
    local info pct
    info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
    pct="$(<<<"$info" grep -i "Battery Percentage:" | head -1 | sed -E 's/.*\(([0-9]+)\).*/\1/')"
    if [[ -z "$pct" ]]; then
        pct="$(<<<"$info" grep -i "Battery Percentage:" | head -1 | sed -E 's/.*Battery Percentage:[[:space:]]*0x([0-9A-Fa-f]+).*/\1/')"
        if [[ "$pct" =~ ^[0-9A-Fa-f]+$ ]]; then
            pct=$((16#$pct))
        fi
    fi
    [[ "$pct" =~ ^[0-9]+$ ]] || pct=""
    if [[ -z "$pct" ]] && command -v upower >/dev/null 2>&1; then
        local upath="org.freedesktop.UPower.devices.${mac//:/_}"
        pct="$(upower --dump 2>/dev/null | awk -v p="$upath" '
            $1 == "Device:" && $2 == p { on = 1; next }
            on && /percentage:/ { gsub(/[^0-9]/, "", $2); if ($2 ~ /^[0-9]+$/) { print $2; exit } }')"
    fi
    printf '%s' "$pct"
}

usb_rows() {
    local line id name
    while IFS= read -r line; do
        [[ "$line" =~ ^Bus[[:space:]]+[0-9]+[[:space:]]+Device[[:space:]]+[0-9]+:[[:space:]]+ID[[:space:]]+([[:xdigit:]]{4}:[[:xdigit:]]{4})[[:space:]]+(.*)$ ]] || continue
        id="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        if [[ "$name" =~ root[[:space:]]hub ]] || [[ "$name" =~ [Bb]luetooth ]]; then
            continue
        fi
        echo "${name}|usb:${id}"
    done < <(lsusb 2>/dev/null)
}

resolve_peripheral() {
    local arg="$1"
    if is_mac "$arg"; then
        if connected_list | grep -qi "Device ${arg} "; then
            echo "$arg"
        fi
        return 0
    fi
    if [[ "$arg" == usb:* ]]; then
        if lsusb 2>/dev/null | grep -q "ID ${arg#usb:} "; then
            echo "$arg"
        fi
        return 0
    fi
    local line mac name info alias
    while IFS= read -r line; do
        [[ "$line" =~ ^Device[[:space:]]+([[:xdigit:]:]+)[[:space:]]+(.*)$ ]] || continue
        mac="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        if [[ "${arg,,}" == "${name,,}" ]]; then
            echo "$mac"
            return 0
        fi
        info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
        alias="$(info_field "$info" Alias)"
        if [[ -n "$alias" && "${arg,,}" == "${alias,,}" ]]; then
            echo "$mac"
            return 0
        fi
    done < <(connected_list)
    while IFS= read -r line; do
        name="${line%%|*}"
        if [[ "${arg,,}" == "${name,,}" ]]; then
            echo "${line#*|}"
            return 0
        fi
    done < <(usb_rows)
    return 0
}

show_bt_detail() {
    local mac="$1"
    local info name alias icon paired bonded trusted blocked connected pct uuid
    info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
    name="$(info_field "$info" Name)"
    [[ -z "$name" ]] && name="$mac"
    alias="$(info_field "$info" Alias)"
    icon="$(info_field "$info" Icon)"
    paired="$(info_field "$info" Paired)"
    bonded="$(info_field "$info" Bonded)"
    trusted="$(info_field "$info" Trusted)"
    blocked="$(info_field "$info" Blocked)"
    connected="$(info_field "$info" Connected)"
    pct="$(battery_of "$mac")"

    echo "qst! title  Devices: ${name} "
    echo "qst! action None"
    echo "qst! item   <- Back to list|devices |SetSearchQuery @meta:permanent=true"

    if [[ "$connected" == "yes" ]]; then
        echo "  [Connected] @meta:nonselectable=true @meta:active=true @meta:center=true|"
    else
        echo "  [Disconnected] @meta:nonselectable=true @meta:center=true|"
    fi

    if [[ "$pct" =~ ^[0-9]+$ ]]; then
        echo "  Battery: ${pct}% @meta:nonselectable=true|"
    else
        echo "  Battery: unknown @meta:nonselectable=true|"
    fi
    echo "  MAC: ${mac} @meta:nonselectable=true|"
    [[ -n "$alias" && "$alias" != "$name" ]] && echo "  Alias: ${alias} @meta:nonselectable=true|"
    [[ -n "$icon" ]] && echo "  Icon: ${icon} @meta:nonselectable=true|"
    echo "  Paired: ${paired:-unknown} @meta:nonselectable=true|"
    echo "  Bonded: ${bonded:-unknown} @meta:nonselectable=true|"
    echo "  Trusted: ${trusted:-unknown} @meta:nonselectable=true|"
    echo "  Blocked: ${blocked:-unknown} @meta:nonselectable=true|"
    echo "  ──────────────────────────── @meta:nonselectable=true @meta:center=true|"

    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*UUID:[[:space:]]*(.+)$ ]] || continue
        uuid="${BASH_REMATCH[1]}"
        echo "  ${uuid} @meta:nonselectable=true|"
    done <<< "$info"

    echo "  ──────────────────────────── @meta:nonselectable=true @meta:center=true|"
    echo "qst! action Execute,RefreshResults"

    if [[ "$connected" == "yes" ]]; then
        echo "  Disconnect|bluetoothctl disconnect ${mac}"
    else
        echo "  Connect|bluetoothctl connect ${mac}"
    fi

    if [[ "$trusted" == "yes" ]]; then
        echo "  Untrust|bluetoothctl untrust ${mac}"
    else
        echo "  Trust (auto-connect)|bluetoothctl trust ${mac}"
    fi

    echo "  Remove / Forget|bluetoothctl remove ${mac} @meta:urgent=true"
}

show_usb_detail() {
    local id="$1"
    local vid="${id#usb:}"
    local pid="${vid#*:}"
    vid="${vid%%:*}"
    local line bus dev name product manufacturer serial
    line="$(lsusb 2>/dev/null | grep -F "ID ${vid}:${pid}" | head -1)"
    if [[ -z "$line" ]]; then
        echo "qst! title  Devices "
        echo "qst! action None"
        echo "  Device not found @meta:nonselectable=true @meta:center=true|"
        return
    fi
    if [[ "$line" =~ ^Bus[[:space:]]+([0-9]+)[[:space:]]+Device[[:space:]]+([0-9]+):[[:space:]]+ID[[:space:]]+[[:xdigit:]:]+[[:space:]]+(.*)$ ]]; then
        bus="${BASH_REMATCH[1]}"
        dev="${BASH_REMATCH[2]}"
        name="${BASH_REMATCH[3]}"
    fi

    local vinfo
    vinfo="$(lsusb -v -d "${vid}:${pid}" 2>/dev/null || true)"
    product="$(<<<"$vinfo" grep -m1 "iProduct" | sed -E 's/.*iProduct[[:space:]]+[0-9]+[[:space:]]+//' | tr -d '\r')"
    manufacturer="$(<<<"$vinfo" grep -m1 "iManufacturer" | sed -E 's/.*iManufacturer[[:space:]]+[0-9]+[[:space:]]+//' | tr -d '\r')"
    serial="$(<<<"$vinfo" grep -m1 "iSerial" | sed -E 's/.*iSerial[[:space:]]+[0-9]+[[:space:]]+//' | tr -d '\r')"
    [[ -z "$product" ]] && product="$name"
    [[ -z "$manufacturer" ]] && manufacturer="${name%% ${product}*}"

    echo "qst! title  Devices: ${product} "
    echo "qst! action None"
    echo "qst! item   <- Back to list|devices |SetSearchQuery @meta:permanent=true"
    echo "  [Connected] @meta:nonselectable=true @meta:active=true @meta:center=true|"
    [[ -n "$product" ]] && echo "  Product: ${product} @meta:nonselectable=true|"
    [[ -n "$manufacturer" ]] && echo "  Manufacturer: ${manufacturer} @meta:nonselectable=true|"
    echo "  ID: ${vid}:${pid} @meta:nonselectable=true|"
    [[ -n "$serial" ]] && echo "  Serial: ${serial} @meta:nonselectable=true|"
    [[ -n "$bus" && -n "$dev" ]] && echo "  Bus / Device: ${bus} / ${dev} @meta:nonselectable=true|"
}

arg="${QUERY# }"

if [[ "$arg" == "-h" || "$arg" == "--help" || "$arg" == "help" ]]; then
    echo "qst! title  Devices Help "
    echo "qst! action None"
    echo "  devices              List connected Bluetooth and USB peripherals @meta:nonselectable=true|"
    echo "  devices <name>       Show details for a peripheral by name @meta:nonselectable=true|"
    exit 0
fi

if [[ -n "$arg" ]]; then
    resolved="$(resolve_peripheral "$arg")"
    if [[ -n "$resolved" ]]; then
        if is_mac "$resolved" || [[ "$resolved" != usb:* ]]; then
            show_bt_detail "$resolved"
        else
            show_usb_detail "$resolved"
        fi
        exit 0
    fi
fi

echo "qst! title  Devices @meta:fuzzy=true"
echo "qst! action SetSearchQuery"

bt_count=0
if command -v bluetoothctl >/dev/null 2>&1; then
    while IFS= read -r line; do
        [[ "$line" =~ ^Device[[:space:]]+([[:xdigit:]:]+)[[:space:]]+(.*)$ ]] || continue
        if [[ "$bt_count" == "0" ]]; then
            echo "  ─── Bluetooth ─── @meta:nonselectable=true @meta:center=true|"
        fi
        mac="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        pct="$(battery_of "$mac")"
        if [[ "$pct" =~ ^[0-9]+$ ]]; then
            echo "  ${name}  ${pct}%  (${mac})|devices ${mac} @meta:meta=bluetooth,device"
        else
            echo "  ${name}  (${mac})|devices ${mac} @meta:meta=bluetooth,device"
        fi
        bt_count=$((bt_count + 1))
    done < <(connected_list)
fi

usb_count=0
if command -v lsusb >/dev/null 2>&1; then
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        if [[ "$usb_count" == "0" ]]; then
            echo "  ─── USB ─── @meta:nonselectable=true @meta:center=true|"
        fi
        name="${line%%|*}"
        token="${line#*|}"
        echo "  ${name}  (${token#usb:})|devices ${token} @meta:meta=usb,device"
        usb_count=$((usb_count + 1))
    done < <(usb_rows)
fi

if [[ "$bt_count" == "0" && "$usb_count" == "0" ]]; then
    echo "  No connected peripherals @meta:nonselectable=true @meta:center=true|"
    echo "  Make sure Bluetooth is on and devices are plugged in @meta:nonselectable=true @meta:center=true|"
fi
