#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

USER="${USER%-graphical}"
LOGNAME="$USER"
MAIL="${MAIL%-graphical}"

unset SHELL
exec  "$GRAPHICAL_SESSION"
