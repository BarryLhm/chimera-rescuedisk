# Chimera Maintenance Disk
A maintenance disk & its build system based on Chimera Linux & chimera-live

### Files
`chimera-live/`: original implements & references & dependency
`cust/`: files to be executed / copied during customization
`pkgs.d/`: contains custom package lists
`customize.sh`: script to be executed during customization
`mklive.sh`: low-level build script, hard-forked from `chimera-live/mklive.sh`
`build.sh`: auto build script
`format-check.sh`: check formats of `pkgs.d/*.list`
`format-fix.sh`: fix formats of `pkgs.d/*.list`

### Usage
- To build:
`doas ./build.sh`
Recommended options:
   `-t 50%`   create a tmpfs using 50% of memory to speed up building (only for temp rootfs dir)
   `-T 70%`   same as above, but using 70%, for the whole temp build dir (need huge memory)
   `-I fish`  manual customization during build using fish shell

For other options, please refer to `mklive.sh` and `build.sh`
   (options will be passed to mklive.sh as extra options)

- To test:
`./test.sh` (options will be passed to qemu as extra options)

### Customization:
- Recommended: `pkgs.d/xx_apps.list` `pkgs.d/xx_tools.list` `pkgs.d/xx_super-utilities.list`
- Advanced: `cmdline` `customize.sh` `cust/scripts/*.sh` `cust/root/...`
- Core: `build.sh` `mklive.sh`

### Technical Information:
- Building procedure:
(Path with a leading - means it's relative to target root)
(entry with a * means it's what's different to chimera-live)
```
-*-build.sh
    |-*-generate packages list from pkgs.d/*
    \---mklive.sh
         |---install packages
         |-*-bind cust/ to -/cust
         |-*-copy customize.sh to -/customize.sh and executes it
         |-*-unmount and rmdir -/cust
         |---generate erofs image from temp rootfs
         |---copy kernel & generate initramfs with live specific files from chimera-live/initramfs-tools
         \---generate final iso file
```

### CREDITS & LICENSES
- chimera-live: Chimera Linux developers, BSD-2-Clause
- mklive.sh: Chimera Linux developers, BarryLhm, BSD-2-Clause
- chimera-live/initramfs-tools: Debian developers, GPL-3.0-or-later
- \* (others except symlinks): BarryLhm, GPL-3.0-or-later
