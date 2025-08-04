#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

. "$CMD_DIR/graphical-env"

export USER="${USER%-graphical}"
export LOGNAME="$USER"
export MAIL="${MAIL%-graphical}"

unset SHELL
exec  "$GRAPHICAL_SESSION"
