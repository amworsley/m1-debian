#!/usr/bin/env bash

# SPDX-License-Identifier: MIT

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

cd "$(dirname "$0")"

unset LC_CTYPE
unset LANG

build_linux()
{
(
        test -d linux || git clone https://github.com/AsahiLinux/linux
        cd linux
        git fetch -a -t
        git reset --hard origin/asahi-wip;
        curl -sL https://tg.st/u/e633ae8c7e2f16d7bc845a0695e583a836d94846e1c33da182216e565c3769c4.config > .config
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

build_linux
build_m1n1
build_uboot
