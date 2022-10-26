#!/bin/bash

# SPDX-License-Identifier: MIT

set -x
set -e

unset LC_CTYPE
unset LANG

build_linux()
{
(
        test -d linux || git clone https://github.com/AsahiLinux/linux
        cd linux
        git fetch -a -t
        git reset --hard origin/asahi-wip;
        curl -sL https://tg.st/u/78cf358c267e7df34d6428d2ee621cf83d9a06b2c5b1e798562730e196cd3754.config > .config
        make olddefconfig
        make -j `nproc` V=0 > /dev/null
        sudo make modules_install
        sudo make install
)
}

build_m1n1()
{
(
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1
        cd m1n1
        git fetch -a -t
        git reset --hard origin/lina/gpu-wip;
        make -j `nproc`
)
}

build_uboot()
{
(
        test -d u-boot || git clone https://github.com/AsahiLinux/u-boot
        cd u-boot
        git fetch -a -t
        # For tag, see https://github.com/AsahiLinux/PKGBUILDs/blob/main/uboot-asahi/PKGBUILD
        git reset --hard origin/asahi;
        curl -s https://tg.st/u/0001-usb-request-on-8-bytes-for-USB_SPEED_FULL-bMaxPacket.patch | git am -
        make apple_m1_defconfig
        make -j `nproc`
)

        cat m1n1/build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.bin
        sudo cp /boot/efi/m1n1/boot.bin /boot/efi/m1n1/`date +%Y%m%d%H%M`.bin
        sudo cp u-boot.bin /boot/efi/m1n1/boot.bin

}

mkdir -p build
cd build

echo 'On my last try it booted, but the following things did not work: usb-a, usb-c, network, shutdown or reboot'
exit 1;

build_linux
build_m1n1
build_uboot