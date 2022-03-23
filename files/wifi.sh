#!/bin/sh

FIRMWARE=/mnt/vendorfw/firmware.tar

for DEVICE in /dev/nvme0n1p4 /dev/nvme0n1p5 /dev/nvme0n1p6; do
        mount -o ro -t vfat $DEVICE /mnt;
        if test -f ${FIRMWARE}; then
                tar -C /lib/firmware -xf ${FIRMWARE}
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
