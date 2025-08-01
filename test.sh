#!/bin/sh -eu

. "$(dirname "$(realpath "$0")")/common.sh"

qemu-system-x86_64 -smp cpus=4 -accel kvm -m 4096 \
 ## uefi
 -drive if=pflash,format=raw,readonly=on,file=/usr/share/qemu/edk2-x86_64-code.fd \
 ## image
 -cdrom "$OUT_IMAGE"
