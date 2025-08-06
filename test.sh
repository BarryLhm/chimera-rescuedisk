#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common.sh"

exec qemu-system-x86_64 -smp cpus=4 -accel kvm -m 4096 -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/edk2-x86_64-code.fd -cdrom "$out_image"
