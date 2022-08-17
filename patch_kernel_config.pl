#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

# This was taken from the linux-image-5.16.0-3-arm64-unsigned
# Than it was copied as .config in the asahi tree
# Than make olddefconfig was executed twice
my @lines = `cat config`;
chomp @lines;

my %asahi_options = (
        'CONFIG_APPLE_ADMAC' => 'm',
        'CONFIG_APPLE_AIC' => 'y',
        'CONFIG_APPLE_DART' => 'm',
        'CONFIG_APPLE_MAILBOX' => 'y',
        'CONFIG_APPLE_PLATFORMS' => 'y',
        'CONFIG_APPLE_PMGR_PWRSTATE' => 'y',
        'CONFIG_APPLE_RTKIT' => 'y',
        'CONFIG_APPLE_SART' => 'm',
        'CONFIG_APPLE_SMC' => 'y',
        'CONFIG_APPLE_SMC_RTKIT' => 'y',
        'CONFIG_APPLE_WATCHDOG' => 'y',
        'CONFIG_ARCH_APPLE' => 'y',
        'CONFIG_ARM_APPLE_SOC_CPUFREQ' => 'm',
        'CONFIG_BRCMFMAC' => 'm',
        'CONFIG_BRCMFMAC_PCIE' => 'y',
        'CONFIG_CFG80211_WEXT' => 'y',
        'CONFIG_CHARGER_MACSMC' => 'm',
        'CONFIG_COMMON_CLK_APPLE_NCO' => 'm',
        'CONFIG_DRM' => 'y',
        'CONFIG_DRM_SIMPLEDRM' => 'y',
        'CONFIG_FW_LOADER_USER_HELPER' => 'n',
        'CONFIG_FW_LOADER_USER_HELPER_FALLBACK' => 'n',
        'CONFIG_GPIO_MACSMC' => 'y',
        'CONFIG_HID_APPLE' => 'm',
        'CONFIG_HID_MAGICMOUSE' => 'm',
        'CONFIG_I2C_APPLE' => 'm',
        'CONFIG_MFD_APPLE_SPMI_PMU' => 'm',
        'CONFIG_MMC_SDHCI_PCI' => 'm',
        'CONFIG_NLMON' => 'm',
        'CONFIG_NVMEM_SPMI_MFD' => 'm',
        'CONFIG_NVME_APPLE' => 'm',
        'CONFIG_PCIE_APPLE' => 'm',
        'CONFIG_PINCTRL_APPLE_GPIO' => 'm',
        'CONFIG_POWER_RESET_MACSMC' => 'm',
        'CONFIG_RTC_DRV_MACSMC' => 'm',
        'CONFIG_SND_SIMPLE_CARD' => 'm',
        'CONFIG_SND_SOC_APPLE_MCA' => 'm',
        'CONFIG_SND_SOC_APPLE_SILICON' => 'm',
        'CONFIG_SND_SOC_CS42L42' => 'm',
        'CONFIG_SND_SOC_TAS2770' => 'm',
        'CONFIG_SPI_APPLE' => 'm',
        'CONFIG_SPI_HID_APPLE_CORE' => 'm',
        'CONFIG_SPI_HID_APPLE_OF' => 'm',
        'CONFIG_SPMI_APPLE' => 'm',
        'CONFIG_USB_DWC3' => 'm',
        'CONFIG_BACKLIGHT_CLASS_DEVICE' => 'y',
        'CONFIG_BACKLIGHT_GPIO' => 'y',
        'CONFIG_TYPEC_TPS6598X' => 'm',
        'CONFIG_BT_HCIBCM4377' => 'm',
        'CONFIG_HID_DOCKCHANNEL' => 'm',
        'CONFIG_APPLE_DOCKCHANNEL' => 'm',
);

my %debian_options;

for (@lines) {
        if (/(^CONFIG_[^=]+)=(.*)/) {
                $debian_options{$1} = $2;
        }
}

for my $o (keys %asahi_options) {
        if ((not exists $debian_options{$o}) && $asahi_options{$o} ne 'n') {
                print "$o missing, adding\n";
                $debian_options{$o} = $asahi_options{$o};
        } elsif ((exists $debian_options{$o}) && ($asahi_options{$o} eq 'n')) {
                print "$o present, removing\n";
                delete $debian_options{$o};
        } elsif ((exists $asahi_options{$o} && exists $debian_options{$o}) && ($debian_options{$o} ne $asahi_options{$o})) {
                print "$o different\n";
        }
}

open(CONFIG, '>', 'config.new') || die;
for (keys %debian_options) {
        print CONFIG $_ . '=' . $debian_options{$_} . "\n";
}
close CONFIG;
