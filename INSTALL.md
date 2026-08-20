# Friendly installation guide

This is the shortest supported route to the validated patched kernel. It is
for Ubuntu 26.04 on `amd64`, before a released Ubuntu kernel contains the
upstream AW88399 support.

## Before starting

You need:

- power connected to the laptop;
- a reliable internet connection;
- at least 25 GiB of free disk space;
- at least 512 MiB free in `/boot`;
- your normal user account with `sudo` access;
- time: compiling a kernel can take from tens of minutes to several hours.

Keep Ubuntu's stock kernel installed. It is the recovery option if the custom
kernel, initramfs, or NVIDIA module does not work.

## Build and install

Open a terminal in this repository and run:

```sh
./setup-kernel.sh
```

The script explains what it will do and asks before starting. It:

1. checks the Ubuntu version, architecture, disk space, `/boot`, and Secure
   Boot state;
2. installs the compiler and packaging prerequisites;
3. downloads a pinned Linux 7.1.8 source archive, patch, and firmware;
4. verifies all three downloads by SHA-256;
5. copies the running Ubuntu kernel configuration and enables AW88399;
6. builds installable Ubuntu `.deb` packages;
7. installs the image, headers, and firmware and updates GRUB.

It does **not** remove any kernel, change the GRUB default, or reboot.

To download and configure everything without compiling, use:

```sh
./setup-kernel.sh --prepare-only
```

The build is resumable. Downloads, source, and output remain under `build/`.
Set `LEGION_BUILD_DIR` if another filesystem has more room, and set `JOBS` to
limit CPU usage:

```sh
LEGION_BUILD_DIR=/path/with/free/space JOBS=8 ./setup-kernel.sh
```

## Secure Boot

If the script reports that Secure Boot is enabled, do not assume the custom
kernel or NVIDIA module will load. Either follow Ubuntu's documented signing
and MOK-enrollment process or disable Secure Boot in the firmware settings.

## First boot

Read [the recovery guide](UBUNTU_26_04.md) before rebooting. Then:

1. Reboot into GRUB.
2. Select **Advanced options for Ubuntu**.
3. Select `7.1.8-legion-audio`.
4. After login, run `uname -r`; it must print `7.1.8-legion-audio`.
5. Run the audio checks in the recovery guide.

If the graphical encrypted-disk prompt appears broken, boot the stock Ubuntu
kernel and follow the permanent `i915` initramfs fix in the recovery guide.

## Later Ubuntu updates

Install normal Ubuntu updates, including Ubuntu's stock kernels. They are
installed alongside the uniquely named custom kernel and provide a recovery
path. Never approve removal of a package containing `legion-audio` unless you
intend to uninstall this kernel.
