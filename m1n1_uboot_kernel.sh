#!/usr/bin/env bash

# SPDX-License-Identifier: MIT

set -o errexit
set -o nounset
set -o pipefail
#set -o xtrace

VERB=0
VOPT=""
LLVM="LLVM=-15"
OUT_DEV=/dev/stdout
L_CLONE=https://github.com/AsahiLinux/linux
L_BRANCH=asahi-wip
if [ -r local-defs.sh ]; then
    . local-defs.sh
fi
set -e
config="config.txt"


export CARGO_HOME="$(pwd)/build/cargo"
export RUSTUP_HOME="$(pwd)/build/rust"
source "$(pwd)/build/cargo/env"

unset LC_CTYPE
unset LANG

export M1N1_VERSION=1.4.11
export KERNEL_VERSION=asahi-6.6-14
export UBOOT_VERSION=asahi-v2023.07.02-4

usage()
{
   echo "Build binaries to install Asahi M1 linux"
   echo "Usage:"
   echo " $(basename $0) [Options] [<Command> ...]"
   echo "Options:"
   echo " -h : Print usage information"
   echo " -n : Dry-run print commands instead of executing them"
   echo " -x : Enabling tracing of shell script"
   echo " -q : Disable tracing of shell script"
   echo " -V level : Set kernel build verbose level (default $VERB)"
   echo " -r : Reduce kernel size greatly by CONFIG_DEBUG_INFO_REDUCED=y"
   echo " -4 : Use 4k page config - instead of $config"
   echo " -D : Don't use $USE_LLVM"
   echo
   echo " -L X : linux version - default $KERNEL_VERSION"
   echo " -M X : m1n1 version - default $M1N1_VERSION"
   echo " -U X : u-boot version - default $UBOOT_VERSION"
   echo
   echo "Commands: (defaults to doing all)"
   echo " linux : extract, patch and build linux image"
   echo " m1n1 : extract, build latest m1n1 image"
   echo " uboot : extract, patch and build u-boot image (requires m1n1)"
   echo " clean : Remove build directory"
   echo
}
CMD="/bin/bash"
while getopts 'hnxqDV:L:M:U:r4' argv
do
    case $argv in
    D)
        LLVM=""
        echo "Don't use LLVM"
    ;;
    h)
       usage
       exit 0
    ;;
    L)
       KERNEL_VERSION="$OPTARG"
       echo "Switching Linux to $KERNEL_VERSION"
    ;;
    M)
       M1N1_VERSION="$OPTARG"
       echo "Switching m1n1 to $M1N1_VERSION"
    ;;
    U)
       UBOOT_VERSION="$OPTARG"
       echo "Switching u-boot to $UBOOT_VERSION"
    ;;
    4)
       config="config-4k.txt"
       echo "Switching config to $config"
    ;;
    n)
       echo "Dry-Run"
       DR=echo
    ;;
    q)
        echo "Disable tracing"
        set +x
	CMD="/bin/bash"
    ;;
    x)
        echo "Enabling tracing"
        set -x
	CMD="/bin/bash -x"
    ;;
    V)
       VERB="$OPTARG"
       if [ "$VERB" -eq 0 ]; then
           echo "Disabling kernel compiling output"
           OUT_DEV=/dev/null
       else
           VOPT="V=$VERB"
           echo "Compiling kernel with $VOPT"
       fi
    ;;
    r)
       echo "Reduce kernel debug info"
       DO_PATCH=1
    ;;
    esac
done
# Obscure option syntax: A + to turn off a "no" option...
set +o nounset
if [ -n "$DR" ]; then
    DO_CMD="cat"
else
    DO_CMD="$CMD"
fi


$DR cd "$(dirname "$0")"
build_linux()
{
(
$DO_CMD <<EOF
        #test -d linux || git clone https://github.com/AsahiLinux/linux
        test -d linux || git clone -b $L_BRANCH $L_CLONE linux
        cd linux
        git fetch -a -t
        git reset --hard $KERNEL_VERSION
        git clean -f -x -d > /dev/null
        cat ../../config.txt > .config
	if [ -n "$DO_PATCH" ]; then
	    sed -i.orig '
/^CONFIG_DEBUG_INFO_REDUCED=./s//CONFIG_DEBUG_INFO_REDUCED=y/
	' .config
	fi
        make $LLVM rustavailable
        make $LLVM olddefconfig
        make -j `nproc` $LLVM $VOPT bindeb-pkg > $OUT_DEV
EOF
)
}

build_m1n1()
{
(
$DO_CMD <<EOF
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1
        cd m1n1
        git fetch -a -t
        git reset --hard v${M1N1_VERSION};
        git clean -f -x -d > /dev/null
        make -j `nproc`
EOF
)
}

build_uboot()
{
(
$DO_CMD <<EOF
        test -d u-boot || git clone https://github.com/AsahiLinux/u-boot
        cd u-boot
        git fetch -a -t
        git reset --hard $UBOOT_VERSION
        git clean -f -x -d > /dev/null

        make apple_m1_defconfig
        make -j `nproc`
EOF
)
if [ -z "$DR" ]; then
        cat m1n1/build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.bin
else
    $DR 'cat m1n1/build/m1n1.bin   \`find linux/arch/arm64/boot/dts/apple/ -name *.dtb\` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.bin'
fi
}

package_boot_bin()
{
(
$DO_CMD <<R_EOF
        rm -rf m1n1_${M1N1_VERSION}_arm64
        mkdir -p m1n1_${M1N1_VERSION}_arm64/DEBIAN m1n1_${M1N1_VERSION}_arm64/usr/lib/m1n1/
        cp u-boot.bin m1n1_${M1N1_VERSION}_arm64/usr/lib/m1n1/boot.bin
        cat <<EOF > m1n1_${M1N1_VERSION}_arm64/DEBIAN/control
Package: m1n1
Version: $M1N1_VERSION
Section: base
Priority: optional
Architecture: arm64
Maintainer: Thomas Glanzmann <thomas@glanzmann.de>
Description: Apple silicon boot loader
 Next to m1n1 this also contains the device trees and u-boot.
EOF

        cat > m1n1_${M1N1_VERSION}_arm64/DEBIAN/postinst <<'EOF'
#!/bin/bash

export PATH=/bin
if [ -f /boot/efi/m1n1/boot.bin ]; then
        cp /boot/efi/m1n1/boot.bin /boot/efi/m1n1/`date +%Y%m%d%H%M`.bin
fi
mkdir -p /boot/efi/m1n1/
cp /usr/lib/m1n1/boot.bin /boot/efi/m1n1/
EOF

        chmod 755 m1n1_${M1N1_VERSION}_arm64/DEBIAN/postinst
        dpkg-deb --build m1n1_${M1N1_VERSION}_arm64
R_EOF
)
}

if [ -n "$DR" ]; then
    if [ ! -d build ]; then
	echo "Creating build directory to run script"
    fi
    echo mkdir -p build
    echo cd build
else
mkdir -p build
cd build
fi

build_all ()
{
build_linux
build_m1n1
build_uboot
package_boot_bin
}

shift $(($OPTIND-1))

if [ -z "$1" ]; then
    build_all
fi

while [ -n "$1" ]; do
    case $1 in
	all) build_all ;;
	linux) build_linux ;;
	m1n1) build_m1n1 ;;
	uboot|u-boot) build_uboot ;;
	clean)
	    $DR cd ..
	    $DR rm -rf build
	;;
    esac
    shift
done
