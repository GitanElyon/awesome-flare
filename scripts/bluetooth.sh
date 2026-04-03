#!/usr/bin/env bash

QUERY="${1:-}"

if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo "qst! title  Bluetooth "
    echo "qst! action None"
    echo "  bluetoothctl not found. Please install bluez/bluetoothctl.|"
    exit 0
fi

is_powered() {
    bluetoothctl show 2>/dev/null | grep -q "^\s*Powered: yes$"
}

is_scanning() {
    bluetoothctl show 2>/dev/null | grep -q "^\s*Discovering: yes$"
}

is_mac() {
    [[ "$1" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]]
}

device_info_flags() {
    local mac="$1"
    local info
    info="$(bluetoothctl info "$mac" 2>/dev/null || true)"
    local connected=0 paired=0 trusted=0
    grep -q "^\s*Connected: yes$" <<<"$info" && connected=1
    grep -q "^\s*Paired: yes$" <<<"$info" && paired=1
    grep -q "^\s*Trusted: yes$" <<<"$info" && trusted=1
    echo "$connected $paired $trusted"
}

arg="${QUERY# }"

if [[ "$arg" == "-h" || "$arg" == "--help" || "$arg" == "help" ]]; then
    echo "qst! title  Bluetooth Help "
    echo "qst! action None"
    echo "  b!           Open main bluetooth menu|"
    echo "  b! power on  Turn on Bluetooth adapter|"
    echo "  b! power off Turn off Bluetooth adapter|"
    echo "  b! scan on   Start scanning for devices|"
    echo "  b! scan off  Stop scanning|"
    exit 0
fi

if [[ "$arg" == "power on" ]]; then
    echo "qst! title  Bluetooth Admin "
    echo "qst! action ExecuteAndRefresh"
    echo "  Powering on...|bluetoothctl power on @meta:urgent=true"
    exit 0
fi

if [[ "$arg" == "power off" ]]; then
    echo "qst! title  Bluetooth Admin "
    echo "qst! action ExecuteAndRefresh"
    echo "  Powering off...|bluetoothctl power off @meta:urgent=true"
    exit 0
fi

if [[ "$arg" == "scan on" ]]; then
    echo "qst! title  Bluetooth Admin "
    echo "qst! action ExecuteAndRefresh"
    echo "  Starting scan...|bluetoothctl scan on @meta:urgent=true"
    exit 0
fi

if [[ "$arg" == "scan off" ]]; then
    echo "qst! title  Bluetooth Admin "
    echo "qst! action ExecuteAndRefresh"
    echo "  Stopping scan...|bluetoothctl scan off @meta:urgent=true"
    exit 0
fi

if is_mac "$arg"; then
    read -r connected paired trusted < <(device_info_flags "$arg")

    status="Unpaired"
    if [[ "$connected" == "1" ]]; then
        status="Connected"
    elif [[ "$paired" == "1" ]]; then
        status="Paired, Disconnected"
    fi

    echo "qst! title  Bluetooth: ${arg} "
    echo "qst! action ExecuteAndRefresh"
    echo "qst! item   <- Back to summary|b! |PopLastToken @meta:permanent=true"
    echo "  [${status}] @meta:nonselectable=true @meta:active=true|"

    if [[ "$connected" == "1" ]]; then
        echo "  Disconnect|bluetoothctl disconnect ${arg} @meta:urgent=true"
    else
        echo "  Connect|bluetoothctl connect ${arg}"
    fi

    if [[ "$paired" != "1" ]]; then
        echo "  Pair|bluetoothctl pair ${arg} @meta:urgent=true"
    fi

    if [[ "$trusted" != "1" ]]; then
        echo "  Trust (Auto-connect in future)|bluetoothctl trust ${arg}"
    else
        echo "  Untrust|bluetoothctl untrust ${arg}"
    fi

    echo "  Remove / Forget|bluetoothctl remove ${arg} @meta:urgent=true"
    exit 0
fi

power_status="OFF"
scan_status="OFF"
power_target="b! power on"
scan_target="b! scan on"
power_label="Enable Bluetooth"
scan_label="Scan for Devices"

if is_powered; then
    power_status="ON"
    power_target="b! power off"
    power_label="Disable Bluetooth"
fi

if is_scanning; then
    scan_status="ON"
    scan_target="b! scan off"
    scan_label="Stop Scanning"
fi

echo "qst! title  Bluetooth "
echo "qst! action SetSearchQuery"
echo "  Power: [${power_status}] -> ${power_label}|${power_target} @meta:urgent=true"
echo "  Scan:  [${scan_status}] -> ${scan_label}|${scan_target} @meta:urgent=true"
echo "  ──────────────────────────── @meta:nonselectable=true|"

devices_found=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^Device[[:space:]]+([[:xdigit:]:]+)[[:space:]]+(.+)$ ]]; then
        mac="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        read -r connected paired trusted < <(device_info_flags "$mac")
        device_meta=" @meta:meta=bluetooth,device"
        if [[ "$connected" == "1" ]]; then
            device_meta="${device_meta} @meta:active=true"
        fi
        echo "  ${name}  (${mac})|b! ${mac}${device_meta}"
        devices_found=1
    fi
done < <(bluetoothctl devices 2>/dev/null)

if [[ "$devices_found" == "0" ]]; then
    echo "  No devices found (Scan to find more) @meta:nonselectable=true|"
fi