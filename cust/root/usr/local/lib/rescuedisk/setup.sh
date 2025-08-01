#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

[ "$CHANGE_SHELL" != 1 ] || \
{
	usermod -s "$LIVE_SHELL" "root"
	### user shell is already set by initramfs
}

add_user_alias "$LIVE_USER" "$LIVE_USER-graphical"
usermod -s "$PROG_DIR/graphical-session.sh" "$LIVE_USER-graphical"
