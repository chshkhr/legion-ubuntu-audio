# Legion Ubuntu audio

Ubuntu support and recovery notes for Lenovo Legion laptops using AW88399
smart amplifiers. This project documents the configuration validated on a
Lenovo Legion Pro 7i Gen 10 (`16IAX10H`, audio SSID `17aa:3906`) running
Ubuntu 26.04 LTS with an encrypted root filesystem and a custom kernel.

The project currently provides:

- a tested Ubuntu custom-kernel and encrypted-root guide;
- a persistent dracut fix for a graphical LUKS prompt that does not accept
  input because `i915` is absent from the initramfs;
- optional early-boot tracing that writes limited diagnostics to the
  unencrypted `/boot` filesystem;
- AW88399 post-boot verification and safe recovery instructions.

## The easy route

If you want working speakers rather than a kernel-building hobby, start with
the [friendly installation guide](INSTALL.md). The included helper performs
preflight checks, downloads a pinned and verified source/patch combination,
builds Ubuntu packages, and installs them without removing your stock kernel
or rebooting automatically:

```sh
./setup-kernel.sh
```

For encrypted-root troubleshooting and technical detail, continue with
[the Ubuntu 26.04 recovery guide](UBUNTU_26_04.md).

## Kernel 7.3 status

The AW88399 HDA side-codec changes have been merged into the upstream Linux
tree and are **expected** to appear starting with Linux 7.3. A future release
is not guaranteed merely because a change is currently merged: verify the
released kernel and test it on the target laptop before retiring a working
custom kernel.

Even when the driver is present, the `aw88399_acf.bin` firmware must be
available in `/lib/firmware`. Until that firmware can be distributed by
`linux-firmware` under compatible terms, it may still require manual
installation.

Upstream references:

- [AW88399 HDA side-codec merge commit](https://github.com/torvalds/linux/commit/e5c91aac491def6ab3f90c4cc246e3fcb0f8f058)
- [original audio investigation and general kernel guide](https://github.com/nadimkobeissi/16iax10h-linux-sound-saga)
- [current patch development and technical background](https://github.com/marco-giunta/legion-pro7-gen10-audio)

## Validated configuration

The current instructions were validated with:

- Ubuntu 26.04 LTS;
- Linux `7.1.8-legion-audio` packaged as `.deb` files;
- LUKS2-encrypted root on LVM and a separate unencrypted `/boot`;
- dracut 110 and Plymouth;
- hybrid Intel `i915` and NVIDIA graphics.

The guide may help with similar systems, but do not apply the `i915` workaround
solely because the laptop has AW88399 amplifiers. First confirm that the target
initramfs omits `i915` and that the documented symptom matches.

## Safety and recovery

Always retain an Ubuntu stock kernel and make sure it remains selectable in
GRUB. Ubuntu kernel updates install alongside a uniquely named custom kernel;
they should not replace `linux-image-<version>-legion-audio`.

Before rebooting a rebuilt custom kernel, verify its initramfs as described in
the guide. If graphical disk unlock fails, select the stock Ubuntu kernel in
GRUB or remove `quiet splash` temporarily to use the text prompt.

## Repository layout

- [`INSTALL.md`](INSTALL.md): short, ordinary-user installation path.
- [`setup-kernel.sh`](setup-kernel.sh): reproducible, guarded kernel builder
  and installer.
- [`UBUNTU_26_04.md`](UBUNTU_26_04.md): installation, recovery, validation,
  and troubleshooting guide.
- [`tools/ubuntu-initramfs`](tools/ubuntu-initramfs): permanent early-`i915`
  dracut configuration and installer.
- [`tools/initramfs-trace`](tools/initramfs-trace): optional diagnostics for
  failures before the encrypted root is available.

## Relationship to the upstream project

This is an Ubuntu-specific companion project, not the upstream home of the
AW88399 driver. Driver changes, supported-device additions, and general kernel
work belong in the
[`16iax10h-linux-sound-saga`](https://github.com/nadimkobeissi/16iax10h-linux-sound-saga)
project or the relevant Linux subsystem.

The Ubuntu material began as a contribution to that project. It lives here so
Ubuntu-specific behavior can be documented and maintained by people who can
test it directly.

## Credits

The Linux audio solution is the work of multiple contributors, especially
Lyapsus, Nadim Kobeissi, Marco Giunta, Gergo K., and Richard Garber. See the
[upstream project](https://github.com/nadimkobeissi/16iax10h-linux-sound-saga#credits)
for the full technical history and attribution.
