#!/bin/bash

# SPDX-License-Identifier: MIT

set -x
set -e

unset LC_CTYPE
unset LANG

export DEBOOTSTRAP=debootstrap

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
        test -d linux || git clone --depth 1 https://github.com/jannau/linux -b spmi/work
        cd linux
        git fetch
        git reset --hard origin/spmi/work; git clean -f -x -d &> /dev/null
        curl -s https://tg.st/u/9ce9060dea91951a330feeeda3ad636bc88c642c.patch | git am -
        curl -s https://tg.st/u/5nly.patch | git am -
        curl -s https://tg.st/u/0wM8.patch | git am -
        curl -s https://tg.st/u/256f5efbf23ff68c489dad92f99d1cecfb021729.patch | git am -
        curl -s https://tg.st/u/8737955a0263d09ffa8550658dfcac1df3d0665c.patch | git am -
        curl -s https://tg.st/u/0001-4k-iommu-patch.patch | git am -
        curl -s https://tg.st/u/0001-21-02-axboe-grabbing-anv-lock-around-the-issue-does-.patch | git am -
        curl -s https://tg.st/u/50c69de75b60f6e47dc9f2a2ee85c6f69648e489.patch | git am -
        curl -s https://tg.st/u/config-2022-02-16 > .config
        make olddefconfig
        make -j $(( 2* `nproc`)) V=0 bindeb-pkg &> /dev/null
)
}

build_m1n1()
{
(
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1.git
        cd m1n1
        git fetch
        git reset --hard origin/main; git clean -f -x -d &> /dev/null
        make -j $(( 2* `nproc`)) &> /dev/null
)
}

build_uboot()
{
(
        handle_crosscompile
        test -d u-boot || git clone --depth 1 https://github.com/jannau/u-boot -b x2r10g10b10
        cd u-boot
        git fetch
        git reset --hard origin/x2r10g10b10; git clean -f -x -d &> /dev/null
        curl -s https://tg.st/u/v2-console-usb-kbd-Limit-poll-frequency-to-improve-performance.diff | patch -p1
        make apple_m1_defconfig
        make -j $(( 2* `nproc`)) &> /dev/null
)

        cat m1n1/build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` u-boot/u-boot-nodtb.bin > u-boot.bin
        cat m1n1/build/m1n1.macho `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` u-boot/u-boot-nodtb.bin > u-boot.macho
}

build_rootfs()
{
(
        handle_crosscompile
        sudo rm -rf testing
        mkdir -p cache
        sudo eatmydata ${DEBOOTSTRAP} --cache-dir=`pwd`/cache --arch=arm64 --include initramfs-tools,wpasupplicant,tcpdump,vim,tmux,vlan,ntpdate,bridge-utils,parted,curl,wget,grub-efi-arm64,mtr-tiny,dbus,ca-certificates,sudo,openssh-client testing testing http://ftp.fau.de/debian

        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`

        cd testing

        sudo bash -c 'echo live > etc/hostname'

        sudo bash -c 'echo > etc/motd'

        sudo cp ../../files/sources.list etc/apt/sources.list
        sudo cp ../../files/hosts etc/hosts
        sudo cp ../../files/resolv.conf etc/resolv.conf
        sudo cp ../../files/fstab etc/fstab
        sudo cp ../../files/quickstart.txt root/
        sudo cp ../../files/interfaces etc/network/interfaces
        sudo cp ../../files/wpa.conf etc/wpa_supplicant/wpa_supplicant.conf

        sudo bash -c 'chroot . apt update'
        sudo bash -c 'chroot . apt install -y firmware-linux'

        sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

        sudo -- ln -s lib/systemd/systemd init

        sudo cp ../${KERNEL} .
        sudo chroot . dpkg -i ${KERNEL}
        sudo rm ${KERNEL}

        sudo bash -c 'apt-get clean'
)
}

build_live_stick()
{
(
        rm -rf live-stick
        mkdir -p live-stick/efi/boot live-stick/efi/debian/
        sudo bash -c 'cd testing; find . | cpio --quiet -H newc -o | pigz > ../live-stick/initrd.gz'
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi live-stick/efi/boot/bootaa64.efi
        cp testing/boot/vmlinuz* live-stick/vmlinuz
        cp ../files/grub.cfg live-stick/efi/debian/grub.cfg
        (cd live-stick; tar cf ../asahi-debian-live.tar .)
)
}

build_dd()
{
(
        rm -f media
        dd if=/dev/zero of=media bs=1 count=0 seek=1G
        mkdir -p mnt
        mkfs.ext4 media
        tune2fs -O extents,uninit_bg,dir_index -m 0 -c 0 -i 0 media
        sudo mount -o loop media mnt
        sudo cp -a testing/* mnt/
        sudo rm mnt/init
        sudo umount mnt
        tar cf - media | pigz > m1.tgz
)
}

build_di_stick()
{
        rm -rf di-stick
        mkdir -p di-stick/efi/boot di-stick/efi/debian/
        test -f initrd.gz || wget https://d-i.debian.org/daily-images/arm64/daily/netboot/debian-installer/arm64/initrd.gz
        sudo rm -rf initrd; mkdir initrd; (cd initrd; gzip -cd ../initrd.gz | sudo cpio -imd --quiet)
        sudo rm -rf initrd/lib/modules/*
        sudo cp -a testing/lib/modules/* initrd/lib/modules/
        sudo cp ../files/wifi.sh initrd/
        sudo cp ../files/boot.sh initrd/
        (cd initrd; find . | cpio --quiet -H newc -o | pigz > ../di-stick/initrd.gz)
        sudo rm -rf initrd
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi di-stick/efi/boot/bootaa64.efi
        cp testing/boot/vmlinuz* di-stick/vmlinuz
        cp ../files/grub.cfg di-stick/efi/debian/grub.cfg
        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
        cp ${KERNEL} di-stick/
        (cd di-stick; tar cf ../m1-d-i.tar .)
}

publish_artefacts()
{
        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
        cp ${KERNEL} k.deb
        sudo mv m1-d-i.tar m1.tgz asahi-debian-live.tar u-boot.bin u-boot.macho di-stick/vmlinuz k.deb /u/
}

mkdir -p build
cd build

sudo apt-get install -y build-essential bash git locales gcc-aarch64-linux-gnu libc6-dev-arm64-cross device-tree-compiler imagemagick ccache eatmydata debootstrap pigz libncurses-dev qemu-user-static binfmt-support rsync git

build_linux
build_m1n1
build_uboot
build_rootfs
build_live_stick
build_di_stick
build_dd
publish_artefacts
