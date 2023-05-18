#!/usr/bin/env bash

# SPDX-License-Identifier: MIT

set -o errexit
set -o nounset
set -o pipefail
#set -o xtrace

cd "$(dirname "$0")"
#set -x
VERB=0
OUT_DEV=/dev/null
L_CLONE=https://github.com/AsahiLinux/linux
L_BRANCH=asahi-wip
ASASHI_LINUX_VER=asahi-6.2-11
if [ -r local-defs.sh ]; then
    . local-defs.sh
fi
set -e
config="config.txt"

unset LC_CTYPE
unset LANG

export DEBOOTSTRAP=debootstrap

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
   echo
   echo " -L X : Use linux version - default $ASASHI_LINUX_VER"
   echo
   echo "Commands: (defaults to doing all)"
   echo " install : Install require debian packages"
   echo " linux : extract, patch and build linux image"
   echo " m1n1 : extract, build latest m1n1 image"
   echo " uboot : extract, patch and build u-boot image (requires m1n1)"
   echo " rootfs : Creates directory 'testing' containing debian rootfs "
   echo " di : Build debian installer"
   echo " dd : From testing rootfs make m1.tgz (ext4 rootfs image)"
   echo " live : From rootfs testing + linux build create tar ball"
   echo " efi : Create efi.tgz file of grub EFI partition from testing rootfs"
   echo " clean : Remove build directory"
   echo
   echo "  See README for details "
   echo
   if [ -r README.md ]; then
       sed '1,/^# scriptlets/d' README.md
   fi
}

handle_crosscompile()
{
        if [ "`uname -m`" != 'aarch64' ]; then
                export ARCH=arm64
                export CROSS_COMPILE=aarch64-linux-gnu-
                export DEBOOTSTRAP=qemu-debootstrap
                sudo apt install -y libc6-dev-arm64-cross
        fi
}

build_linux()
{
(
        handle_crosscompile
$DO_CMD <<EOF
        test -d linux || git clone -b $L_BRANCH $L_CLONE linux
        cd linux
        git fetch -a -t
        #git reset --hard $ASASHI_LINUX_VER
        cat ../../$config > .config
	if [ -n $DO_PATCH ]; then
	    sed -i.orig '
/^CONFIG_DEBUG_INFO_REDUCED=./s//CONFIG_DEBUG_INFO_REDUCED=y/
	' .config
	fi
        for patches in ../../glanzmann-p*.patch; do
            echo "Applying $(basename $patches)"
            git am $patches
        done
        make LLVM=clang rustavailable
        make LLVM=clang olddefconfig
        make -j `nproc` LLVM=clang V=$VERB bindeb-pkg > $OUT_DEV
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
        # https://github.com/AsahiLinux/PKGBUILDs/blob/main/m1n1/PKGBUILD
        git reset --hard v1.1.8; git clean -f -x -d &> $OUT_DEV
        make -j `nproc`
EOF
)
}

build_uboot()
{
(
        handle_crosscompile
$DO_CMD <<EOF
        test -d u-boot || git clone https://github.com/AsahiLinux/u-boot
        cd u-boot
        git fetch -a -t
        # For tag, see https://github.com/AsahiLinux/PKGBUILDs/blob/main/uboot-asahi/PKGBUILD
        git reset --hard asahi-v2022.10-1; git clean -f -x -d &> $OUT_DEV
        git revert --no-edit 4d2b02faf69eaddd0f73758ab26c456071bd2017

        make apple_m1_defconfig
        make -j `nproc`
EOF
)

	local DTB_FILES=$(find linux/arch/arm64/boot/dts/apple/ -name \*.dtb)
	local UBOOT_GZIP="u-boot/u-boot-nodtb.bin.gz"
$DO_CMD <<EOF
        cat m1n1/build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.bin
        cat m1n1/build/m1n1.macho `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.macho
        cp u-boot.bin 4k.bin
        cp u-boot.bin 2k.bin
        echo 'display=2560x1440' >> 2k.bin
        echo 'display=wait,3840x2160' >> 4k.bin

EOF
}

build_rootfs()
{
(
        handle_crosscompile
$DO_CMD <<EOF
        sudo rm -rf testing
        mkdir -p cache
        sudo eatmydata ${DEBOOTSTRAP} --cache-dir=`pwd`/cache --arch=arm64 --include initramfs-tools,pciutils,wpasupplicant,tcpdump,vim,tmux,vlan,ntpdate,parted,curl,wget,grub-efi-arm64,mtr-tiny,dbus,ca-certificates,sudo,openssh-client,mtools,gdisk,cryptsetup,wireless-regdb,zstd stable testing http://deb.debian.org/debian

        cd testing

        sudo mkdir -p boot/efi/m1n1 etc/X11/xorg.conf.d

        sudo bash -c 'echo debian > etc/hostname'

        sudo bash -c 'echo > etc/motd'

        sudo cp ../../files/sources.list etc/apt/sources.list
        sudo cp ../../files/glanzmann.list etc/apt/sources.list.d/
        sudo cp ../../files/thomas-glanzmann.gpg etc/apt/trusted.gpg.d/
        sudo cp ../../files/hosts etc/hosts
        sudo cp ../../files/resolv.conf etc/resolv.conf
        sudo cp ../../files/quickstart.txt root/
        sudo cp ../../files/interfaces etc/network/interfaces
        sudo cp ../../files/wpa.conf etc/wpa_supplicant/wpa_supplicant.conf
        sudo cp ../../files/rc.local etc/rc.local
        sudo cp ../../files/30-modeset.conf etc/X11/xorg.conf.d/30-modeset.conf
        sudo cp ../../files/blacklist.conf etc/modprobe.d/

        sudo perl -p -i -e 's/"quiet"/"net.ifnames=0"/ if /^GRUB_CMDLINE_LINUX_DEFAULT=/' etc/default/grub

        sudo bash -c 'chroot . apt update'
        sudo bash -c 'chroot . apt install -y firmware-linux'

        sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

        sudo -- ln -s lib/systemd/systemd init

        sudo chroot . apt update
        sudo chroot . apt install -y m1n1 linux-image-asahi
        sudo chroot . apt clean
        sudo rm var/lib/apt/lists/* || true

EOF
)
}

build_live_stick()
{
(
$DO_CMD <<EOF
        rm -rf live-stick
        mkdir -p live-stick/efi/boot live-stick/efi/debian/
        sudo cp ../files/wifi.pl testing/etc/rc.local
        sudo bash -c 'cd testing; find . | cpio --quiet -H newc -o | zstd -T0 -16 > ../live-stick/initrd.zstd'
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi live-stick/efi/boot/bootaa64.efi
        cp testing/boot/vmlinuz* live-stick/vmlinuz
        cp ../files/grub.cfg live-stick/efi/debian/grub.cfg
        (cd live-stick; tar cf ../asahi-debian-live.tar .)
EOF
)
}

build_dd()
{
(
$DO_CMD <<EOF
        rm -f media
        dd if=/dev/zero of=media bs=1 count=0 seek=2G
        mkdir -p mnt
        mkfs.ext4 media
        tune2fs -O extents,uninit_bg,dir_index -m 0 -c 0 -i 0 media
        sudo mount -o loop media mnt
        sudo cp -a testing/* mnt/
        sudo rm -rf mnt/init mnt/boot/efi/m1n1
        sudo umount mnt
        tar cf - media | pigz -9 > m1.tgz
EOF
)
}

build_efi()
{
(
$DO_CMD <<EOFXX
        rm -rf EFI
        mkdir -p EFI/boot EFI/debian
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi EFI/boot/bootaa64.efi

        export INITRD=`ls -1 testing/boot/ | grep initrd`
        export VMLINUZ=`ls -1 testing/boot/ | grep vmlinuz`
        export UUID=`blkid -s UUID -o value media`
        cat > EFI/debian/grub.cfg <<EOF
search.fs_uuid ${UUID} root
linux (\$root)/boot/${VMLINUZ} root=UUID=${UUID} rw
initrd (\$root)/boot/${INITRD}
boot
EOF
        tar czf efi.tgz EFI
EOFXX
)
}

build_efi()
{
(
        rm -rf EFI
        mkdir -p EFI/boot EFI/debian
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi EFI/boot/bootaa64.efi

        export INITRD=`ls -1 testing/boot/ | grep initrd`
        export VMLINUZ=`ls -1 testing/boot/ | grep vmlinuz`
        export UUID=`blkid -s UUID -o value media`
        cat > EFI/debian/grub.cfg <<EOF
search.fs_uuid ${UUID} root
linux (\$root)/boot/${VMLINUZ} root=UUID=${UUID} rw net.ifnames=0
initrd (\$root)/boot/${INITRD}
boot
EOF
)
}

build_asahi_installer_image()
{
(
$DO_CMD <<EOF
        rm -rf aii
        mkdir -p aii/esp/m1n1
        cp -a EFI aii/esp/
        cp testing/usr/lib/m1n1/boot.bin aii/esp/m1n1/boot.bin
        ln media aii/media
        cd aii
        zip -r9 ../debian-base.zip esp media
EOF
)
}

build_di_stick()
{
$DO_CMD <<EOF
        rm -rf di-stick
        mkdir -p di-stick/efi/boot di-stick/efi/debian/
        rm -f initrd.gz
        wget https://d-i.debian.org/daily-images/arm64/daily/netboot/debian-installer/arm64/initrd.gz
        sudo rm -rf initrd; mkdir initrd; (cd initrd; gzip -cd ../initrd.gz | sudo cpio -imd --quiet)
        sudo rm -rf initrd/lib/modules/*
        sudo cp -a testing/lib/modules/* initrd/lib/modules/
        sudo cp ../files/wifi.sh initrd/
        sudo cp ../files/boot.sh initrd/
        (cd initrd; find . | cpio --quiet -H newc -o | pigz -9 > ../di-stick/initrd.gz)
        sudo rm -rf initrd
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi di-stick/efi/boot/bootaa64.efi
        cp testing/boot/vmlinuz* di-stick/vmlinuz
        cp ../files/grub.cfg di-stick/efi/debian/grub.cfg
        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
        cp ${KERNEL} di-stick/
        (cd di-stick; tar cf ../m1-d-i.tar .)
EOF
}

publish_artefacts()
{
        echo upload build/asahi-debian-live.tar build/debian-base.zip
$DO_CMD <<EOF
        sudo cp asahi-debian-live.tar debian-base.zip /u/
EOF
}

CMD="/bin/bash"
while getopts 'hnxqV:L:r4' argv
do
    case $argv in
    h)
       usage
       exit 0
    ;;
    L)
       ASASHI_LINUX_VER="$OPTARG"
       echo "Switching Linux to $ASASHI_LINUX_VER"
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
       if [ "$VERB" -gt 0 ]; then
	   OUT_DEV=/dev/stdout
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


do_install ()
{
$DR  \
sudo apt-get install -y build-essential bash git locales gcc-aarch64-linux-gnu libc6-dev device-tree-compiler imagemagick ccache eatmydata debootstrap pigz libncurses-dev qemu-user-static binfmt-support rsync git flex bison bc kmod cpio libncurses5-dev libelf-dev:native libssl-dev dwarves zstd

}

build_all ()
{
build_linux
build_m1n1
build_uboot
build_rootfs
build_dd
build_efi
build_asahi_installer_image
build_live_stick
publish_artefacts
}

shift $(($OPTIND-1))

if [ -z "$1" ]; then
    do_install
    build_all
fi

while [ -n "$1" ]; do
    case $1 in
	all) build_all ;;
	install) do_install ;;
	linux) build_linux ;;
	m1n1) build_m1n1 ;;
	uboot|u-boot) build_uboot ;;
	rootfs) build_rootfs ;;
	di|di_stick) build_di_stick ;;
	dd) build_dd ;;
	efi) build_efi ;;
	asahi|image|asahi_installer_image) build_asahi_installer_image ;;
	live|stick|live_stick) build_live_stick ;;
	publish|artefacts) publish_artefacts ;;
	clean)
	    $DR cd ..
	    $DR rm -rf build
	;;
    esac
    shift
done
