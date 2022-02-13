#!/bin/sh

for DEVICE in /dev/sda1; do
        mount -o ro $DEVICE /mnt;
        if test -f /mnt/linux-firmware.tar; then
                tar -C /lib/firmware -xf /mnt/linux-firmware.tar
                rmmod brcmfmac
                rmmod brcmutil
                sleep 1
                modprobe brcmfmac
                sleep 1
                rmmod brcmfmac
                sleep 1
                modprobe brcmfmac
                umount /mnt
                exit
        fi
        umount /mnt
done
