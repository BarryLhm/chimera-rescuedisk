#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common.sh"

errors=0
report()(errors=1; for i in "$@"; do echo "$i"; done)

for i in pkgs.d/*.list
do	sort -C "$i" || report "[Error] $i is unsorted"
	duplines="$(cat "$i" | sort | uniq -d)"
	[ -z "$duplines" ] || report "[Error] $i contains duplicated lines:" "$duplines"
done

duplines="$(cat pkgs.d/*.list | sort | uniq -d)"
[ -z "$duplines" ] || report "[Warning] lists contain duplicated lines:" "$duplines"

exit "$errors"
