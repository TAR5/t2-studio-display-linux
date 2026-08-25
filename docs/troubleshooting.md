# Troubleshooting

## Safety first

Keep the Studio Display disconnected while changing GPU power-management or
kernel settings. Maintain a bootable stock kernel. If a connection hard-locks
the machine, force it off, disconnect the display, and recover on the internal
panel.

## DPM is not high after reboot

Confirm the exact GPU identity:

~~~sh
lspci -nnk -d 1002:
udevadm info --attribute-walk /sys/class/drm/card2
~~~

The supplied rule intentionally matches only Radeon device 1002:7340 with
Apple subsystem 106b:0210.

Check the installed rule and current value:

~~~sh
cat /etc/udev/rules.d/30-amdgpu-pm.rules
cat /sys/bus/pci/drivers/amdgpu/*/power_dpm_force_performance_level
~~~

Reloading rules affects future device events; reboot to test the early GPU
add event.

## The display connects but still flickers

Find connected AMD connectors:

~~~sh
for status in /sys/class/drm/card*-*/status; do
  printf '%s: ' "$status"
  cat "$status"
done
~~~

Check the EDID manufacturer/product bytes. A handled Studio Display begins
with one of these signatures at EDID offset 8:

    06 10 3a ae
    06 10 42 ae
    06 10 46 ae

For example:

~~~sh
od -An -tx1 -j8 -N4 /sys/class/drm/card2-DP-6/edid
~~~

Then check debugfs:

~~~sh
sudo sh -c 'tr -d "\000" < /sys/kernel/debug/dri/0000:03:00.0/DP-6/link_settings'
~~~

Current should contain four lanes and 0x1e. If debugfs is absent, confirm it
is mounted:

~~~sh
mount | grep debugfs
~~~

## 5K is missing or the display appears as two tiles

The udev helper does not solve the dual-SST-tile problem. Boot the alternate
kernel containing kernel/apple-studio-display-secondary-tile.patch and verify
the running kernel:

~~~sh
uname -r
~~~

Keep the stock kernel available as a fallback.

## Internal display does not turn off on Omarchy

The optional integration requires:

    /usr/bin/omarchy-hyprland-monitor-internal

Test the native command from the active desktop session:

~~~sh
omarchy-hyprland-monitor-internal off
~~~

Omarchy refuses to disable the only active output. The HBR3 helper schedules
the command two seconds after connection so Hyprland has time to activate the
Studio Display.

The default manual toggle is Super+Ctrl+Delete.

## Internal display does not return

First try the same Omarchy command:

~~~sh
omarchy-hyprland-monitor-internal on
~~~

If necessary, remove the toggle fragment and reload Hyprland:

~~~sh
rm -f ~/.local/state/omarchy/toggles/hypr/internal-monitor-disable.lua
hyprctl reload
~~~

## Collecting the previous boot

After a forced shutdown and safe reboot:

~~~sh
journalctl -k -b -1 --no-pager
journalctl -b -1 --no-pager
~~~

Look for amdgpu, SMU, GPU reset, CATERR, PCIe AER, thermal, OOM, or DRM atomic
commit messages. A clean ending still does not rule out a silent firmware or
hardware deadlock.
