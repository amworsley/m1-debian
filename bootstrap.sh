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

        cat m1n1/build/m1n1.bin `find u-boot -name \*.dtb` u-boot/u-boot-nodtb.bin > u-boot.bin
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
        curl -s https://tg.st/u/config-2022-01-24 > .config
        make olddefconfig
        make -j 16 bindeb-pkg
)
}

build_rootfs()
{
(
        sudo rm -rf testing
        sudo eatmydata debootstrap --arch=arm64 --include initramfs-tools,wpasupplicant,tcpdump,vim,tmux,vlan,ntpdate,bridge-utils,parted,curl,wget,grub-efi-arm64,mtr-tiny,dbus,ca-certificates,sudo,openssh-client testing testing http://ftp.fau.de/debian

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
        sudo cp ../../files/wlp1s0f0 etc/network/interfaces.d/
        sudo cp ../../files/wpa.conf etc/wpa_supplicant/wpa_supplicant.conf

        sudo bash -c 'chroot . apt update'
        sudo bash -c 'chroot . apt install -y firmware-linux-free'

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

build_di_stick()
{
        rm -rf di-stick
        mkdir -p di-stick/efi/boot di-stick/efi/debian/
        test -f initrd.gz || wget https://d-i.debian.org/daily-images/arm64/daily/netboot/debian-installer/arm64/initrd.gz
        sudo rm -rf initrd; mkdir initrd; (cd initrd; gzip -cd ../initrd.gz | sudo cpio -imd --quiet)
        sudo rm -rf initrd/lib/modules/*
        sudo cp -a testing/lib/modules/* initrd/lib/modules/
        sudo cp ../files/wpa.conf initrd/etc/
        (cd initrd; find . | cpio --quiet -H newc -o | pigz > ../di-stick/initrd.gz)
        sudo rm -rf initrd
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi di-stick/efi/boot/bootaa64.efi
        cp testing/boot/vmlinuz* di-stick/vmlinuz
        cp ../files/grub.cfg di-stick/efi/debian/grub.cfg
        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
        cp ${KERNEL} di-stick/
        (cd di-stick; tar cf ../m1-d-i.tar .)
}

upload()
{
        unset MYCURLARGS;
        for FILE in "$@"; do
                MYCURLARGS="$MYCURLARGS -F file=@${FILE}";
        done;
        curl -n -D - $MYCURLARGS https://upload.glanzmann.de/ | grep ^x-location | awk '{print $2}'
}


upload_artefacts()
{
        export KERNEL=`ls -1rt linux-image*.deb | grep -v dbg | tail -1`
        cp ${KERNEL} k.deb
        upload m1-d-i.tar m1.tgz asahi-debian-live.tar u-boot.bin di-stick/vmlinuz k.deb
}

mkdir -p build
cd build

build_m1n1
build_uboot
build_linux
build_rootfs
build_live_stick
build_di_stick
build_fs
upload_artefacts
