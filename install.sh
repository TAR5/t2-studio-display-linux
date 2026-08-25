#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")" && pwd)

if (( EUID != 0 )); then
  exec sudo -- "$0" "$@"
fi

gpu_found=0
for device_path in /sys/bus/pci/devices/*; do
  [[ -r "$device_path/vendor" ]] || continue
  [[ $(<"$device_path/vendor") == 0x1002 ]] || continue
  [[ $(<"$device_path/device") == 0x7340 ]] || continue
  [[ $(<"$device_path/subsystem_vendor") == 0x106b ]] || continue
  [[ $(<"$device_path/subsystem_device") == 0x0210 ]] || continue
  gpu_found=1
  break
done

if (( ! gpu_found )); then
  echo "Refusing installation: the tested Apple Radeon Pro 5300M was not found." >&2
  echo "This workaround is intentionally hardware-specific." >&2
  exit 1
fi

install -Dm0755 "$repo_root/bin/studio-display-hbr3" \
  /usr/local/libexec/studio-display-hbr3
install -Dm0644 "$repo_root/udev/30-amdgpu-pm.rules" \
  /etc/udev/rules.d/30-amdgpu-pm.rules
install -Dm0644 "$repo_root/udev/99-studio-display-hbr3.rules" \
  /etc/udev/rules.d/99-studio-display-hbr3.rules

if udevadm verify --help >/dev/null 2>&1; then
  udevadm verify --no-style \
    /etc/udev/rules.d/30-amdgpu-pm.rules \
    /etc/udev/rules.d/99-studio-display-hbr3.rules
fi

udevadm control --reload-rules

echo "Installed the DPM and Studio Display HBR3 udev workaround."
echo "Disconnect the Studio Display and reboot before the first test."
