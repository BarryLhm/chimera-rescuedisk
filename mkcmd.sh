#!/bin/sh -eu
#
# mkcmd.sh
# Chimera Maintenance Disk image creation tool
#
# Copyright 2025 BarryLhm <BarryLhm@outlook.com>
#
# License: GPL-3.0-or-later
#
# Uses code from Debian live-boot project, modified by q66 for chimera-live,
# which is available under GPL-3.0-or-later license. Therefore, as a combined
# work, this is provided under the GPL-3.0-or-later terms.
#


# different to chimera-live mklive.sh, this script recieve configurations
# from environment variables

#################### lib

##### public vars
prog="$(basename "$0")"
dir="$(dirname "$(realpath "$0")")"
stage=lib
first_stage=0
repo_args=
core_packages="chimerautils"
host_packages="xorriso mtools dosfstools limine erofs-utils"
umask 022

def_build_dirs()
{
	host_dir="$_build_dir/host"
	rootfs_dir="$_build_dir/rootfs"
	image_dir="$_build_dir/image"
	live_dir="$image_dir/live"

	rootfs_dir_in_host="/mnt/rootfs"
	image_dir_in_host="/mnt/image"
	live_dir_in_host="$image_dir_in_host/live"
}

##### public functions
help()
{
	cat <<-EOF
	usage: <_key=value ...> $prog [-h|--help] first_stage
	    (notice: the '_' is necessary)
	keys: (* mandatory, = default/options, . script parent dir)
	### runtime
	- apk          = apk       apk binary
	- key_dir      = ./keys    apk pubkey dir
	- cache_dir    = ./cache   apk cache dir
	- repos                    extra apk repositories separated by space
	- build_dir    = ./build   temp dir for building
	- use_tmpfs    = none      use tmpfs to accelerate build
	               = rootfs        for rootfs directory
	               = all           for host, rootfs and image directory
	- tmpfs_size   = 40%       'size' mount option for each tmpfs
	### io
	* out_file                 output image file
	- packages                 extra packages
	- cmdline                  extra kernel cmdline
	### cust
	- cust_repos   = ./repositories
	- cust_pkgs    = ./pkgs.d
	- cust_cmdline = ./cmdline
	- cust_dir     = ./cust
	- cust_script  = ./customize.sh
	- project_name = "Chimera Maintenance Disk"

	read manual and code to get detailed info
	EOF
	exit "${1-1}"
}

msg()(printf "\033[1m%s\033[m\n" "$@" >&2)

error()(msg "$prog: $1" "build failed in stage $stage"; return "${2-1}")

stage()
{
	[ "$#" = 0 ] || stage="$1"; msg "current stage: $stage"
}

var_init()
{
	local value="$1" error=0 badkeys=; shift
	[ "$#" != 0 ] || error "var_init: no keys"
	for i in "$@"
	do [ "$i" ] || error=1 badkeys="$badkeys ''"
	done
	badkeys="$badkeys$(printf "%s\0" "$@" | grep -Evxz "_[a-zA-Z0-9_]+" | \
	 xargs -0r printf " '%s'" | awk "{print} END {if (NR==0) exit 1}")" \
	 && error=1 || :
	[ "$error" = 0 ] || error "var_init: invalid key:$badkeys"
	for i in "$@"
	do [ "$(eval echo '"${'"$i"'-}"')" ] || \
	 eval "$i='$(echo "$value" | sed "s/'/'\\\''/g")'"
	done
}

mount_tmp()
{
	for i in "$@"
	do mount -t tmpfs -o noatime,size="$_tmpfs_size" mkcmd "$i"
	done
}

run_apk_at()
{
	local root="$1"; shift
	case "$root" in
	host) root="$host_dir";;
	rootfs) root="$rootfs_dir";;
	*) error "run_apk_at: invalid root '$root'";;
	esac
	"$_apk" --no-interactive --arch "x86_64" --cache-packages \
	 --cache-dir "$_cache_dir/x86_64" $repo_args -p "$root" "$@"
}

mount_pseudo_at()
{
	local root="$1" i; shift
	case "$root" in
	host) root="$host_dir";;
	rootfs) root="$rootfs_dir";;
	*) error "mount_pseudo_at: invalid root '$root'";;
	esac
	for i in "/proc -t proc" "/dev -t devtmpfs" "/sys -t sysfs"
	do mount -o noatime mkcmd "$root"$i
	done
}

host_run()(chroot -- "$host_dir" "$@")

#################### entry point
stage entry_point

[ "$#" = 0 ] && help || \
{
	until [ "$#" = 0 ]
	do	case "$1" in
		-h|--help) help 0;;
		first_stage) first_stage=1;;
		second_stage);;
		*) error "unknown option $1, run $prog -h to get help";;
		esac
	shift
	done
	[ "$first_stage" != 1 ] || \
	{
		msg "restarting in seperated mount namespace..."
		exec unshare -m -- sh -"$-" "$0" second_stage
	}
}

#################### options processing
stage options_processing

####### init vars

### defaults
var_init apk _apk
var_init "$dir/keys" _key_dir
var_init "$dir/cache" _cache_dir
var_init "$dir/build" _build_dir
var_init none _use_tmpfs
var_init 40% _tmpfs_size
var_init "$dir/repositories" _cust_repos
var_init "$dir/pkgs.d" _cust_pkgs
var_init "$dir/cmdline" _cust_cmdline
var_init "$dir/cust" _cust_dir
var_init "$dir/customize.sh" _cust_script
var_init "Chimera Maintenance Disk" _project_name

### avoid unset vars
var_init '' _repos _out_file _packages _cmdline

####### canonicalize & check

### apk
case "$_apk" in
*/*) _apk="$(realpath "$_apk")"
esac
### check arch
[ "$("$_apk" --print-arch)" = "x86_64" ] || error "unsupported arch or bad apk"
### key dir
[ -d "$_key_dir" ] || error "invalid pubkey dir"
### cache dir
[ -d "$_cache_dir" ] || error "invalid cache dir"
### repos are mixed, expanded, and checked in prepare stage later
### build_dir is canonicalized in prepare stage later
### use_tmpfs
case "$_use_tmpfs" in
none|rootfs|all);;
*) error "invalid use_tmpfs option";;
esac
### tmpfs_size
echo "$_tmpfs_size" | grep -qxE "[0-9]+[kKmMgG%]" || error "invalid tmpfs_size"
### out_file
[ "$_out_file" ] || error "must specify output file"
### packages, checked in prepare stage later
_packages="$(echo "$_packages" | tr "\n" " ")"
### cmdline, checked in prepare stage later
_cmdline="$(echo "$_cmdline" | tr "\n" " ")"
### cust
[ -f "$_cust_repos" ] || error "invalid cust_repos"
[ -d "$_cust_pkgs" ] || error "invalid cust_pkgs"
[ -f "$_cust_cmdline" ] || error "invalid cust_cmdline"
[ -d "$_cust_dir" ] || error "invalid cust_dir"
[ -f "$_cust_script" ] || error "invalid cust_script"
#echo "$_project_name" | grep -qxE "s"+ || error "invalid project_name"
#################### prepare
stage prepare

### read cust repos, pkgs and cmdline
_repos="$(<"$_cust_repos" tr "\n" " ") $_repos"
for i in $_repos
do	case "$i" in
	http*);;
	*) [ -f "$i/x86_64/APKINDEX.tar.gz" ] || error "unavailable local repository '$i'"
	esac
	repo_args="$repo_args -X $i"
done
[ "$repo_args" ] || error "no available repos"
_packages="$(cat "$_cust_pkgs"/*.list | grep -v "^#" | tr "\n" " ") $_packages"
[ "$_packages" != " " ] || error "no packages to install"
_cmdline="$(<"$_cust_cmdline" tr "\n" " ") $_cmdline"
### cache dir
mkdir -p "$_cache_dir/x86_64"
[ ! -e "$_build_dir" ] || error "build dir '$_build_dir' already exists"
### build dirs
mkdir -p "$_build_dir"
_build_dir="$(realpath "$_build_dir")"
def_build_dirs
mkdir "$host_dir" "$rootfs_dir" "$image_dir"
### create live_dir after tmpfs mount later
### mount tmpfs
case "$_use_tmpfs" in
rootfs) mount_tmp "$rootfs_dir";;
all) mount_tmp "$host_dir" "$rootfs_dir" "$image_dir"
esac
mkdir "$live_dir"
#################### start build
stage start_build

##### copy keys

for i in "$host_dir/etc/apk/keys" "$rootfs_dir/etc/apk/keys"
do	mkdir -p "$i"
	cp -t "$i" "$_key_dir"/*.pub
done

##### install packages

### host
run_apk_at host --initdb add $core_packages || \
 error "failed to install host core"
mount_pseudo_at host
run_apk_at host add $host_packages || \
 error "failed to install host packages"
### rootfs
run_apk_at rootfs --initdb add $core_packages || \
 error "failed to install rootfs core"
mount_pseudo_at rootfs
run_apk_at rootfs add $_packages || \
 error "failed to install rootfs packages"

##### cust dir and script

[ -z "$_cust_script" ] || \
{
	[ -z "$_cust_dir" ] || \
	{
		mkdir "$rootfs_dir/cust"
		mount -rB "$_cust_dir" "$rootfs_dir/cust"
	}

	cp "$_cust_script" "$rootfs_dir/customize.sh"
	chmod +x "$rootfs_dir/customize.sh"
	chroot "$rootfs_dir" /customize.sh
	rm "$rootfs_dir/customize.sh"

	[ -z "$_cust_dir" ] || \
	{
		umount -lf "$rootfs_dir/cust"
		rmdir "$rootfs_dir/cust"
	}
}

#################### packaging
stage packaging

##### copy kernel & detect initramfs-tools

### kernel
found_kernel=0
for i in "$rootfs_dir/boot"/vmlinu[xz]-*
do	[ -f "$i" ] || error "detect_kernel: '$i' is not a file"
	kernel_file="$i"
	kernel_ver="${kernel_file##*/}"
	kernel_type="${kernel_ver%%-*}"
	kernel_ver="${kernel_ver#*-}"
	found_kernel=1
	break
done
[ "$found_kernel" = 1 ] || error "detect_kernel: kernel not found"
cp -T "$kernel_file" "$live_dir/$kernel_type"
### initramfs-tools
[ -x "$rootfs_dir/usr/bin/mkinitramfs" ] || \
 error "rootfs does not contain initramfs-tools"

##### generate filesystem

### cleanup useless initrd
rm -f "$rootfs_dir/boot"/initrd*
mount -B "$_build_dir" "$host_dir/mnt"
### bind mount
case "$_use_tmpfs" in
rootfs) mount -B "$rootfs_dir" "$host_dir$rootfs_dir_in_host";;
all)	mount -B "$rootfs_dir" "$host_dir$rootfs_dir_in_host"
	mount -B "$image_dir" "$host_dir$image_dir_in_host";;
esac
### make erofs
host_run mkfs.erofs -b 4096 -z lzma -E ztailpacking \
 "$live_dir_in_host/filesystem.erofs" "$rootfs_dir_in_host"

##### generate initrd

### copy initramfs files
cp -R "$dir/initramfs-tools/lib/live" "$rootfs_dir/usr/lib/"
cp "$dir/initramfs-tools/bin"/* "$rootfs_dir/usr/bin/"
for i in hooks scripts
do	cp -R "$dir/initramfs-tools/$i"/* \
	 "$rootfs_dir/usr/share/initramfs-tools/$i/"
done
cp -R "$dir/data" "$rootfs_dir/usr/lib/live/"
### generate initramfs
mkdir "$rootfs_dir/live"
mount -B "$live_dir" "$rootfs_dir/live"
chroot "$rootfs_dir" mkinitramfs -o /live/initrd "$kernel_ver"
umount -lf "$rootfs_dir/live"
rmdir "$rootfs_dir/live"

##### cleanup

### remove core
run_apk_at rootfs del $core_packages
### cleanup temp dirs
for i in run tmp root var/cache var/log /var/tmp
do	rm -r "$rootfs_dir/$i"
	mkdir "$rootfs_dir/$i"
done
chmod 777 "$rootfs_dir/tmp" "$rootfs_dir"/var/tmp
chmod 750 "$rootfs_dir/root"
### cleanup backup userdbs
for i in passwd group shadow gshadow subuid subgid
do	rm -f "$rootfs_dir/etc/$i-"
done

##### generate efi
generate_menu()
{
	sed \
	 -e "s|@@BOOT_TITLE@@|$_project_name|g" \
	 -e "s|@@KERNFILE@@|$kernel_type|g" \
	 -e "s|@@KERNVER@@|$kernel_ver|g" \
	 -e "s|@@ARCH@@|x86_64|g" \
	 -e "s|@@BOOT_CMDLINE@@|$_cmdline|g" \
	 "$1"
}

mkdir -p "$image_dir/EFI/BOOT"
generate_menu "$dir/limine/limine.conf.in" >"$image_dir/limine.conf"

for i in IA32 X64
do cp "$host_dir/usr/share/limine/BOOT$i.EFI" "$image_dir/EFI/BOOT/"
done

### eltorito
truncate -s 2949120 "$image_dir/efi.img"
host_run mkfs.vfat -F 12 -S 512 "$image_dir_in_host/efi.img"
LC_CTYPE=C host_run mmd -i "$image_dir_in_host/efi.img" EFI EFI/BOOT
for i in "$image_dir/EFI/BOOT"/*
do	LC_CTYPE=C host_run mcopy -i "$image_dir_in_host/efi.img" \
	 "$image_dir_in_host/EFI/BOOT/$(basename "$i")" "::EFI/BOOT/"
done

### generate
cp "$host_dir/usr/share/limine/limine-bios-cd.bin" \
 "$host_dir/usr/share/limine/limine-bios.sys" "$image_dir/"

host_run xorriso -as mkisofs -iso-level 3 -rock -joliet -max-iso9660-filenames \
 -omit-period -omit-version-number -relaxed-filenames -allow-lowercase \
 -volid CHIMERA_LIVE -eltorito-boot limine-bios-cd.bin -no-emul-boot \
 -boot-load-size 4 -boot-info-table -hfsplus -apm-block-size 2048 \
 -eltorito-alt-boot -e efi.img -efi-boot-part \
 --efi-boot-image --protective-msdos-label --mbr-force-bootable \
 -o /mnt/image.iso /mnt/image
host_run limine bios-install /mnt/image.iso

mv "$_build_dir/image.iso" "$_out_file"
