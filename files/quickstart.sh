# Wifi
rmmod brcmfmac
rmmod brcmutil
mount /dev/sda1 /mnt
tar -C /lib/firmware/ -xf /mnt/linux-firmware.tar
umount /mnt
modprobe brcmfmac
/etc/init.d/iwd start
ip link set up dev wlan0
dhclient wlan0

iwctl
station wlan0 connect

# Time
ntpdate pool.ntp.org
date --set 2022-01-25
date --set 14:21
