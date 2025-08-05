#!/bin/sh -eu
#
# mkcmd.sh
# Chimera Maintenance Disk image creation tool
#
# Copyright 2025 BarryLhm <BarryLhm@outlook.com>
#
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

def_build_dirs()
{
	host_dir="$_build_dir/host"
	rootfs_dir="$_build_dir/rootfs"
	image_dir="$_build_dir/image"
	live_dir="$image_dir/live"
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

stage()([ "$#" = 0 ] || stage="$1"; msg "current stage: $stage")

var_init()
{
	local value="$1" error=0 key badkeys=; shift
	[ "$#" != 0 ] || error "var_init: empty input"
	for key in "$@"
	do [ "$key" ] || badkeys="$badkeys ''"
	done
	set -o pipefail
	badkeys="$badkeys$(printf "%s\0" "$@" | grep -Evxz "_[a-zA-Z0-9_]+" | \
	 xargs -0 printf " '%s'")" && error=1 || :
	set +o pipefail
	[ "$error" = 0 ] || error "var_init: invalid key:$badkeys"
	for key in "$@"
	do [ "$(eval echo '"${'"$key"'-}"')" ] || \
	 eval "$key='$(echo "$value" | sed "s/'/'\\\''/g")'"
	done
}

mount_tmp()
{
	local target
	for target in "$@"
	do mount -t tmpfs -o noatime,size="$_tmpfs_size" mkcmd "$target"
	done
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
		exec unshare -- "$0" second_stage
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
var_init "$dir/pkgs.d" _cust_packages
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
### repos
for repo in $_repos
do	case "$repo" in
	http*);;
	*) [ -f "${f}/${APK_ARCH}/APKINDEX.tar.gz" ] || die "unavailable local repository $f"
	esac
	repo_args="$repo_args -X $repo"
done
### build_dir is canonicalized in prepare stage below
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
[ -d "$_cust_pkgs" ] || error "invalid cust_pkgs"
[ -f "$_cust_cmdline" ] || error "invalid cust_cmdline"
[ -d "$_cust_dir" ] || error "invalid cust_dir"
[ -f "$_cust_script" ] || error "invalid cust_script"

#################### prepare
stage prepare

### cache dir
mkdir -p "$_cache_dir/$_arch"
[ ! -e "$BUILD_DIR" ] || error "build dir '$BUILD_DIR' already exists"
### build dirs
mkdir -p "$_build_dir"
"$_build_dir"="$(realpath "$_build_dir")"
def_build_dirs
mkdir "$host_dir" "$rootfs_dir" "$image_dir"
#create live_dir after tmpfs mount below
### mount tmpfs
case "$_use_tmpfs" in
rootfs) mount_tmp "$rootfs_dir";;
full) mount_tmp "$host_dir" "$rootfs_dir" "$image_dir"
esac
mkdir "$live_dir"

#################### start build
stage start_build
