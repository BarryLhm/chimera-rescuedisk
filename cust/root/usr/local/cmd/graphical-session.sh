#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

export USER="${USER%-graphical}"
export LOGNAME="$USER"
export MAIL="${MAIL%-graphical}"
[ ! -f "$LOCALE_CONF" ] || . "$LOCALE_CONF"
unset SHELL

. "$CMD_DIR/graphical-env"

exec  "$GRAPHICAL_SESSION"
