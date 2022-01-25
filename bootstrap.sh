#!/bin/bash

set -x
set -e

unset LC_CTYPE
unset LANG

build_m1n1()
{
(
        test -d m1n1 || git clone --recursive https://github.com/AsahiLinux/m1n1.git
        cd m1n1
        git fetch
        git reset --hard origin/main; git clean -f -x -d
        make -j 16
)
}

build_uboot()
{
(
        # Build u-boot
        test -d u-boot || git clone https://github.com/kettenis/u-boot
        cd u-boot
        git fetch
        git reset --hard origin/apple-m1-m1n1-nvme; git clean -f -x -d
        make apple_m1_defconfig
        # it is normal that it runs on an error at the end
        make -j 16 || true
)

        cat m1n1/build/m1n1.macho `find u-boot -name \*.dtb` u-boot/u-boot-nodtb.bin > u-boot.macho
}

build_linux()
{
(
        test -d linux || git clone --depth 1 https://github.com/AsahiLinux/linux
        cd linux
        git fetch
        git reset --hard origin/asahi; git clean -f -x -d
        curl -s https://tg.st/u/9ce9060dea91951a330feeeda3ad636bc88c642c.patch | git am -
        curl -s https://tg.st/u/5nly | git am -
        curl -s https://tg.st/u/asahi-config-2022-01-19 > .config
        make olddefconfig
        make -j 16 bindeb-pkg
)
}

build_rootfs()
{
(
        sudo rm -rf testing
        sudo eatmydata debootstrap --arch=arm64 --include initramfs-tools,iwd,tcpdump,vim,tmux,vlan,ntpdate,bridge-utils,parted,curl,wget,grub-efi-arm64,mtr-tiny,dbus,ca-certificates,sudo,openssh-client testing testing http://ftp.fau.de/debian

        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`

        cd testing

        sudo bash -c 'echo live > etc/hostname'

        sudo bash -c 'echo > etc/motd'

        sudo cp ../../files/sources.list etc/apt/sources.list
        sudo cp ../../files/hosts etc/hosts
        sudo cp ../../files/resolv.conf etc/resolv.conf
        sudo cp ../../files/fstab etc/fstab
        sudo cp ../../files/quickstart.txt root/
        sudo cp ../../files/eth0 etc/network/interfaces.d/

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

build_stick()
{
(
        rm -rf stick
        mkdir -p stick/efi/boot stick/efi/debian/
        sudo bash -c 'cd testing; find . | cpio --quiet -H newc -o | pigz > ../stick/initrd.gz'
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi stick/efi/boot/bootaa64.efi
        cp testing/boot/vmlinuz* stick/vmlinuz
        cp ../files/grub.cfg stick/efi/debian/grub.cfg
        (cd stick; tar cf ../asahi-debian-live-`date "+%Y-%m-%d"`.tar .)
)
}

build_fs()
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

mkdir -p build
cd build

build_m1n1
build_uboot
build_linux
build_rootfs
build_stick
build_fs
