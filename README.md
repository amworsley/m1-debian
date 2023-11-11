This pages explains how to install Debian on Apple Silicon machines.

# Tripwires
The USB-A Port on the Mac Mini will not work in u-boot and grub.  The two
additional USB-3 ports on the iMac 4 port model don't work in u-boot, grub
and Linux. In order to install Linux on a FileVault-enabled Mac run the
installer from Recovery open Disk Utility > Expanding "Macintosh HD" >
Selecting locked volume > click "Mount". Debian does not include the choosen
EFI patch. As a result it will always pick the first ESP partition. This can be
problematic if you're using multiple ESP partitions for example when having
multiple Linux and BSD installations.

# Artefacts
If you don't want to use the prebuild artefacts, you can build them yourself
using the following scripts:

        - prepare_rust.sh - Prepares a rust installation suitable for kernel compilation
        - m1n1_uboot_kernel.sh - Builds m1n1, u-boot and the kernel including gpu support.
        - mesa.sh - Creates mesa packages
        - bootstrap.sh - Creates Debian root and live filesystem
        - meta.sh - Meta package which makes sure that we always get latest and greatest kernel.

# Asahi installer

[Video Recording](https://tg.st/u/debian_asahi_installer.mp4)

* Poweroff your Mac. Hold and press the power button until you see a wheel chain and Options written below. Approx 20 seconds.

* In the boot picker, choose Options. Once loaded, open a Terminal under Utilities > Terminal

* Run the asahi installer and select Debian:

        curl -sL https://tg.st/d | sh

* Follow the installer instructions.

* Once Debian is booted log in as root without password and set a root password

        passwd
        pwconv

* Configure wifi by editing the wpa_supplicant.conf, enabling the interface and remove the # before allow-hotplug to enable it during boot.

        vi /etc/wpa_supplicant/wpa_supplicant.conf
        ifup wlan0
        vi /etc/network/interfaces

* Reboot to see if grub was correctly installed

        reboot

* Install a desktop environment for example blackbox

        apt-get update
        apt-get install -y xinit blackbox xterm firefox-esr lightdm

* Create yourself an unprivileged user

        useradd -m -c 'Firstname Lastname' -s /bin/bash <username>
        passwd <username>

* Optional install sshd. You can not log in as root, but only with your unprivileged user

        apt update
        apt install -y openssh-server

* Consult the **[/root/quickstart.txt](https://git.zerfleddert.de/cgi-bin/gitweb.cgi/m1-debian/blob_plain/refs/heads/master:/files/quickstart.txt)** file to find out how to do other interesting things.

# Livesystem

[Video Recording](https://tg.st/u/live.mp4)

* Prerequisites

        - USB Stick. this is what this guide assumes, but it is also possible
          to run the Debian livesystem from another PC using m1n1 chainloading.
          But if you know how to do that, you probably don't need this guide.
        - If possible use an Ethernet Dongle, less typing.

* Create USB Stick with a single vfat partition on it and untar the modified Debian installer on it. Instructions for Linux:

        # Identify the usb stick device
        lsblk

        DEVICE=/dev/sdX
        parted -a optimal $DEVICE mklabel msdos
        parted -a optimal $DEVICE mkpart primary fat32 2048s 100%
        mkfs.vfat ${DEVICE}1
        mount ${DEVICE}1 /mnt
        curl -sL https://tg.st/u/asahi-debian-live.tar | tar -C /mnt -xf -
        umount /mnt

In order to format the usb stick under Macos, open the disk utility, right-click on the usb stick (usually the lowest device in the list) and select erase. Choose the following options:

        Name: LIVE
        Format: MS-DOS (FAT)
        Scheme: Master Boot Record

Than open a terminal, and run the following commands:

        sudo su -
        cd /Volumes/LIVE
        curl -sL https://tg.st/u/asahi-debian-live.tar | tar -xf -

* You need to run the asahi installer and have either an OS installed or m1n1+UEFI.

* If you have a EFI binary on the NVMe and want to boot from the usb stick, you need to interrupt u-boot on the countdown by pressing any key and run the following comamnd to boot from usb:

        env set boot_efi_bootmgr; run bootcmd_usb0

* Reboot with the USB stick connected, the Debian livesystem should automatically start, if it doesn't load the kernel and initrd manually, you can use tab. For x try 0,1,2,...

        linux (hdX,msdos1)/vmlinuz
        initrd (hdX,msdos1)/initrd.gz
        boot

* Log in as **root** without password.

* Consult the **[/root/quickstart.txt](https://git.zerfleddert.de/cgi-bin/gitweb.cgi/m1-debian/blob_plain/refs/heads/master:/files/quickstart.txt)** file to find out how to get the networking up, etc.

# FAQ

## How to enable spakers?

Currently speakers are only supported on M1 air. Install the necessary packages:

        apt update
        apt upgrade -y
        apt dist-upgrade -y
        apt install -y alsa-ucm-conf-asahi speakersafetyd
        reboot

After the reboot I need to restart the speakersafetyd in order to hear sound out of the speakers:

        sudo systemctl restart speakersafetyd

## Does it work on M2?

Yes, M3 is not yet supported.

## Are you still maintaining this?

Yes, I do and will continue doing this until there is an official Debian installer.

## If I install Debian, will it be easy to update the Asahi work as it develops?

Yes, long answer below.

To update the kernel to the lastest "stable" asahi branch you need to run
as root:

        apt update
        apt upgrade

For installations before 2022-12-12, see <https://thomas.glanzmann.de/asahi/README.txt>

Later it might be necessary to upgrade the stub partion in order to
support the GPU code. As soon as that happens, I'll add the
instructions and a video in order to do so, but short version is:

        - Backup /boot/efi/EFI
        - Delete the old stub and efi/esp partition
        - Rerun the asahi installer with m1n1+u-boot option
        - Put the /boot/efi/EFI back

So, you never need to reinstall Debian. Kernel updates are easy, stub
updates are a little bit more cumbersome but also seldom.

## How do I compile zfs on apple silicon debian?

- In order to build zfs you need the rust environment. So from the m1-debian
  repository you have to run these scripts:

        ./dependencies.sh
        ./prepare_rust.sh

- Prepare your zfs build environment. You need to replace
  /home/sithglan/work/m1-debian with your path to
  your m1-debian checkout:

        export CARGO_HOME="/home/sithglan/work/m1-debian/build/cargo"
        export RUSTUP_HOME="/home/sithglan/work/m1-debian/build/rust"
        source "/home/sithglan/work/m1-debian/build/cargo/env"

- Tell zfs which version of clang you use to compile the kernel:

        export KERNEL_LLVM=-15

- Checkout ZFS:

        git clone https://github.com/openzfs/zfs
        cd ./zfs
        git checkout master

- Apply the following patch:

        diff --git a/META b/META
        index 3919b0d..67c9f7d 100644
        --- a/META
        +++ b/META
        @@ -4,7 +4,7 @@ Branch:        1.0
        Version:       2.2.99
        Release:       1
        Release-Tags:  relext
        -License:       CDDL
        +License:       GPL
        Author:        OpenZFS
        Linux-Maximum: 6.4
        Linux-Minimum: 3.10

- Build ZFS:

        sh autogen.sh
        ./configure
        make -s -j$(nproc)

- Follow the instructions on <https://openzfs.github.io/openzfs-docs/Developer%20Resources/Building%20ZFS.html> how to install it.

# scriptlets to check things

See what kernel is grub is currently default for booting

   sed -n '/default="[a-z]/ { s/^[^"]*"//;s/"$//p}' /boot/grub/grub.cfg

Check what kernel version is recommended with:

    sed -n '/^build_linux(/,/^}/p' m1n1_uboot_kernel.sh

Check what kernel bootstrap.sh is building

    sed -n '/^build_linux(/,/^}/p' bootstrap.sh

See what menu entries are available for boot by grub

    sed -n "/menuentry/s/^.*menuentry_id_option '//;s/' {//p" /boot/grub/grub.cfg

Build a new kernel and modules directly in build/linux

cd build/linux
make -j 8 LLVM=clang V=1 Image.gz modules
sudo make -j 8 LLVM=clang V=1 zinstall modules_install
