#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

##### Warning: GNU Coreutils non-compatibility

detect_cp_provider()
{
	cp --version >/dev/null 2>&1 && echo "gnu" && return || :
	cp --help >/dev/null 2>&1 && echo "busybox" && return || :
	echo "bsd"
}

[ "$(detect_cp_provider)" != "bsd" ] && echo "need BSD cp utility" && exit 1 || :

cp -R "$ROOT_DIR/" "/"
