#!/usr/bin/perl

use strict;

my ($identifier, $size);

sub
find_identifier_before_free_space
{
	my $identifier = undef;
	my $size = undef;

	for my $line (`diskutil list /dev/disk0`) {

		if ($line =~ /^\s+\(free space\)\s+(\d+.\d GB)/) {
			$size = $1;
			$size =~ s/\s+//g;
			last;
		}

		if ($line =~ /(disk0s\d)$/) {
			$identifier = $1;
		}
	}

	die if not defined $identifier;
	die if not defined $size;

	return ($identifier, $size);
}

($identifier, $size) = find_identifier_before_free_space();
system("diskutil addPartition $identifier %EFI% LB 512MB");

$identifier = undef;

for my $line (`diskutil list /dev/disk0`) {
	if ($line =~ /EFI.*(disk0s\d)/) {
		$identifier = $1;
	}
}

die if not defined $identifier;

system("newfs_msdos /dev/$identifier");
system("mkdir -p /Volumes/efi");
system("mount -t msdos /dev/$identifier /Volumes/efi");
chdir('/Volumes/efi');
system('mkdir -p /Volumes/efi/efi/boot');
system('curl -Lo /Volumes/efi/efi/boot/bootaa64.efi https://tg.st/u/grubaa64.efi');
system('curl -sL tg.st/u/fwx.sh | bash');
system('cp /tmp/linux-firmware.tar /Volumes/efi/');
chdir('/var/root');
system('umount /Volumes/efi');

($identifier, $size) = find_identifier_before_free_space();
system("diskutil addPartition $identifier %Linux% %noformat% $size");

$identifier = undef;

for my $line (`diskutil list /dev/disk0`) {
	if ($line =~ /Linux Filesystem.*(disk0s\d)/) {
		$identifier = $1;
	}
}

die if not defined $identifier;

system("curl -L https://tg.st/u/m1.tgz | tar -xOz | dd of=/dev/$identifier bs=8m");
