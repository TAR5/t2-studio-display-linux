# Alternate T2 kernel package

This directory contains the tested Arch PKGBUILD for an alternate
linux-t2-studio kernel.

It is derived from
[linux-t2-arch](https://github.com/NoaHimesaka1873/linux-t2-arch) and pins the
T2 patch set by commit hash. The additional patch:

    apple-studio-display-secondary-tile.patch

adds the Apple Studio Display panel IDs to AMD's EDID quirks and hides the
secondary SST tile from userspace.

## Build

Review PKGBUILD and then run:

~~~sh
makepkg -si
~~~

Kernel compilation needs substantial disk space and time. The package build
directory can exceed 20 GB.

## Boot safety

- Keep the distribution stock kernel installed.
- Confirm the new kernel and initramfs appear as a separate boot entry.
- Do not delete the stock entry until the alternate kernel has survived
  repeated cold boots.
- If the boot manager verifies hashes, update its metadata using the method
  documented for your T2 Linux installation.
- Back up the finished package files before cleaning the build directory.

This package targets MacBookPro16,1. It intentionally skips a historical
MacBookPro15,1 i915 lane quirk from the T2 patch set.
