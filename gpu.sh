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
        source "$HOME/.cargo/env"
        curl -sL https://tg.st/u/3007a82fe2f3ef7d91945e1cb3e5a167f8d6b0550ecb67850d1cd85f3efa112e.config > .config
        make LLVM=-14 olddefconfig
        make LLVM=-14 -j `nproc` V=0 > /dev/null
        sudo make LLVM=-14 modules_install
        sudo make LLVM=-14 install
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
