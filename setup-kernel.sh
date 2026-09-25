#!/usr/bin/env bash
set -Eeuo pipefail

readonly KERNEL_VERSION=7.1.8
readonly LOCAL_VERSION=-legion-audio
readonly KERNEL_RELEASE=${KERNEL_VERSION}${LOCAL_VERSION}
readonly PACKAGE_VERSION=${KERNEL_VERSION}-1
readonly UPSTREAM_REV=0ab1581365cdde211ca37ea46974b36ccca25ca7
readonly KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-${KERNEL_VERSION}.tar.xz
readonly PATCH_URL=https://raw.githubusercontent.com/nadimkobeissi/16iax10h-linux-sound-saga/${UPSTREAM_REV}/fix/patches/16iax10h-audio-linux-7.1.6.patch
readonly FIRMWARE_URL=https://raw.githubusercontent.com/nadimkobeissi/16iax10h-linux-sound-saga/${UPSTREAM_REV}/fix/firmware/aw88399_acf.bin
readonly KERNEL_SHA256=ff01dcb449279d5b4cfccdb01fee639cf5ff1803f1749a77844dd33915422c49
readonly PATCH_SHA256=f6501d7042ab668ed63959d007dd9c6810e60f314761c621c6afd829b6825c09
readonly FIRMWARE_SHA256=1e927c9bca76d868181c0f81df2bccef3cf19c7d0910219f229360c87babd42c

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
work_dir=${LEGION_BUILD_DIR:-$script_dir/build}
jobs=${JOBS:-$(nproc)}
assume_yes=false
prepare_only=false

usage() {
	cat <<'EOF'
Build and install the validated Legion AW88399 kernel on Ubuntu 26.04.

Usage: ./setup-kernel.sh [--yes] [--prepare-only]

  --yes           Skip the confirmation prompt.
  --prepare-only  Download, patch, and configure the source without compiling.

Environment:
  LEGION_BUILD_DIR  Build directory (default: ./build)
  JOBS              Parallel compiler jobs (default: all CPU threads)

The script never removes kernels, changes the GRUB default, or reboots.
EOF
}

for argument in "$@"; do
	case $argument in
		--yes) assume_yes=true ;;
		--prepare-only) prepare_only=true ;;
		-h|--help) usage; exit 0 ;;
		*) printf 'Unknown option: %s\n' "$argument" >&2; usage >&2; exit 2 ;;
	esac
done

if [ "$(id -u)" -eq 0 ]; then
	printf '%s\n' 'Do not run this whole script as root. Run it as your normal user.' >&2
	exit 1
fi

if [ ! -r /etc/os-release ]; then
	printf '%s\n' 'Cannot identify this operating system.' >&2
	exit 1
fi
. /etc/os-release
if [ "${ID:-}" != ubuntu ] || [ "${VERSION_ID:-}" != 26.04 ]; then
	printf 'This workflow is validated only on Ubuntu 26.04; found %s %s.\n' \
		"${ID:-unknown}" "${VERSION_ID:-unknown}" >&2
	exit 1
fi
if [ "$(dpkg --print-architecture)" != amd64 ]; then
	printf '%s\n' 'This workflow currently supports only amd64.' >&2
	exit 1
fi

available_kb=$(df -Pk "$script_dir" | awk 'NR == 2 { print $4 }')
if [ "$available_kb" -lt 26214400 ]; then
	printf '%s\n' 'At least 25 GiB free is required for kernel sources and build output.' >&2
	exit 1
fi
boot_available_kb=$(df -Pk /boot | awk 'NR == 2 { print $4 }')
if [ "$boot_available_kb" -lt 524288 ]; then
	printf '%s\n' '/boot has less than 512 MiB free. Free space before continuing.' >&2
	exit 1
fi

printf 'Target kernel: %s\nBuild directory: %s\nCompiler jobs: %s\n' \
	"$KERNEL_RELEASE" "$work_dir" "$jobs"
printf '%s\n' 'Expect a large download and a build that may take one or more hours.'

if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
	cat >&2 <<'EOF'

WARNING: Secure Boot is enabled. This custom kernel and third-party modules may
not load until you sign them and enroll your key, or disable Secure Boot in
firmware settings. The script will build, but do not reboot into the custom
kernel until you have addressed this.
EOF
fi

if ! $assume_yes; then
	printf '\nContinue? [y/N] '
	read -r answer
	case $answer in [yY]|[yY][eE][sS]) ;; *) printf '%s\n' 'Cancelled.'; exit 0 ;; esac
fi

printf '\nInstalling build prerequisites...\n'
sudo apt-get update
sudo apt-get install -y \
	bc bison build-essential ca-certificates curl debhelper dwarves fakeroot \
	flex libelf-dev libncurses-dev libssl-dev python3 rsync xz-utils \
	libdw-dev

mkdir -p "$work_dir/downloads"
archive=$work_dir/downloads/linux-${KERNEL_VERSION}.tar.xz
patch_file=$work_dir/downloads/16iax10h-audio.patch
firmware_file=$work_dir/downloads/aw88399_acf.bin

download() {
	url=$1
	target=$2
	hash=$3
	if [ -f "$target" ] && printf '%s  %s\n' "$hash" "$target" | sha256sum -c --status; then
		printf 'Using verified download: %s\n' "$target"
		return
	fi
	curl --fail --location --progress-bar "$url" --output "$target.part"
	mv -- "$target.part" "$target"
	printf '%s  %s\n' "$hash" "$target" | sha256sum -c
}

download "$KERNEL_URL" "$archive" "$KERNEL_SHA256"
download "$PATCH_URL" "$patch_file" "$PATCH_SHA256"
download "$FIRMWARE_URL" "$firmware_file" "$FIRMWARE_SHA256"

source_dir=$work_dir/linux-$KERNEL_VERSION
if [ ! -d "$source_dir" ]; then
	printf '\nExtracting Linux %s...\n' "$KERNEL_VERSION"
	tar -C "$work_dir" -xf "$archive"
fi

if [ ! -e "$source_dir/.legion-audio-patched" ]; then
	printf '\nApplying the AW88399 patch...\n'
	patch -d "$source_dir" -p1 --forward < "$patch_file"
	touch "$source_dir/.legion-audio-patched"
fi

running_config=/boot/config-$(uname -r)
if [ ! -r "$running_config" ]; then
	printf 'Kernel configuration not found: %s\n' "$running_config" >&2
	exit 1
fi
if [ ! -e "$source_dir/.legion-audio-configured" ]; then
	cp -- "$running_config" "$source_dir/.config"
	"$source_dir/scripts/config" --file "$source_dir/.config" \
		--set-str LOCALVERSION "$LOCAL_VERSION" \
		--module SND_HDA_SCODEC_AW88399 \
		--module SND_HDA_SCODEC_AW88399_I2C \
		--set-str SYSTEM_TRUSTED_KEYS '' \
		--set-str SYSTEM_REVOCATION_KEYS ''
	make -C "$source_dir" olddefconfig
	touch "$source_dir/.legion-audio-configured"
fi

configured_release=$(make -s -C "$source_dir" kernelrelease)
if [ "$configured_release" != "$KERNEL_RELEASE" ]; then
	printf 'Unexpected configured release: %s (wanted %s)\n' \
		"$configured_release" "$KERNEL_RELEASE" >&2
	exit 1
fi

if $prepare_only; then
	printf '\nPrepared and configured %s in %s\n' "$KERNEL_RELEASE" "$source_dir"
	exit 0
fi

printf '\nBuilding Debian packages. This is the long part...\n'
make -C "$source_dir" -j"$jobs" bindeb-pkg \
	KDEB_PKGVERSION="$PACKAGE_VERSION"

image_deb=$work_dir/linux-image-${KERNEL_RELEASE}_${PACKAGE_VERSION}_amd64.deb
headers_deb=$work_dir/linux-headers-${KERNEL_RELEASE}_${PACKAGE_VERSION}_amd64.deb
if [ ! -r "$image_deb" ] || [ ! -r "$headers_deb" ]; then
	printf '%s\n' 'Build finished but the expected image or headers package is missing.' >&2
	exit 1
fi

printf '\nInstalling firmware and kernel packages...\n'
sudo install -m 0644 "$firmware_file" /lib/firmware/aw88399_acf.bin
sudo apt-get install -y "$headers_deb" "$image_deb"
sudo update-grub

if [ -r /etc/crypttab ] && grep -Eq '^[[:space:]]*[^#[:space:]]' /etc/crypttab; then
	cat <<EOF

Encrypted volumes were detected. If the graphical LUKS prompt does not work
with the custom kernel, run:

  sudo $script_dir/tools/ubuntu-initramfs/install.sh $KERNEL_RELEASE
EOF
fi

if command -v nvidia-smi >/dev/null 2>&1 && command -v dkms >/dev/null 2>&1; then
	if ! dkms status -k "$KERNEL_RELEASE" 2>/dev/null | grep -qi nvidia; then
		cat >&2 <<EOF

WARNING: no NVIDIA DKMS module was detected for $KERNEL_RELEASE.
Do not make this kernel your default until the NVIDIA module is built.
EOF
	fi
fi

cat <<EOF

Installed $KERNEL_RELEASE. The script did not change the GRUB default or reboot.

Next:
  1. Read the recovery notes in UBUNTU_26_04.md.
  2. Reboot and select $KERNEL_RELEASE under "Advanced options for Ubuntu".
  3. Confirm with: uname -r
  4. Keep the stock Ubuntu kernel installed as your recovery path.
EOF
