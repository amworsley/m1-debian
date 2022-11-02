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
        git reset --hard asahi-6.1-rc3-1;
        curl -sL https://tg.st/u/3007a82fe2f3ef7d91945e1cb3e5a167f8d6b0550ecb67850d1cd85f3efa112e.config | grep -v CONFIG_DRM_APPLE | grep -v CONFIG_DRM_ASAHI > .config
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
        git reset --hard v1.1.7;
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
        curl -s https://tg.st/u/0001-usb_setup_descriptor-Add-1ms-delay-in-order-to-unbre.patch | patch -p1
        make apple_m1_defconfig
        make -j `nproc`
)
        cat m1n1/build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.bin
        echo display=3840x2160 >> u-boot.bin
        sudo cp /boot/efi/m1n1/boot.bin /boot/efi/m1n1/`date +%Y%m%d%H%M`.bin
        sudo cp u-boot.bin /boot/efi/m1n1/boot.bin
}

mkdir -p build
cd build

build_linux
build_m1n1
build_uboot
