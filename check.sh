#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "$0")" && pwd)

bash -n "$repo_root/install.sh"
bash -n "$repo_root/uninstall.sh"
sh -n "$repo_root/bin/studio-display-hbr3"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck \
    "$repo_root/install.sh" \
    "$repo_root/uninstall.sh" \
    "$repo_root/bin/studio-display-hbr3"
fi

if udevadm verify --help >/dev/null 2>&1; then
  udevadm verify --no-style \
    "$repo_root/udev/30-amdgpu-pm.rules" \
    "$repo_root/udev/99-studio-display-hbr3.rules"
fi

git -C "$repo_root" diff --check
echo "All available checks passed."
