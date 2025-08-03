#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common.sh"

[ "$(id -u)" = 0 ] || error "Need root permission"

[ ! -d build ] || rm -r build

baseurl="https://repo.chimera-linux.org/current"

repo_m="$baseurl/main"
repo_u="$baseurl/user"
repo_md="$baseurl/main/debug"
repo_ud="$baseurl/user/debug"

arg_repos="-r $repo_m -r $repo_u -r $repo_md -r $repo_ud"

exec ./mklive.sh "$@" -o "$out_image" -D cust -S customize.sh -c "$(cat cmdline | tr "\n" " ")" \
 $arg_repos -p "$(cat pkgs.d/*.list | grep -v "^#" | tr "\n" " ")"
