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
        sudo eatmydata debootstrap --arch=arm64 --include iwd,tcpdump,vim,tmux,vlan,ntpdate,bridge-utils,parted,curl,wget,grub-efi-arm64,mtr-tiny,dbus testing testing http://ftp.fau.de/debian

        cd testing

        sudo bash -c 'echo live > etc/hostname'

        sudo bash -c 'echo > etc/motd'

        sudo bash -c 'echo "deb http://deb.debian.org/debian testing main contrib non-free" > etc/apt/sources.list'
        sudo bash -c 'echo "deb-src http://deb.debian.org/debian testing main contrib non-free" >> etc/apt/sources.list'

        sudo bash -c 'chroot . apt update'
        sudo bash -c 'chroot . apt install -y firmware-linux'

        sudo -- perl -p -i -e 's/root:x:/root::/' etc/passwd

        sudo -- ln -s lib/systemd/systemd init

        sudo cp ../linux-image-5.16.0-asahi-next-20220118-gdcd14bb2ec40_5.16.0-asahi-next-20220118-gdcd14bb2ec40-1_arm64.deb .

        sudo chroot . dpkg -i linux-image-5.16.0-asahi-next-20220118-gdcd14bb2ec40_5.16.0-asahi-next-20220118-gdcd14bb2ec40-1_arm64.deb

        sudo rm linux-image-5.16.0-asahi-next-20220118-gdcd14bb2ec40_5.16.0-asahi-next-20220118-gdcd14bb2ec40-1_arm64.deb
        sudo bash -c 'apt-get clean'
)
}

build_stick()
{
(
        rm -rf stick
        mkdir -p stick/efi/boot stick/boot
        sudo bash -c 'cd testing; find . | cpio --quiet -H newc -o | pigz > ../stick/initrd.gz'
        cp testing/usr/lib/grub/arm64-efi/monolithic/grubaa64.efi stick/efi/boot/bootaa64.efi
        cp testing/boot/vmlinuz* stick/vmlinuz

        cat > stick/boot/grub.cfg <<EOF
echo Loading Kernel...
linux (hd0,msdos1)/vmlinuz net.ifnames=0
echo Loading initrd... Please wait
initrd (hd0,msdos1)/initrd.gz
boot
EOF

)
}

# build_m1n1
# build_uboot
# build_linux
# build_rootfs
build_stick
