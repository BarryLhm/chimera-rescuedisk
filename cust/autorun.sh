#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/scripts/common"

for i in "$SCRIPTS_DIR"/*.sh
do "$i"
done
