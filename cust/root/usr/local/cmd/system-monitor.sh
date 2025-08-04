#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

trap "" INT

ask_oper()
{
	setcolor yellow
	echo "What would you like to do?"
	setcolor reset
	echo "(0) Run 'htop' as root"
	echo "(<cmd>) Run <cmd> as root (with '$LIVE_SHELL')"
	local answer="$(ask 0 "[0] ")"
	echo
	set +e
	case "$answer" in
	0) htop;;
	*)	"$LIVE_SHELL" -c "$answer" || \
		{
		local ret="$?"
		echo
		setcolor yellow
		echo "Command '$answer' returned $ret"
		setcolor reset
		};;
	esac
	set -e
	echo

}

setcolor yellow
setcolor reset
echo
echo "Welcome to Chimera Maintenance Disk system monitor!"
echo
echo "---------------------------------------------"

while :
do ask_oper
done
