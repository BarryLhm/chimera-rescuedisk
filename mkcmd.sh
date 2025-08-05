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
host_packages="xorriso mtools dosfstools"
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
	- arch         = <local>   image arch (must be supported by local machine)
	- key_dir      = ./keys    apk pubkey dir
	- cache_dir    = ./cache   apk cache dir
	* repos                    apk repositories separated by space
	- build_dir    = ./build   temp dir for building
	- use_tmpfs    = none      use tmpfs to accelerate build
	               = rootfs        for rootfs directory
	               = full          for host, rootfs and image directory
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
	local value="$1" error=0 badkeys= i; shift
	[ "$#" != 0 ] || error "var_init: empty input"
	for i in "$@"
	do [ "$i" ] || badkeys="$badkeys ''"
	done
	set -o pipefail
	badkeys="$badkeys$(printf "%s\0" "$@" | grep -Evxz "_[a-zA-Z0-9_]+" | \
	 xargs -0 printf " '%s'")" && error=1 || :
	set +o pipefail
	[ "$error" = 0 ] || error "var_init: invalid key:$badkeys"
	for i in "$@"
	do [ "$(eval echo '"${'"$i"'-}"')" ] || \
	 eval "$i='$(echo "$value" | sed "s/'/'\\\''/g")'"
	done
}

mount_tmp()
{
	local target
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
	"$_apk" --no-interactive --arch "$_arch" --cache-packages \
	 --cache-dir "$_cache_dir/$_arch" $repo_args -p "$root" "$@"
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
}


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
		exec unshare -- sh -"$-" "$0" second_stage
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

### avoid unset vars
var_init '' _arch _repos _out_file _packages _cmdline

####### canonicalize & check

### apk
case "$_apk" in
*/*) _apk="$(realpath "$_apk")"
esac
### arch
[ "$_arch" ] || _arch="$("$_apk" --print-arch)"
[ -d "$_key_dir" ] || error "invalid pubkey dir"
[ -d "$_cache_dir" ] || error "invalid cache dir"
[ "$_repos" ] || error "must specify repos"
### repos are expanded in prepare stage later
### build_dir is canonicalized in prepare stage later
### use_tmpfs
case "$_use_tmpfs" in
none|rootfs|full);;
*) error "invalid use_tmpfs option";;
esac
### tmpfs_size
echo "$_tmpfs_size" | grep -qxE "[0-9]+[kKmMgG%]" || error "invalid tmpfs_size"
### out_file
[ "$_out_file" ] || error "must specify output file"
### packages
_packages="$(echo "$_packages" | tr "\n" " ")"
### cmdline
_cmdline="$(echo "$_cmdline" | tr "\n" " ")"
### cust
[ -f "$_cust_repos" ] || error "invalid cust_repos"
[ -d "$_cust_pkgs" ] || error "invalid cust_pkgs"
[ -f "$_cust_cmdline" ] || error "invalid cust_cmdline"
[ -d "$_cust_dir" ] || error "invalid cust_dir"
[ -f "$_cust_script" ] || error "invalid cust_script"

#################### prepare
stage prepare

### read cust repos, pkgs and cmdline
_repos="$(cat "$_cust_repos" | tr "\n" " ") $repos"
for i in $_repos
do	case "$i" in
	http*);;
	*) [ -f "$i/$_arch/APKINDEX.tar.gz" ] || error "unavailable local repository '$i'"
	esac
	repo_args="$repo_args -X $i"
done
_packages="$(cat "$_cust_pkgs"/*.list | grep -v "^#" | tr "\n" " ") $_packages"
_cmdline="$(cat "$_cust_cmdline" | tr "\n" " ") $_cmdline"
### cache dir
mkdir -p "$_cache_dir/$_arch"
[ ! -e "$BUILD_DIR" ] || error "build dir '$BUILD_DIR' already exists"
### build dirs
mkdir -p "$_build_dir"
"$_build_dir"="$(realpath "$_build_dir")"
def_build_dirs
mkdir "$host_dir" "$rootfs_dir" "$image_dir"
#create live_dir after tmpfs mount later
### mount tmpfs
case "$_use_tmpfs" in
rootfs) mount_tmp "$rootfs_dir";;
full) mount_tmp "$host_dir" "$rootfs_dir" "$image_dir"
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
run_apk_at host --initdb add $core_package || \
 error "failed to install host core"
mount_pseudo_at host
run_apk_at host add $host_packages || \
 error "failed to install host packages"
### rootfs
run_apk_at rootfs --initdb add $core_package || \
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

	cp "$cust_script" "$rootfs_dir/customize.sh"
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

##### kernel
for i in "$rootfs_dir/boot"/vmlinuz-*
do	[ -f "$i" ] || error "detect_kernel: '$i' is not a file"
	kernel_file="$i"
	kernel_ver="${kernel_file##*boot/}"
	kernel_ver="${kernel_ver#*-}"
	kernel_type="$i"
	break
done
[ -f "$kernel_file" ] || error "kernel not found"

cp -T "$kernel_file" "$live_dir"/"$kernel_type"
## is this really needed?

##### initramfs

### copy initramfs tools
[ -x "$rootfs_dir/usr/bin/mkinitramfs" ] || \
 die "rootfs does not contain initramfs-tools"
cp -R "$dir/initramfs-tools/lib/live" "$rootfs_dir/usr/lib/"
mv "$rootfs_dir/usr/local/bin" "$rootfs_dir/usr/local/bin.bak"
mkdir "$rootfs_dir/usr/local/bin"
##################################################### testing for local!!!
cp "$dir/initramfs-tools/bin"/* "$rootfs_dir/usr/local/bin/"
for i in hooks scripts
do	mkdir -p "$rootfs_dir/usr/local/share/initramfs-tools/$i"
	cp -R "$dir/initramfs-tools/$i"/* \
	 "$rootfs_dir/usr/local/share/initramfs-tools/$i/"

done
cp -R "$dir/data" "$rootfs_dir/lib/live"
### generate initramfs
mkdir "$rootfs_dir/live"
mount -B "$live_dir" "$rootfs_dir/live"
chroot "$rootfs_dir" mkinitramfs -o /live/initrd "$kernel_ver"
umount -lf "$rootfs_dir/live"
rmdir "$rootfs_dir/live"
### cleanup initramfs tools
rm -r "$rootfs_dir/usr/local/lib/live"
rm -r "$rootfs_dir/usr/local/bin"
mv "$rootfs_dir/usr/local/bin.bak" "$rootfs_dir/usr/local/bin"
rm -r "$rootfs_dir/usr/local/share/initramfs-tools"
### cleanup initrd
rm -f "$rootfs_dir/boot"/initrd*

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

##### generate erofs

mount "$_build_dir" "$host_dir/mnt"
case $_use_tmpfs in
half) mount --bind "$rootfs_dir" "rootfs_dir_in_host";;
full)	mount --bind "$rootfs_dir" "rootfs_dir_in_host"
	mount --bind "$image_dir" "$image_dir_in_host";;
esac

chroot "$host_dir" /usr/bin/mkfs.erofs -b 4096 -z lzma -E ztailpacking \
 "$live_dir_in_host/filesystem.erofs" "$rootfs_dir_in_host"

##### generate efi
generate_menu()
{
	sed \
	 -e "s|@@BOOT_TITLE@@|Chimera Maintenance Disk|g" \
	 -e "s|@@KERNFILE@@|vmlinuz|g" \
	 -e "s|@@KERNVER@@|$kernel_ver|g" \
	 -e "s|@@ARCH@@|$APK_ARCH|g" \
	 -e "s|@@BOOT_CMDLINE@@|$CMDLINE|g" \
	 "$1"
}

mkdir -p "$image_dir/boot/grub" "$image_dir/EFI/BOOT"
generate_menu "$dir/grub/menu.cfg.in" > "$image_dir/boot/grub/grub.cfg"
generate_menu "$dir/limine/limine.conf.in" > "$image_dir/limine.conf"
copy_bootefi()(cp "$host_dir/usr/share/limine/BOOT$1.EFI" "$image_dir/EFI/BOOT/")
case "$_arch" in
x86_64) copy_bootefi IA32; copy_bootefi X64;;
aarch64) copy_bootefi AA64;;
riscv64) copy_bootefi RISCV64;;
loongarch64) copy_bootefi LOONGARCH64;;
*) error "Unknown architecture '$_arch' for EFI";;
esac











