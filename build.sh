#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common.sh"

[ "$(id -u)" = 0 ] || error "Need root permission"

[ ! -d build ] || rm -r build

export _out_file="$out_image" _use_tmpfs=all _tmpfs_size=4G
exec ./mkcmd.sh first_stage
