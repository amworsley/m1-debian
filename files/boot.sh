#!/bin/sh

chroot /target debconf-set-selections < /options
chroot /target apt-get remove grub-efi-arm64-signed
chroot /target grub-install --removable /boot/efi
chroot /target wget https://tg.st/u/k.deb
chroot /target dpkg -i k.deb
chroot /target rm k.deb
cp -a /lib/firmware/brcm /target/lib/firmware/
chroot /target update-grub
