#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

#ask_exit()
#{
#	echo "Do you really want to exit? (I'll be respawned)"
#	case "(ask N "[N] " y Y n N)" in
#	y|Y) exit;;
#	n|N) return;;
#	esac
#}

trap "" INT

ask_lang()
{
	setcolor yellow
	echo "Please choose language:"
	setcolor reset
	echo "(/) Don't set language"
	echo "(l) Language list"
	echo "(<locale name>) Set language to <locale name>"
	while :
	do	answer="$(ask "zh_CN.UTF-8" "[zh_CN.UTF-8 ] " / l $(ls "$LOCALE_DIR") )"
		case "$answer" in
		/) break;;
		l) ls -C "$LOCALE_DIR" | less -P s"Press arrow keys to scroll, 'q' to return";;
 		*) echo "LANG=$answer" > "$LOCALE_CONF"; echo "Language set to $answer"; break;;
		esac
	done
}

ask_oper()
{
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

}

setcolor yellow
setcolor reset
echo
echo "Welcome to Chimera Rescue Disk startup menu!"
echo
ask_lang
echo
setcolor yellow
echo "///NOTE/// Login prompts available on tty5-8}"
setcolor reset
echo "---------------------------------------------"

while :
do ask_oper
done
