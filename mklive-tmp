#!/bin/sh -eu
#
# mklive.sh
# Chimera Linux live image creation tool
# (Modified to fit in maintenance disk requirements)
#
# Copyright 2022 q66 <q66@chimera-linux.org>
#           2025 BarryLhm <BarryLhm@outlook.com>
#
# License: BSD-2-Clause
#
# Uses code from the Debian live-boot project, which is available under the
# GPL-3.0-or-later license. Therefore, as a combined work, this is provided
# under the GPL-3.0-or-later terms.
#

if [ "${DEBUG-}" ]
then	set -x
	DEBUG_SHELL="$DEBUG"
	DEBUG=1
else	DEBUG=0
fi

errors=0

[ "$(realpath "$0")" = "$(realpath -q mklive.sh || :)" ] || \
{
	echo "[Error] Please run under repo root dir"
	errors=1
}

[ "$(id -u)" = "0" ] || \
{
	echo "must be run as root"
	errors=1
}

[ "$errors" = 0 ] || exit "$errors"

 #################################################
 # first stage before mount namespace separation #
 #################################################

[ "${SECOND_STAGE-}" = 1 ] || \
{
	[ "$DEBUG" != 1 ] || export DEBUG="$DEBUG_SHELL"
	exec unshare -m env SECOND_STAGE=1 "$0" "$@"
}
  #######################
  # Inlined lib.sh here #
  #######################

#!/bin/sh
#
# Shared functions to be used by image creation scripts.
#
# Copyright 2022 q66 <q66@chimera-linux.org>
#
# License: BSD-2-Clause
#

umask 022

readonly PROGNAME="$(basename "$0")"

mount_pseudo()
{
	mount -t devtmpfs none "${ROOT_DIR:?}/dev" || die "failed to mount devfs"
	mount -t proc none "${ROOT_DIR:?}/proc" || die "failed to mount procfs"
	mount -t sysfs none "${ROOT_DIR:?}/sys" || die "failed to mount sysfs"
}

mount_pseudo_host()
{
	mount -t devtmpfs none "${HOST_DIR:?}/dev" || die "failed to mount devfs"
	mount -t proc none "${HOST_DIR:?}/proc" || die "failed to mount procfs"
	mount -t sysfs none "${HOST_DIR:?}/sys" || die "failed to mount sysfs"
}

error_sig()
{
	[ -z "${2-}" ] || msg "error at line $2"
	[ "$DEBUG" != 1 ] || \
	{
		echo "Entering debug shell"
		"$DEBUG_SHELL"
	}
	exit "${1-0}"
}

trap 'error_sig "$?" "$LINENO"' INT

msg()
{
	printf "\033[1m$*\n\033[m" >&2
}

die()
{
	msg "ERROR: $*"
	error_sig 1 "$LINENO"
}

  #########################
  # End of inlined lib.sh #
  #########################

######################################## Options processing

##### var init & defaults

APK_BIN="apk"
APK_ARCH=
BUILD_DIR="build"
MKLIVE_BOOTLOADER=
CMDLINE=
CACHE_DIR="apk-cache"
BIND_DIR=
CUSTOM_SHELL=
APK_KEYDIR=
KERNVER=
OUT_FILE=
PACKAGES=
APK_REPO=
FSTYPE="erofs"
CUSTOM_SCRIPT=
USE_TMPFS=none
TMPFS_SIZE=

HOST_PACKAGES="xorriso mtools dosfstools"
TARGET_PACKAGES=

##### use env var values

[ -z "${MKLIVE_BUILD_DIR-}" ] || BUILD_DIR="$MKLIVE_BUILD_DIR"
[ -z "${MKLIVE_CACHE_DIR-}" ] || CACHE_DIR="$MKLIVE_CACHE_DIR"

##### usage

usage()
{
	cat <<EOF
Usage: $PROGNAME <opts>

Options: (those with * is mandatory and ! is advanced option)
  -A APKPROG    Override the apk tool (default: apk)
  -a ARCH     ! Generate an image for ARCH (must be runnable on current machine, default: same as current)
  -b BUILDDIR   Temporary dir for building.
  -B BLTYPE   ! Bootloader to use (nyaboot and default: grub for ppc* and limine for others).
  -c CMDLINE    Extra kernel command line to append.
  -C DIR        APK cache directory during build (default: apk-cache)
  -D DIR      ! Direcory to be bound into the build container (/cust) before custom script (-S) is executed. (need -S)
  -h            Print this message.
  -I SHPROG   ! Open an interactive shell after custom script (-S) is executed. (need -S)
		(Notice: Build will fail if shell return non-0 value)
  -k DIR        Path to apk repository public key directory.
* -o FILE       Output a FILE (default: chimera-linux-ARCH-YYYYMMDD(-FLAVOR).iso)
* -p PACKAGES   List of packages to install.
* -r REPO       Path to apk repository.
  -s FSTYPE   ! Filesystem to use (squashfs or erofs, default: erofs).
  -S FILE     ! Script (copied to /customize.sh) to be executed during build (after packages, before packing).
  -t SIZE     ! Use tmpfs for target root directory. (refer to tmpfs manual page for SIZE param)
  -T SIZE     ! Use tmpfs for host, root and image directory with each size limited to SIZE (except host dir). (refer to tmpfs manual page for SIZE param)
EOF
	exit "${1-1}"
}

##### get options

needarg()(die "-$opt needs an argument")

set +eu
while getopts "A:a:b:B:c:C:D:f:hI:k:o:p:r:s:S:t:T:" opt
do	case "$opt" in
	A) APK_BIN="$OPTARG"	|| needarg;;
	a) APK_ARCH="$OPTARG"	|| needarg;;
	b) BUILD_DIR="$OPTARG"	|| needarg;;	## added
	B) MKLIVE_BOOTLOADER="$OPTARG"	|| needarg;;	## added
	c) CMDLINE="$OPTARG"	|| needarg;;
	C) CACHE_DIR="$OPTARG"	|| needarg;;	## added
	D) BIND_DIR="$OPTARG";;	## added
	h) usage 0	|| needarg;;
	I) CUSTOM_SHELL="$OPTARG" || needarg;;
	k) APK_KEYDIR="$OPTARG"	|| needarg;;
	## removed K) KERNVER
	o) OUT_FILE="$OPTARG"	|| needarg;; ## changed to mandatory
	p) PACKAGES="$OPTARG"	|| needarg;;	## changed to mandatory
	r) APK_REPO="$APK_REPO -X $OPTARG" || needarg;; ## changed to mandatory
	s) FSTYPE="$OPTARG"	|| needarg;;
	S) CUSTOM_SCRIPT="$OPTARG"	|| needarg;;	## added
	t) USE_TMPFS=half TMPFS_SIZE="$OPTARG"	|| needarg;;	## added
	T) USE_TMPFS=full TMPFS_SIZE="$OPTARG"	|| needarg;;	## added
	*) usage;;
	esac
done
set -eu
shift "$((OPTIND - 1))"

##### Check options

## functions needed to check options

run_host_apk() # (root, cmd, [args ...])
{
	"$APK_BIN" ${APK_REPO} --no-interactive --arch "$APK_ARCH" \
	 --cache-packages --cache-dir "$CACHE_DIR/$APK_ARCH" -p "$@"
}

run_apk()(run_host_apk "$@")

## apk binary

case "$APK_BIN" in
/*|./*) APK_BIN="$(realpath "$APK_BIN")";;
esac

"$APK_BIN" -V > /dev/null 2>&1 || die "invalid apk command"

## default apk arch

[ "$APK_ARCH" ] || APK_ARCH="$("$APK_BIN" --print-arch)"

## fstype

case "$FSTYPE" in
erofs) HOST_PACKAGES="$HOST_PACKAGES erofs-utils";;
squashfs) HOST_PACKAGES="$HOST_PACKAGES squashfs-tools-ng";;
*) die "unknown live filesystem '$FSTYPE'";;
esac

## bootloader

# default
[ "$MKLIVE_BOOTLOADER" ] || \
{
case "$APK_ARCH" in
ppc*) MKLIVE_BOOTLOADER="grub";;
*) MKLIVE_BOOTLOADER="limine";;
esac
}

case "$MKLIVE_BOOTLOADER" in
limine) HOST_PACKAGES="$HOST_PACKAGES limine";;
nyaboot) HOST_PACKAGES="$HOST_PACKAGES nyaboot";;
grub)	HOST_PACKAGES="$HOST_PACKAGES grub"
	case "$APK_ARCH" in
	aarch64) TARGET_PACKAGES="$TARGET_PACKAGES grub-arm64-efi";;
	ppc*) TARGET_PACKAGES="$TARGET_PACKAGES grub-powerpc-ieee1275";;
	riscv64) TARGET_PACKAGES="$TARGET_PACKAGES grub-riscv64-efi";;
	loongarch64) TARGET_PACKAGES="$TARGET_PACKAGES grub-loongarch64-efi";;
	x86_64) TARGET_PACKAGES="$TARGET_PACKAGES grub-i386-efi grub-i386-pc grub-x86_64-efi";;
	*) die "unknown GRUB target for $APK_ARCH";;
	esac
esac

## out file and packages

[ "$OUT_FILE" ] || die "Please specify output file path"
[ "$PACKAGES" ] || die "Please specify packages"

## repositories

[ "$APK_REPO" ] || die "Please specify repositories"
for f in ${APK_REPO}; do
	case "$f" in
	-X|--repository);;
	http*);;
	*)	if [ ! -f "${f}/${APK_ARCH}/APKINDEX.tar.gz" ]
		then die "invalid local repository $f"
		fi;;
	esac
done

## key dir
[ "$APK_KEYDIR" ] || APK_KEYDIR="keys"
[ -d "$APK_KEYDIR" ] || die "must provide a valid public key directory"

## cache dir
[ -d "$CACHE_DIR" ] || die "Invalid cache dir '$CACHE_DIR'"
mkdir -p "$CACHE_DIR/$APK_ARCH"
# apk needs an aboslute path or the path is regarded as relative to target root
CACHE_DIR="$(realpath "$CACHE_DIR")"

## build dir
[ ! -e "$BUILD_DIR" ] || die "build dir '$BUILD_DIR' already exists"
mkdir -p "$BUILD_DIR"
# make absolute so that we aren't prone to bad cleanup with changed cwd
BUILD_DIR="$(realpath "$BUILD_DIR")"

IMAGE_DIR="$BUILD_DIR/image"
ROOT_DIR="$BUILD_DIR/rootfs"
HOST_DIR="$BUILD_DIR/host"
LIVE_DIR="$IMAGE_DIR/live"

mkdir "${ROOT_DIR:?}" "$IMAGE_DIR" "${LIVE_DIR:?}" "${HOST_DIR:?}" || die "failed to create directories"

# tmpfs build dir
case "$USE_TMPFS" in
half)	msg "[Warning] Using tmpfs for target root directory"
	mount -t tmpfs -o noatime,size="$TMPFS_SIZE" mklive-tmproot "${ROOT_DIR:?}";;
full)	msg "[Warning] Using tmpfs for host, root and image directory"
	mount -t tmpfs -o noatime mklive-tmphost "${HOST_DIR:?}"
	mount -t tmpfs -o noatime,size="$TMPFS_SIZE" mklive-tmproot "${ROOT_DIR:?}"
	mount -t tmpfs -o noatime,size="$TMPFS_SIZE" mklive-tmpimage "$IMAGE_DIR"
	mkdir "${LIVE_DIR:?}";;
none);;
esac


WRKSRC="$(pwd)"

## custom script & bind dir
[ -z "$CUSTOM_SCRIPT" ] || CUSTOM_SCRIPT="$(realpath "$CUSTOM_SCRIPT")"
[ -z "$BIND_DIR" ] || \
{
	[ -d "$BIND_DIR" ] || die "Invalid bind directory"
	BIND_DIR="$(realpath "$BIND_DIR")"
}

######################################## Start build

## copy keys
msg "Copying signing keys..."

mkdir -p "${ROOT_DIR:?}/etc/apk/keys" || die "failed to create keys directory"
mkdir -p "${HOST_DIR:?}/etc/apk/keys" || die "failed to create host keys directory"
for i in "${APK_KEYDIR}"/*.pub
do	[ -r "$i" ] || continue
	cp "$i" "${ROOT_DIR:?}/etc/apk/keys" || die "failed to copy key to target :'$i'"
	cp "$i" "${HOST_DIR:?}/etc/apk/keys" || die "failed to copy key to host: '$i'"
done

## install host setup
msg "Installing host base packages..."

run_host_apk "${HOST_DIR:?}" --initdb add chimerautils || die "failed to install host chimerautils"

msg "Mounting host pseudo-filesystems..."
mount_pseudo_host

msg "Installing host packages..."
run_host_apk "${HOST_DIR:?}" add ${HOST_PACKAGES} || die "failed to install host packages"

## install target packages
msg "Installing target base packages..."

run_apk "${ROOT_DIR:?}" --initdb add chimerautils || die "failed to install chimerautils"

## needs to be available before adding full package set
msg "Mounting pseudo-filesystems..."
mount_pseudo

msg "Installing target packages..."
run_apk "${ROOT_DIR:?}" add ${PACKAGES} ${TARGET_PACKAGES} || die "failed to install full rootfs"

######################################## Customization

[ -z "${CUSTOM_SCRIPT-}" ] || \
{
	[ -z "${BIND_DIR-}" ] || \
	{
		mkdir "${ROOT_DIR:?}/cust"
		mount -rB "$BIND_DIR" "${ROOT_DIR:?}/cust"
	}

	cp "$CUSTOM_SCRIPT" "${ROOT_DIR:?}/customize.sh"
	chmod +x "${ROOT_DIR:?}/customize.sh"
	chroot "${ROOT_DIR:?}" /customize.sh
	rm "${ROOT_DIR:?}/customize.sh"

	[ -z "$CUSTOM_SHELL" ] || \
	{
		chroot "${ROOT_DIR:?}" "$CUSTOM_SHELL"
	}

	[ -z "${BIND_DIR-}" ] || \
	{
		umount -lf "${ROOT_DIR:?}/cust"
		rmdir "${ROOT_DIR:?}/cust"
	}
}

######################################## Packing image

## determine kernel version
for i in "${ROOT_DIR:?}/boot/"vmlinu[xz]-*
do	[ -f "$i" ] || break
	KERNVER=${i##*boot/}
	KERNVER=${KERNVER#*-}
	break
done

for i in "${ROOT_DIR:?}/boot/"vmlinu[xz]-*; do
	[ -f "$i" ] || break
	KERNFILE=${i##*boot/}
	KERNFILE=${KERNFILE%%-*}
	break
done

[ "$KERNVER" ] || die "live media require a kernel, but none detected"

[ "$KERNFILE" ] || die "no kernel found matching '${KERNVER}'"

# copy target-specific grub files
if [ "$MKLIVE_BOOTLOADER" = "grub" ]; then
	rm -rf "${HOST_DIR:?}/usr/lib/grub"
	cp -a "${ROOT_DIR:?}/usr/lib/grub" "${HOST_DIR:?}/usr/lib"
fi

# add live-boot initramfs stuff
msg "Copying live initramfs scripts..."

[ -x "${ROOT_DIR:?}/usr/bin/mkinitramfs" ] || \
 die "live media require initramfs-tools, but target root does not contain it"

copy_initramfs() {
	cp -R initramfs-tools/lib/live "${ROOT_DIR:?}/usr/lib" || return 1
	cp initramfs-tools/bin/* "${ROOT_DIR:?}/usr/bin" || return 1
	cp initramfs-tools/hooks/* "${ROOT_DIR:?}/usr/share/initramfs-tools/hooks" || return 1
	cp initramfs-tools/scripts/* "${ROOT_DIR:?}/usr/share/initramfs-tools/scripts" || return 1
	cp -R data "${ROOT_DIR:?}/lib/live"
}

cleanup_initramfs() {
	rm -rf "${ROOT_DIR:?}/usr/lib/live"
	cd "$WRKSRC/initramfs-tools/bin"
	for x in *; do
		rm -f "${ROOT_DIR:?}/usr/bin/$x"
	done
	cd "$WRKSRC/initramfs-tools/hooks"
	for x in *; do
		rm -f "${ROOT_DIR:?}/usr/share/initramfs-tools/hooks/$x"
	done
	cd "$WRKSRC/initramfs-tools/scripts"
	for x in *; do
		rm -f "${ROOT_DIR:?}/usr/share/initramfs-tools/scripts/$x"
	done
	cd "$WRKSRC"
}

copy_initramfs || die "failed to copy initramfs files"

# generate initramfs
msg "Generating initial ramdisk and copying kernel..."
chroot "${ROOT_DIR:?}" mkinitramfs -o /tmp/initrd "${KERNVER}" || die "unable to generate ramdisk"

mv "${ROOT_DIR:?}/tmp/initrd" "${LIVE_DIR:?}"

for i in "${ROOT_DIR:?}/boot/vmlinuz-${KERNVER}"; do
	cp "$i" "${LIVE_DIR:?}/vmlinuz"
done

# clean up target root
msg "Cleaning up target root..."

run_apk "${ROOT_DIR:?}" del chimerautils ${TARGET_PACKAGES}

cleanup_initramfs

cleanup_dirs() {
	for x in "$@"; do
		rm -rf "${ROOT_DIR:?}/${x}"
		mkdir -p "${ROOT_DIR:?}/${x}"
	done
}

cleanup_dirs run tmp root var/cache var/log var/tmp

chmod 777 "${ROOT_DIR:?}/tmp"
chmod 777 "${ROOT_DIR:?}/var/tmp"
chmod 750 "${ROOT_DIR:?}/root"

# clean up pointless ramdisk(s)
for f in "${ROOT_DIR:?}/boot/"initrd*; do
	[ -f "$f" ] && rm -f "$f"
done

# clean up backup shadow etc
rm -f "${ROOT_DIR:?}/etc/shadow-" "${ROOT_DIR:?}/etc/gshadow-" \
	 "${ROOT_DIR:?}/etc/passwd-" "${ROOT_DIR:?}/etc/group-" \
	 "${ROOT_DIR:?}/etc/subuid-" "${ROOT_DIR:?}/etc/subgid-"

case "$FSTYPE" in
	squashfs)
		# clean up tmpfiles with xattrs not supported by squashfs
		# (sd-tmpfiles will recreate them as necessary)
		#
		# this list may be expanded as needed
		rm -rf "${ROOT_DIR:?}/var/lib/tpm2-tss/system/keystore"
		;;
esac

# generate filesystem
msg "Generating root filesystem..."

mount --bind "${BUILD_DIR}" "${HOST_DIR:?}/mnt" || die "build dir bind mount failed"
[ "$USE_TMPFS" != "half" ] || mount --bind "${BUILD_DIR}/rootfs" "${HOST_DIR:?}/mnt/rootfs" || die "root dir bind mount failed"
[ "$USE_TMPFS" != "full" ] || \
{
	mount --bind "${BUILD_DIR}/rootfs" "${HOST_DIR:?}/mnt/rootfs" || die "root dir bind mount failed"
	mount --bind "${BUILD_DIR}/image" "${HOST_DIR:?}/mnt/image" || die "image dir bind mount failed"
}

case "$FSTYPE" in
	erofs)	# tried zstd, it's quite a bit bigger than xz... and experimental
		# when testing, level=3 is 1.9% bigger than 16 and 0.7% bigger than 9
		# ztailpacking has measurable space savings, fragments+dedupe does not
		chroot "${HOST_DIR:?}" /usr/bin/mkfs.erofs -b 4096 -z lzma -E ztailpacking \
		 /mnt/image/live/filesystem.erofs /mnt/rootfs || die "mkfs.erofs failed";;
	squashfs)	chroot "${HOST_DIR:?}" /usr/bin/gensquashfs --pack-dir /mnt/rootfs \
			 -c xz -k -x /mnt/image/live/filesystem.squashfs || die "gensquashfs failed";;
esac

# generate iso image
msg "Generating ISO image..."

generate_menu()
{
	sed \
	 -e "s|@@BOOT_TITLE@@|Chimera Maintenance Disk|g" \
	 -e "s|@@KERNFILE@@|$KERNFILE|g" \
	 -e "s|@@KERNVER@@|$KERNVER|g" \
	 -e "s|@@ARCH@@|$APK_ARCH|g" \
	 -e "s|@@BOOT_CMDLINE@@|$CMDLINE|g" \
	 "$1"
}

# grub support, mkrescue chooses what to do automatically

generate_iso_grub()
{
	# because host grub would not have all the targets
	chroot "${HOST_DIR:?}" /usr/bin/grub-mkrescue -o /mnt/image.iso \
	 --product-name "Chimera Maintenance Disk" \
	 --product-version "$(date "+%Y%m%d")" \
	 --mbr-force-bootable \
	 /mnt/image \
	 -volid "CHIMERA_LIVE"
}

# base args that will be present for any iso generation
generate_iso_base()
{
	chroot "${HOST_DIR:?}" /usr/bin/xorriso -as mkisofs -iso-level 3 \
	 -rock -joliet -max-iso9660-filenames -omit-period -omit-version-number \
	 -relaxed-filenames -allow-lowercase -volid CHIMERA_LIVE \
	 "$@" -o /mnt/image.iso /mnt/image
}

# maximally compatible setup for x86_64, one that can boot on bios machines
# as well as both mac efi and pc uefi, and from optical media as well as disk
generate_isohybrid_limine()
{
	generate_iso_base \
	 -eltorito-boot limine-bios-cd.bin -no-emul-boot -boot-load-size 4 \
	 -boot-info-table -hfsplus -apm-block-size 2048 -eltorito-alt-boot \
	 -e efi.img -efi-boot-part --efi-boot-image \
	 --protective-msdos-label --mbr-force-bootable
}

# just plain uefi support with nothing else, for non-x86 machines where there
# is no legacy to worry about, should still support optical media + disk
generate_efi_pure()
{
	generate_iso_base --efi-boot efi.img -efi-boot-part --efi-boot-image --protective-msdos-label
}

# ppc only, nyaboot + apm hybrid for legacy machines (mac, slof), modern
# machines do not care as long as it's mountable (and need no bootloader)
generate_ppc_nyaboot() {
	generate_iso_base \
	 -hfsplus -isohybrid-apm-hfsplus -hfsplus-file-creator-type chrp \
	 tbxi boot/ofboot.b -hfs-bless-by p boot -sysid PPC -chrp-boot-part
}

prepare_efi_img() {
	# make an efi image for eltorito (optical media boot)
	truncate -s 2949120 "${IMAGE_DIR}/efi.img" || die "failed to create EFI image"
	chroot "${HOST_DIR:?}" /usr/bin/mkfs.vfat -F12 -S 512 "/mnt/image/efi.img" > /dev/null \
	 || die "failed to format EFI image"
	LC_CTYPE=C chroot "${HOST_DIR:?}" /usr/bin/mmd -i "/mnt/image/efi.img" EFI EFI/BOOT \
	 || die "failed to populate EFI image"
	for img in "${IMAGE_DIR}/EFI/BOOT"/*; do
		img=${img##*/}
		LC_CTYPE=C chroot "${HOST_DIR:?}" /usr/bin/mcopy -i "/mnt/image/efi.img" \
		 "/mnt/image/EFI/BOOT/$img" "::EFI/BOOT/" || die "failed to populate EFI image"
	done
}

# grub.cfg for systems that parse this without invoking
# the actual bootloader, e.g. openpower systems and so on
mkdir -p "${IMAGE_DIR}/boot/grub"
generate_menu grub/menu.cfg.in > "${IMAGE_DIR}/boot/grub/grub.cfg"

case "$MKLIVE_BOOTLOADER" in
limine)	generate_menu limine/limine.conf.in > "${IMAGE_DIR}/limine.conf"
	# efi executables for usb/disk boot
	mkdir -p "${IMAGE_DIR}/EFI/BOOT"
	case "$APK_ARCH" in
	x86_64)	cp "${HOST_DIR:?}/usr/share/limine/BOOTIA32.EFI" "${IMAGE_DIR}/EFI/BOOT"
		cp "${HOST_DIR:?}/usr/share/limine/BOOTX64.EFI" "${IMAGE_DIR}/EFI/BOOT";;
	aarch64) cp "${HOST_DIR:?}/usr/share/limine/BOOTAA64.EFI" "${IMAGE_DIR}/EFI/BOOT";;
	riscv64) cp "${HOST_DIR:?}/usr/share/limine/BOOTRISCV64.EFI" "${IMAGE_DIR}/EFI/BOOT";;
	loongarch64)cp "${HOST_DIR:?}/usr/share/limine/BOOTLOONGARCH64.EFI" "${IMAGE_DIR}/EFI/BOOT";;
	*) die "Unknown architecture $APK_ARCH for EFI";;
	esac
	# make an efi image for eltorito (optical media boot)
	prepare_efi_img
	# now generate
	case "$APK_ARCH" in
	x86_64)	# but first, necessary extra files for bios
		cp "${HOST_DIR:?}/usr/share/limine/limine-bios-cd.bin" "${IMAGE_DIR}"
		cp "${HOST_DIR:?}/usr/share/limine/limine-bios.sys" "${IMAGE_DIR}"
		# generate image
		generate_isohybrid_limine || die "failed to generate ISO image"
		# and install bios
		chroot "${HOST_DIR:?}" /usr/bin/limine bios-install "/mnt/image.iso";;
	aarch64|loongarch64|riscv64) generate_efi_pure || die "failed to generate ISO image";;
	*) die "Unknown architecture $APK_ARCH for limine";;
	esac;;
nyaboot)	case "$APK_ARCH" in
		ppc*);;
		*) die "Unknown architecture $APK_ARCH for nyaboot";;
		esac
		# necessary dirs
		mkdir -p "${IMAGE_DIR}/boot"
		mkdir -p "${IMAGE_DIR}/etc"
		mkdir -p "${IMAGE_DIR}/ppc/chrp"
		# generate menu
		generate_menu yaboot/yaboot.conf.in > "${IMAGE_DIR}/etc/yaboot.conf"
		generate_menu yaboot/yaboot.msg.in > "${IMAGE_DIR}/etc/yaboot.msg"
		# needs to be present in both locations
		cat yaboot/ofboot.b > "${IMAGE_DIR}/boot/ofboot.b"
		cat yaboot/ofboot.b > "${IMAGE_DIR}/ppc/bootinfo.txt"
		# now install the yaboot binary
		cp "${HOST_DIR:?}/usr/lib/nyaboot.bin" "${IMAGE_DIR}/boot/yaboot";;
grub)		generate_iso_grub || die "failed to generate ISO image";;
*) die "Unknown bootloader '$MKLIVE_BOOTLOADER'";;
esac

mv "$BUILD_DIR/image.iso" "$OUT_FILE"

msg "Successfully generated image '$OUT_FILE'"
