#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

while true
do	setcolor yellow
	setcolor reset
	echo
	echo "Welcome to Chimera Rescue Disk startup menu!"
	echo
	setcolor yellow
	echo "///NOTE/// Login prompts available on tty5-8}"
	setcolor reset
	echo "---------------------------------------------"
	setcolor yellow
	echo "What would you like to do?"
	setcolor reset
	echo "(0) Login as root (shell: $LIVE_SHELL)"
	echo "(1) Login as $LIVE_USER (shell: $LIVE_SHELL)"
	echo "(2) startxfce4 (as '$LIVE_USER')"
	echo "(r) reboot"

	set +e
	case "$(ask 0 "[0] " 0 1 2 r)" in
	0) login -f root;;
	1) login -f "$LIVE_USER";;
	2) login -f "$LIVE_USER-graphical";;
	r) reboot;;
	esac
	set -e
done
