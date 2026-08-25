# T2 Studio Display Linux

A hardware-specific recipe for running an Apple Studio Display at
5120×2880 @ 60 Hz from a 2019 16-inch Intel MacBook Pro under Linux.

The tested result is stable 5K60 at 8 bpc over a four-lane HBR3 DisplayPort
link, with the MacBook panel automatically disabled while the Studio Display
is attached.

> [!WARNING]
> This is an experimental workaround for one specific T2 Mac configuration.
> The failure mode before the fix was a complete system lock, rapidly
> increasing fan speed, and forced shutdown. Keep a known-good stock kernel
> boot entry and recovery media. Do not test first on a machine containing
> unbacked-up data.

## Tested setup

| Component | Tested value |
| --- | --- |
| Mac | MacBookPro16,1 (16-inch, 2019) |
| GPU | Radeon Pro 5300M / Navi 14, PCI 1002:7340, Apple subsystem 106b:0210 |
| Display | Apple Studio Display |
| Desktop | Omarchy Quattro with Hyprland |
| Kernel | Linux 7.1.8 T2 kernel plus the included Studio Display tile patch |
| Mode | 5120×2880 @ 60 Hz, XRGB8888, 8 bpc |
| Link | Four lanes at HBR3 (0x1e) |

Known Studio Display EDID product IDs handled by the helper are 0xAE3A,
0xAE42, and 0xAE46.

## What this fixes

Three separate pieces were required on the tested machine:

1. The kernel patch hides the secondary SST tile that the Studio Display
   exposes, allowing userspace to configure one full 5K output.
2. A narrowly scoped udev rule forces the MacBook's Radeon Pro 5300M DPM
   performance level to high before display hotplug. This prevented the hard
   locks and fan ramp observed with the default auto setting.
3. A hotplug helper verifies the Apple EDID and retrains only that connector
   to four-lane HBR3. This removed the visible flicker.

No persistent systemd service or polling daemon is installed.

On Omarchy, the helper also schedules Omarchy's native laptop-display toggle
after a verified Studio Display connection. Omarchy's existing monitor
watcher restores the internal panel after disconnection. Other desktops
simply skip this optional step.

## Why HBR3 matters

The display timing observed for 5K60 is roughly 936 MHz. At 24 bits per pixel,
the uncompressed pixel stream is about 22.46 Gbit/s:

    936 MHz × 24 bits = 22.464 Gbit/s

Four-lane HBR2 carries 17.28 Gbit/s after 8b/10b encoding, so it cannot carry
that stream uncompressed. Four-lane HBR3 carries 25.92 Gbit/s and can.

The live A/B test was:

| Configuration | Result |
| --- | --- |
| DPM auto, HBR2 | Flicker/artifacts followed by a hard lock and fan ramp |
| DPM high, HBR2 | No hard lock, but visible flicker |
| DPM high, HBR3 | Stable 5K60 with no flicker |

See [docs/diagnosis.md](docs/diagnosis.md) for the full technical record.

## Repository layout

    bin/studio-display-hbr3
        EDID-gated HBR3 hotplug helper and optional Omarchy panel toggle
    udev/30-amdgpu-pm.rules
        MacBookPro16,1 Radeon Pro 5300M DPM rule
    udev/99-studio-display-hbr3.rules
        AMD DisplayPort hotplug rule
    kernel/
        Arch/T2 PKGBUILD, tested configuration, and Studio Display tile patch
    install.sh
        Installs only the udev rules and helper
    uninstall.sh
        Removes only the files installed by install.sh

## Installation

Clone the repository:

~~~sh
git clone https://github.com/TAR5/t2-studio-display-linux.git
cd t2-studio-display-linux
~~~

### 1. Preserve a fallback

Before changing the kernel, confirm that the stock kernel still boots and
keep it as a separate boot-menu entry. Do not overwrite or remove it.

### 2. Build the alternate T2 kernel

The package is based on linux-t2-arch and applies the included AMD display
patch:

~~~sh
cd kernel
makepkg -si
~~~

The package name is linux-t2-studio, so it can remain an alternate kernel.
Review the PKGBUILD before building. Kernel packaging and boot-entry handling
vary between T2 Linux installations.

### 3. Install the runtime workaround

Disconnect the Studio Display, then run:

~~~sh
sudo ./install.sh
~~~

This installs three files:

    /etc/udev/rules.d/30-amdgpu-pm.rules
    /etc/udev/rules.d/99-studio-display-hbr3.rules
    /usr/local/libexec/studio-display-hbr3

### 4. Reboot into the alternate kernel

Before attaching the display, verify that DPM is high:

~~~sh
cat /sys/bus/pci/drivers/amdgpu/*/power_dpm_force_performance_level
~~~

The expected result is:

    high

If it is not high, do not connect the Studio Display yet. Check the hardware
IDs and udev logs first.

### 5. Connect and verify

After attaching the display, verify 5K60 in the compositor:

~~~sh
hyprctl monitors all
~~~

Verify the DisplayPort link as root:

~~~sh
sudo sh -c 'tr -d "\000" < /sys/kernel/debug/dri/0000:03:00.0/DP-6/link_settings'
~~~

The important current setting is four lanes at 0x1e:

    Current:  4  0x1e

Connector names and the PCI address can differ, although the helper derives
them dynamically.

## Power and thermal behavior

The DPM rule intentionally holds the Radeon GPU at performance level high.
That can increase idle power use, memory clock, heat, and battery drain.
This trade-off was required to prevent hard locking during Studio Display
hotplug on the tested machine.

If you travel on battery, either boot a configuration without this rule or
remove it and reboot. Do not switch back to auto while relying on the Studio
Display unless you are prepared for the original lockup to recur.

## Rollback

Disconnect the Studio Display and run:

~~~sh
sudo ./uninstall.sh
~~~

Then reboot. The uninstall script does not remove any kernel package or modify
boot entries. It also does not change the live GPU/link state, which avoids a
risky transition while the current session is running.

The alternate kernel can be removed separately after booting a different
kernel:

~~~sh
sudo pacman -R linux-t2-studio linux-t2-studio-headers
~~~

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md). If the machine locks,
boot the stock kernel with amdgpu disabled if necessary, disconnect the Studio
Display, and collect the previous boot journal before trying another change.

## Credits

- [T2 Linux](https://wiki.t2linux.org/guides/hybrid-graphics/) for the T2
  kernel work and documented AMDGPU DPM failure pattern.
- The AMD and Linux DRM contributors named in the included kernel patch.
- The [CachyOS community report](https://discuss.cachyos.org/t/fix-apple-studio-display-5k-flicker-black-screen-on-linux-with-amd-macbookpro16-1-by-forcing-displayport-hbr3-and-avoiding-dsc/29495)
  that identified HBR3 as the stable link mode on similar hardware.
- [Omarchy](https://omarchy.org/) for its native Hyprland monitor management.
- [linux-t2-arch](https://github.com/NoaHimesaka1873/linux-t2-arch), from
  which the kernel packaging files were adapted.

## License

Repository scripts and packaging are provided under GPL-3.0; see
[LICENSE](LICENSE). The kernel patch retains the licensing and attribution of
the Linux/AMD source files it modifies.
