#!/usr/bin/perl

# Script to install chainload rust in Debian

my $esp_line = `diskutil list disk0 | grep EFI`;

my $esp_disk = undef;

if ($esp_line =~ /(disk0s\d)/) {
	$esp_disk = $1;
}

die unless defined $esp_disk;

my $partuuid = `diskutil info $esp_disk | grep 'Partition UUID' | awk -F: '{print \$2}'`;

$partuuid =~ s/\s+//g;

my $m1n1 = `curl -sL tg.st/m1n1-rust.bin`;

open(OBJECT, '>', 'object.bin') || die;
print OBJECT $m1n1;
print OBJECT "chainload=$partuuid;m1n1/boot.bin')\n";
print OBJECT "chosen.asahi,efi-system-partition=$partuuid\n";
close (OBJECT);

system('kmutil configure-boot -c object.bin --raw --entry-point 2048 --lowest-virtual-address 0 -v /Volumes/Debian');
