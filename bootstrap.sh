#!/bin/bash

# SPDX-License-Identifier: MIT

#set -x
VERB=0
set -e

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
   echo
   echo "  See README for details "
   echo
   #if [ -r README ]; then
   #    cat README
   #fi
}

handle_crosscompile()
{
        if [ "`uname -m`" != 'aarch64' ]; then
                export ARCH=arm64
                export CROSS_COMPILE=aarch64-linux-gnu-
                export DEBOOTSTRAP=qemu-debootstrap
        fi
}

build_linux()
{
(
        handle_crosscompile
$DO_CMD <<EOF
        test -d linux || git clone --depth 1 https://github.com/AsahiLinux/linux -b asahi
        cd linux
        git fetch
        git reset --hard origin/asahi; git clean -f -x -d &> /dev/null
        curl -s https://tg.st/u/40c9642c7569c52189f84621316fc9149979ee65.patch | git am -
        curl -s https://tg.st/u/0001-4k-iommu-patch-2022-03-11.patch | git am -
        curl -s https://tg.st/u/config-2022-03-17-distro-sven-jannau.txt > .config
	if [ -n $DO_PATCH ]; then
	    sed -i.orig '
/^CONFIG_DEBUG_INFO_REDUCED=./s//CONFIG_DEBUG_INFO_REDUCED=y/
	' .config
	fi
        make olddefconfig
        make -j `nproc` V=$VERB bindeb-pkg > /dev/null
EOF
)
}

build_m1n1()
{
(
$DO_CMD <<EOF
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1
        cd m1n1
        git fetch
        git reset --hard origin/main; git clean -f -x -d &> /dev/null
        make -j `nproc`
EOF
)
}

build_uboot()
{
(
        handle_crosscompile
$DO_CMD <<EOF
        test -d u-boot || git clone --depth 1 https://github.com/AsahiLinux/u-boot
        cd u-boot
        git fetch
        git reset --hard origin/asahi; git clean -f -x -d &> /dev/null
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
        sudo eatmydata ${DEBOOTSTRAP} --cache-dir=`pwd`/cache --arch=arm64 --include initramfs-tools,pciutils,wpasupplicant,tcpdump,vim,tmux,vlan,ntpdate,parted,curl,wget,grub-efi-arm64,mtr-tiny,dbus,ca-certificates,sudo,openssh-client,mtools,gdisk testing testing http://deb.debian.org/debian

        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`

        cd testing

        sudo mkdir -p boot/efi

        sudo bash -c 'echo debian > etc/hostname'

        sudo bash -c 'echo > etc/motd'

        sudo cp ../../files/sources.list etc/apt/sources.list
        sudo cp ../../files/hosts etc/hosts
        sudo cp ../../files/resolv.conf etc/resolv.conf
        sudo cp ../../files/quickstart.txt root/
        sudo cp ../../files/interfaces etc/network/interfaces
        sudo cp ../../files/wpa.conf etc/wpa_supplicant/wpa_supplicant.conf
        sudo cp ../../files/rc.local etc/rc.local

        sudo bash -c 'chroot . apt update'
        sudo bash -c 'chroot . apt install -y firmware-linux'

        sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

        sudo -- ln -s lib/systemd/systemd init

        sudo cp ../${KERNEL} .
        sudo chroot . dpkg -i ${KERNEL}
        sudo rm ${KERNEL}

        sudo bash -c 'chroot . apt-get clean'
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
        sudo bash -c 'cd testing; find . | cpio --quiet -H newc -o | pigz -9 > ../live-stick/initrd.gz'
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
        sudo rm mnt/init
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

build_asahi_installer_image()
{
(
$DO_CMD <<EOF
        rm -rf aii
        mkdir -p aii/esp/m1n1
        cp -a EFI aii/esp/
        cp u-boot.bin aii/esp/m1n1/boot.bin
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
        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
$DO_CMD <<EOF
        cp ${KERNEL} k.deb
        sudo cp m1-d-i.tar m1.tgz efi.tgz asahi-debian-live.tar u-boot.bin u-boot.macho 2k.bin 4k.bin k.deb m1n1/build/m1n1.bin m1n1/build/m1n1.macho testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi debian-base.zip /u/
EOF
}

CMD="/bin/bash"
while getopts 'hnxqV:r' argv
do
    case $argv in
    h)
       usage
       exit 0
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
    ;;
    r)
       echo "Reduce kernel debug info"
       DO_PATCH=1
    ;;
    esac
done
if [ -n "$DR" ]; then
    DO_CMD="cat"
else
    DO_CMD="$CMD"
fi

if [ -n $DR ]; then
    if [ ! -d build ]; then
	echo "Creating build directory to run script"
    fi
    echo mkdir -p build
    echo DR cd build
fi
mkdir -p build
cd build

do_install ()
{
   $DR \
sudo apt-get install -y build-essential bash git locales gcc-aarch64-linux-gnu libc6-dev-arm64-cross device-tree-compiler imagemagick ccache eatmydata debootstrap pigz libncurses-dev qemu-user-static binfmt-support rsync git flex bison bc kmod cpio libncurses5-dev libelf-dev:native libssl-dev dwarves

}

build_all ()
{
build_linux
build_m1n1
build_uboot
build_rootfs
#build_di_stick
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
    esac
    shift
done
