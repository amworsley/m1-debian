#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

my $firmware_tarball = '/mnt/vendorfw/firmware.tar';
my @vfat_devices;

for (`blkid`) {
        if (/^([^:]+):.*vfat/) {
                push @vfat_devices, $1;
        }
}

for my $dev (@vfat_devices) {
        system("mount -o ro $dev /mnt");
        if (-f $firmware_tarball) {
                system("tar -C /lib/firmware/ -xf $firmware_tarball");
                system('rmmod brcmfmac');
                system('rmmod brcmutil');
                sleep(1);
                system('modprobe brcmfmac');
                sleep(1);
                system('rmmod brcmfmac');
                sleep(1);
                system('modprobe brcmfmac');
        }
        system('umount /mnt');

}
