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
curl https://tg.st/u/c5eb67144c10f8685ebd8c1dfef8586588e1994d.patch | patch -p1
curl https://tg.st/u/asahi-config-2022-01-08 > .config
make olddefconfig
make bindeb-pkg
