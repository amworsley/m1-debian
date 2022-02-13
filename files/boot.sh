#!/bin/sh

echo 'grub-efi-arm64 grub2/update_nvram boolean false' | chroot /target debconf-set-selections
echo 'grub-efi-arm64 grub2/force_efi_extra_removable boolean false' | chroot /target debconf-set-selections
chroot /target apt-get remove grub-efi-arm64-signed
chroot /target grub-install --removable /boot/efi
rm /target/boot/efi/EFI/BOOT/fbaa64.efi
rm /target/boot/efi/EFI/debian/fbaa64.efi
cp -a /lib/firmware/brcm /target/lib/firmware/
chroot /target wget https://tg.st/u/k.deb
chroot /target dpkg -i k.deb
chroot /target rm k.deb
chroot /target update-grub
