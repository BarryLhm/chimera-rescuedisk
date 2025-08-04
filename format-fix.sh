#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common.sh"

cat pkgs.d/*.list | sort | uniq -d >> "$duplist"
[ "$(cat "$duplist")" ] && echo "[Info] lists contains duplicated lines:" && cat "$duplist" || :

for i in pkgs.d/*.list
do	sort -u "$i" | grep -vxFf "$duplist" | awk NF > "$i.tmp"
	mv "$i.tmp" "$i"
done

cat "$duplist" >> "$uncatlist"
rm "$duplist"
sort -uo "$uncatlist" "$uncatlist"
[ "$(cat "$uncatlist")" ] || rm "$uncatlist"
