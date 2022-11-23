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
        git reset --hard asahi-6.1-rc6-5
        source "$HOME/.cargo/env"
        curl -o .config https://tg.st/u/1dbcb0d155911d80f29e61153f53e39bff1c6198f9ed0673520d4cf45343fa9f.config
        make LLVM=-14 olddefconfig
        make LLVM=-14 -j `nproc` V=0 > /dev/null
        sudo make LLVM=-14 V=0 modules_install > /dev/null
        sudo make LLVM=-14 install
)
}

build_m1n1()
{
(
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1
        cd m1n1
        git fetch -a -t
        git reset --hard v1.1.8;
        make -j `nproc`
)
}

build_uboot()
{
(
        test -d u-boot || git clone https://github.com/AsahiLinux/u-boot
        cd u-boot
        git fetch -a -t
        git reset --hard asahi-v2022.10-1;

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