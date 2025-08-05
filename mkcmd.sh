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

PROG="$(basename "$0")"

help()
{
	cat <<-EOF
	usage: <key=value ...> core.sh

	keys: (* mandatory, = default/options)
	### runtime
	- apk       = apk       apk binary
	- key_dir   = keys      apk repo pubkey dir
	- cache_dir = apk-cache apk cache dir
	* repos                 apk repositories separated by space
	- build_dir = build     temp dir for building
	- use_tmpfs             use tmpfs to accelerate build
	            = root          for rootfs directory
	            = full          for host, rootfs and image directory
	### io
	* out_file              output image file
	* packages              package list separated by space
	- cmdline               extra kernel cmdline
	### cust
	- cust_dir
	- cust_script

	read manual and code to get detailed info
	EOF
	exit "${1-1}"
}

error()
{
	echo "$PROG: $1" >&2
	return "${2-1}"
}

var_init()
{
	local _value="$1" _error=0 _error2=0 _emptykeys= _key _badkeys _badkeys2; shift
	[ "$#" != 0 ] || error "var_init: empty input"
	for _key in "$@"
	do [ "$_key" ] || _emptykeys="$_emptykeys ''"
	done
	set -o pipefail
	_badkeys="$(printf "%s\0" "$@" | grep -Evxz '[a-zA-Z0-9][a-zA-Z0-9_]*' | \
	 xargs -0 printf " '%s'")" && _error=1 || :
	_badkeys2="$(printf "%s\0" "$@" | grep -Exz '[0-9]+' | \
	 xargs -0 printf " '%s'" )" && _error2=1 || :
	set +o pipefail
	[ "$_error" = 0 ] && [ "$_error2" = 0 ] || local _msg="var_init: invalid key:"
	case "$_error/$_error2" in
	1/0) error "$_msg$_emptykeys$_badkeys";;
	0/1) error "$_msg$_emptykeys$_badkeys2";;
	1/1) error "$_msg$_emptykeys$_badkeys$_badkeys2";;
	esac
	for key in "$@"
	do [ "$(eval echo '"${'"$key"'-}"')" ] || eval "$key='$value'"
	done
}

##### options processing

### defaults
var_init apk apk
var_init keys key_dir
var_init apk-cache cache_dir
var_init build build_dir

### avoid unset vars
var_init '' repos use_tmpfs out_file packages cmdline cust_dir cust_script

### check options
#


## Main
#help

#[ "$1" = "second_stage" ] ||
