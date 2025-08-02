#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common"

enable()
{
	for i in "$@"
	do dinitctl -o enable "$(basename "$i")"
	done
}

###### services following...
