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

build_initrd()
{
(

        rm -rf testing
        sudo eatmydata debootstrap --arch=arm64 --include iwd,tcpdump,vim,tmux,vlan,firmware-linux,ntpdate,bridge-utils,parted,curl,wget,grub-efi-arm64 testing testing http://ftp.fau.de/debian

        cd testing

        sudo -c 'echo live > etc/hostname'

        sudo -c 'echo > etc/motd'

        sudo -c 'echo "deb http://deb.debian.org/debian testing main contrib non-free" > /etc/apt/sources.list'
        sudo -c 'echo "deb-src http://deb.debian.org/debian testing main contrib non-free" > /etc/apt/sources.list'

        sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

        sudo ln -s lib/systemd/systemd init

        sudo cp ../linux-image-5.16.0-asahi-next-20220118-gdcd14bb2ec40_5.16.0-asahi-next-20220118-gdcd14bb2ec40-1_arm64.deb .

        sudo chroot . dpkg -i linux-image-5.16.0-asahi-next-20220118-gdcd14bb2ec40_5.16.0-asahi-next-20220118-gdcd14bb2ec40-1_arm64.deb

        sudo rm linux-image-5.16.0-asahi-next-20220118-gdcd14bb2ec40_5.16.0-asahi-next-20220118-gdcd14bb2ec40-1_arm64.deb

)
}

# build_stick()
# {
# (
#         # find . | cpio --quiet -H newc -o | pigz > ../stick/initrd.gz
#         # cp /boot/efi/EFI/BOOT/BOOTAA64.EFI efi/boot/
#         # cp /boot/vmlinuz-5.16.0-asahi-next-20220118-14779-ga4d177b3ad21-dirty vmlinuz
# )
# }

# build_m1n1
# build_uboot
# build_linux
build_initrd
# build_stick
