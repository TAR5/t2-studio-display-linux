#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

rm -f /etc/udev/rules.d/30-amdgpu-pm.rules
rm -f /etc/udev/rules.d/99-studio-display-hbr3.rules
rm -f /usr/local/libexec/studio-display-hbr3

udevadm control --reload-rules

echo "Removed the udev workaround files."
echo "The live GPU/link state was not changed. Disconnect the display and reboot."
