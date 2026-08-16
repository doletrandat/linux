# SPDX-License-Identifier: GPL-2.0
# Lumia 730 Superman bring-up

This branch carries the experimental Nokia Lumia 730 (RM-1040, codename
`superman`) device-tree and configuration work on top of Linux `v6.16-rc4`.
It is not a claim of hardware support. The first planned test uses a legacy
Android image and a removable microSD; no eMMC or EFIESP change belongs in
this repository.

## Source delta

- `arch/arm/boot/dts/qcom/qcom-msm8226-nokia-superman.dts` describes the
  Lumia 730 board and its device-specific I2C peripherals.
- `arch/arm/boot/dts/qcom/Makefile` adds the Superman DTB to the ARM QCOM
  build list.
- `arch/arm/configs/lumia_superman_defconfig` records the exact bring-up
  configuration used for the currently built kernel.

The defconfig is intentionally captured before hardware validation. It is a
full expanded configuration snapshot and should be reduced with the kernel's
normal `savedefconfig` workflow before proposing upstream-quality changes.

## Build inputs

The Android device repository consumes:

```text
arch/arm/boot/zImage
arch/arm/boot/dts/qcom/qcom-msm8226-nokia-superman.dtb
```

It appends the DTB to the zImage for the legacy LK image contract. Generated
`zImage`, DTB, modules, and boot images are deliberately not committed here.

## Known limitations

Binder IPC is disabled in the current configuration, and early display support
is not available in the recovery ramdisk. USB FunctionFS support is enabled,
but UDC registration and enumeration remain unverified on real hardware.
