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
                sudo apt install -y libc6-dev-arm64-cross
        fi
}

build_linux()
{
(
        handle_crosscompile
        test -d linux || git clone https://github.com/AsahiLinux/linux
        cd linux
        git fetch
        git reset --hard asahi-5.19-5; git clean -f -x -d &> /dev/null
        curl -s https://tg.st/u/40c9642c7569c52189f84621316fc9149979ee65.patch | git am -
        curl -s https://tg.st/u/0001-4k-iommu-patch-2022-07-20.patch | git am -
        cat ../../config-4k.txt > .config
        make olddefconfig
        make -j `nproc` V=0 bindeb-pkg > /dev/null
)
}

build_m1n1()
{
(
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1
        cd m1n1
        git fetch -a -t
        # https://github.com/AsahiLinux/PKGBUILDs/blob/main/m1n1/PKGBUILD
        git reset --hard v1.1.4; git clean -f -x -d &> /dev/null
        make -j `nproc`
)
}

build_uboot()
{
(
        handle_crosscompile
        test -d u-boot || git clone https://github.com/AsahiLinux/u-boot
        cd u-boot
        git fetch -a -t
        # For tag, see https://github.com/AsahiLinux/PKGBUILDs/blob/main/uboot-asahi/PKGBUILD
        git reset --hard asahi-v2022.07-3; git clean -f -x -d &> /dev/null
        git revert --no-edit 4d2b02faf69eaddd0f73758ab26c456071bd2017
        make apple_m1_defconfig
        make -j `nproc`
)

        cat m1n1/build/m1n1.bin   `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.bin
        cat m1n1/build/m1n1.macho `find linux/arch/arm64/boot/dts/apple/ -name \*.dtb` <(gzip -c u-boot/u-boot-nodtb.bin) > u-boot.macho
        cp u-boot.bin 4k.bin
        cp u-boot.bin 2k.bin
        echo 'display=2560x1440' >> 2k.bin
        echo 'display=wait,3840x2160' >> 4k.bin

}

build_rootfs()
{
(
        handle_crosscompile
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
)
}

build_live_stick()
{
(
        rm -rf live-stick
        mkdir -p live-stick/efi/boot live-stick/efi/debian/
        sudo cp ../files/wifi.pl testing/etc/rc.local
        sudo bash -c 'cd testing; find . | cpio --quiet -H newc -o | pigz -9 > ../live-stick/initrd.gz'
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
        dd if=/dev/zero of=media bs=1 count=0 seek=2G
        mkdir -p mnt
        mkfs.ext4 media
        tune2fs -O extents,uninit_bg,dir_index -m 0 -c 0 -i 0 media
        sudo mount -o loop media mnt
        sudo cp -a testing/* mnt/
        sudo rm mnt/init
        sudo umount mnt
        tar cf - media | pigz -9 > m1.tgz
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
linux (\$root)/boot/${VMLINUZ} root=UUID=${UUID} rw
initrd (\$root)/boot/${INITRD}
boot
EOF
        tar czf efi.tgz EFI
)
}

build_asahi_installer_image()
{
(
        rm -rf aii
        mkdir -p aii/esp/m1n1
        cp -a EFI aii/esp/
        cp u-boot.bin aii/esp/m1n1/boot.bin
        ln media aii/media
        cd aii
        zip -r9 ../debian-base.zip esp media
)
}

build_di_stick()
{
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
}

publish_artefacts()
{
        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
        cp ${KERNEL} k.deb
        sudo cp m1-d-i.tar m1.tgz efi.tgz asahi-debian-live.tar u-boot.bin u-boot.macho 2k.bin 4k.bin k.deb m1n1/build/m1n1.bin m1n1/build/m1n1.macho testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi debian-base.zip /u/
}

mkdir -p build
cd build

sudo apt-get install -y build-essential bash git locales gcc-aarch64-linux-gnu libc6-dev device-tree-compiler imagemagick ccache eatmydata debootstrap pigz libncurses-dev qemu-user-static binfmt-support rsync git flex bison bc kmod cpio libncurses5-dev libelf-dev:native libssl-dev dwarves

build_linux
build_m1n1
build_uboot
exit
build_rootfs
#build_di_stick
build_dd
build_efi
build_asahi_installer_image
build_live_stick
publish_artefacts
