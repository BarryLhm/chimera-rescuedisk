#!/bin/sh ## not executable, just for syntax highlighting

script="$(realpath "$0")"
dir="$(dirname "$script")"
prog="$(basename "$0")"
realprog="$(basename "$script")"

duplist=pkgs.d/dup.txt
uncatlist=pkgs.d/Z114514_uncategorized.list
out_image=cmd.iso

error()
{
	echo "$prog: $1" >&2; return "${2-1}"
}

[ "$(realpath "$0")" = "$(realpath -q "$prog")" ] || error "Please run under repo root dir"

[ "$(realpath "$0")" = "$(realpath -q "$(basename "$0")" || :)" ] || error "Please run under repo root dir"
