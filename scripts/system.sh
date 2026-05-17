#!/usr/bin/env bash
set -euo pipefail

echo "qst! meta System Power, 1.0.0, GitanElyon, Reboots, powers off, or suspends the computer."

echo "qst! title System Power"

action_backend="systemctl"
if ! command -v "$action_backend" >/dev/null 2>&1; then
    echo "qst! action None"
    echo "qst! item  systemctl is not available on this system|systemctl is not available on this system|None @meta:nonselectable=true @meta:center=true"
    exit 0
fi

echo "qst! action None"
echo "qst! item  Reboot|$action_backend reboot|Execute,ExitApp"
echo "qst! item  Shut Down|$action_backend poweroff|Execute,ExitApp"
echo "qst! item  Sleep|$action_backend suspend|Execute,ExitApp"
