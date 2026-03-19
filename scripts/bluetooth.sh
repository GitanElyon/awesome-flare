#!/usr/bin/env bash

QUERY="${1:-}"

if ! command -v bluetoothctl >/dev/null 2>&1; then
    echo "f! title  Bluetooth "
    echo "f! action None"
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
    echo "f! title  Bluetooth Help "
    echo "f! action None"
    echo "  b!           Open main bluetooth menu|"
    echo "  b! power on  Turn on Bluetooth adapter|"
    echo "  b! power off Turn off Bluetooth adapter|"
    echo "  b! scan on   Start scanning for devices|"
    echo "  b! scan off  Stop scanning|"
    exit 0
fi

if [[ "$arg" == "power on" ]]; then
    echo "f! title  Bluetooth Admin "
    echo "f! action ExecuteAndRefresh"
    echo "  Powering on...|bluetoothctl power on"
    exit 0
fi

if [[ "$arg" == "power off" ]]; then
    echo "f! title  Bluetooth Admin "
    echo "f! action ExecuteAndRefresh"
    echo "  Powering off...|bluetoothctl power off"
    exit 0
fi

if [[ "$arg" == "scan on" ]]; then
    echo "f! title  Bluetooth Admin "
    echo "f! action ExecuteAndRefresh"
    echo "  Starting scan...|bluetoothctl scan on"
    exit 0
fi

if [[ "$arg" == "scan off" ]]; then
    echo "f! title  Bluetooth Admin "
    echo "f! action ExecuteAndRefresh"
    echo "  Stopping scan...|bluetoothctl scan off"
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

    echo "f! title  Bluetooth: ${arg} "
    echo "f! action ExecuteAndRefresh"
    echo "f! item   <- Back to summary|b! |SetSearchQuery"
    echo "  [${status}]|"

    if [[ "$connected" == "1" ]]; then
        echo "  Disconnect|bluetoothctl disconnect ${arg}"
    else
        echo "  Connect|bluetoothctl connect ${arg}"
    fi

    if [[ "$paired" != "1" ]]; then
        echo "  Pair|bluetoothctl pair ${arg}"
    fi

    if [[ "$trusted" != "1" ]]; then
        echo "  Trust (Auto-connect in future)|bluetoothctl trust ${arg}"
    else
        echo "  Untrust|bluetoothctl untrust ${arg}"
    fi

    echo "  Remove / Forget|bluetoothctl remove ${arg}"
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

echo "f! title  Bluetooth "
echo "f! action SetSearchQuery"
echo "  Power: [${power_status}] -> ${power_label}|${power_target}"
echo "  Scan:  [${scan_status}] -> ${scan_label}|${scan_target}"
echo "  ────────────────────────────|"

devices_found=0
while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^Device[[:space:]]+([[:xdigit:]:]+)[[:space:]]+(.+)$ ]]; then
        mac="${BASH_REMATCH[1]}"
        name="${BASH_REMATCH[2]}"
        echo "  ${name}  (${mac})|b! ${mac}"
        devices_found=1
    fi
done < <(bluetoothctl devices 2>/dev/null)

if [[ "$devices_found" == "0" ]]; then
    echo "  No devices found (Scan to find more)|"
fi