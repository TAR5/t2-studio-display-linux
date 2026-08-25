# Diagnosis and A/B results

## Symptoms

On the tested MacBookPro16,1, connecting an Apple Studio Display while AMDGPU
used its default dynamic power-management behavior caused combinations of:

- a briefly visible wallpaper;
- flicker and block-like artifacts;
- a white or black external screen;
- a frozen internal screen;
- rapidly increasing fan speed;
- a complete lock requiring a forced shutdown.

The previous-boot journal did not contain a definitive SMU, GPU reset, OOM,
thermal, or PCIe AER error. That absence did not exclude a firmware or
power-state deadlock because a hard hardware lock can stop logging before the
failure is recorded.

## Power-management isolation

Before connection, the GPU reported:

    power_dpm_force_performance_level: auto
    PCI power/control: on
    runtime_status: active

The kernel also logged:

    amdgpu: Runtime PM not available

That message excludes PCI runtime suspend on this setup, but not SMU/DPM
clock and voltage changes, memory-clock transitions, clock gating, or display
power transitions.

Forcing this live setting before hotplug prevented the lock:

~~~sh
printf high | sudo tee \
  /sys/bus/pci/drivers/amdgpu/0000:03:00.0/power_dpm_force_performance_level
~~~

This matched the T2 Linux documentation, which associates freezes followed by
high fan speed and sudden shutdown with AMDGPU DPM on MacBookPro16,1.

## Link isolation

With DPM held at high, the Studio Display connected successfully at 5K60 but
still flickered. AMD debugfs showed:

    Current:   4  0x14
    Reported:  4  0x14
    max_bpc:   8
    dsc_clock_en: 1

0x14 is HBR2. A live retrain to HBR3 used:

~~~sh
printf '4 0x1e' | sudo tee \
  /sys/kernel/debug/dri/0000:03:00.0/DP-6/link_settings
~~~

Afterward:

    Current:    4  0x1e
    Preferred:  4  0x1e

The flicker stopped and the system remained stable.

The debugfs dsc_clock_en value still read 1 immediately after the live
retrain. Therefore this repository does not claim that the flag proves DSC
was disabled in the tested session. HBR3 provides enough payload for 5K60 at
8 bpc without compression, but the observed result establishes only that the
HBR3 retrain removed the flicker.

## Conclusion

The evidence points to two independent failure sources:

1. AMDGPU dynamic power-state transitions caused or enabled the hard lock.
2. The automatically selected HBR2 display path caused the visible flicker.

The combination of DPM high and HBR3 was stable. Either change alone was
insufficient for the complete result.

## Why the workaround is scoped

The DPM udev rule matches all of the following on one PCI parent:

    vendor:            0x1002
    device:            0x7340
    subsystem_vendor:  0x106b
    subsystem_device:  0x0210

The hotplug helper separately verifies manufacturer APP and one of three
known Studio Display product IDs before writing link settings. This avoids
forcing HBR3 on an unrelated DisplayPort sink.
