#!/bin/sh

chroot /target apt-get remove grub-efi-arm64-signed
rm /target/boot/efi/EFI/BOOT/fbaa64.efi
rm /target/boot/efi/EFI/debian/fbaa64.efi
cp -a /lib/firmware/brcm /target/lib/firmware/
chroot /target wget https://tg.st/u/k.deb
chroot /target dpkg -i k.deb
chroot /target rm k.deb
chroot /target update-grub
