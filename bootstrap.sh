#!/bin/bash

set -x
set -e

unset LC_CTYPE
unset LANG

# Build u-boot
git clone https://github.com/kettenis/u-boot
cd u-boot/
git checkout apple-m1-m1n1-nvme
make apple_m1_defconfig
# it is normal that it runs on an error at the end
make || true
cd ..

# build m1n1
git clone --recursive https://github.com/AsahiLinux/m1n1.git
cd m1n1
make -j
cd ..

# Build our boot object that replaces step2.sh in the asahi installer
cat m1n1/build/m1n1.macho `find u-boot -name \*.dtb` u-boot/u-boot-nodtb.bin > u-boot.macho

# Build Linux
git clone https://github.com/AsahiLinux/linux
cd linux
git checkout origin/asahi
# SPI patches
curl https://tg.st/u/aa6a11b3feeda0f57284f99406188e4615e7c43c.patch | patch -p1
curl https://tg.st/u/9ce9060dea91951a330feeeda3ad636bc88c642c.patch | patch -p1
# Sound patch
curl https://tg.st/u/5nly | patch -p1
# Config with sound enabled
curl https://tg.st/u/asahi-config-2022-01-19 > .config
make olddefconfig
make bindeb-pkg
