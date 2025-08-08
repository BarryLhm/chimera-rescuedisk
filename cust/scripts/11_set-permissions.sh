#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

cd /
###### permissions following...
chmod +x /usr/local/cmd/*.sh
chmod +x /etc/rc.local
chmod 000 /usr/local/cmd/home/.config/user-dirs.*
