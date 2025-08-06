# Chimera Maintenance Disk
A maintenance disk & its build system based on Chimera Linux & chimera-live

### Files
`chimera-live/`: original implements & references & dependency

`repositories`: apk repositories used during installation

`keys/`: apk trusted pubkeys

`pkgs.d/`: contains custom package lists

`cmdline`: extra kernel cmdline

`cust/`: files to be used during customization

`customize.sh`: script to be executed during customization

`mkcmd.sh`: low-level build script, rewrited from `chimera-live/mklive.sh`

`build.sh`: auto build script

`format-check.sh`: check formats of `pkgs.d/*.list`

`format-fix.sh`: fix formats of `pkgs.d/*.list`

### Usage
- To build:
[#|doas|sudo|...] `./build.sh`
options are passed through environtment variables to `mkcmd.sh`

- To test:
`./test.sh` (uefi boot)

### Customization:
- Simple: `pkgs.d/xx_apps.list` `pkgs.d/xx_tools.list` `pkgs.d/xx_super-utilities.list`
- Advanced: `cmdline` `customize.sh` `cust/scripts/*.sh` `cust/root/...`
- Core: `build.sh` `mkcmd.sh` `repositories` `keys/`

### Technical Information:
- Building procedure:
(Path with a leading - means it's relative to target rootfs)
```
build.sh
    \--mkcmd.sh
        |--read custom dirs (get package lists, repos, cmdline...)
        |--install packages
        |--bind cust/ to -/cust
        |--copy customize.sh to -/customize.sh and executes it
        |--unmount and rmdir -/cust
        |--copy kernel and detect initramfs-tools
        |--generate erofs image from temp rootfs
        |--copy live secific files from initramfs-tools/
        |--generate initramfs
        |--generate bootloader and boot config
	\--generate final iso file
```

### CREDITS & LICENSES
- `chimera-live`: Chimera Linux developers, BSD-2-Clause
- `chimera-live/initramfs-tools/`: Debian developers, GPL-3.0-or-later
- `*` (others except symlinks): BarryLhm, GPL-3.0-or-later
