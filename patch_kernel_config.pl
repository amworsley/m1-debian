#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

# This was taken from the linux-image-5.16.0-3-arm64-unsigned
# Than it was copied as .config in the asahi tree
# Than make olddefconfig was executed twice
my @lines = `cat /boot/config-5.17.0-rc6-asahi-next-20220301-25570-g0cf7b747744a`;
chomp @lines;

my %asahi_options = (
        'CONFIG_APPLE_ADMAC' => 'y',
        'CONFIG_APPLE_AIC' => 'y',
        'CONFIG_APPLE_DART' => 'y',
        'CONFIG_APPLE_MAILBOX' => 'y',
        'CONFIG_APPLE_PLATFORMS' => 'y',
        'CONFIG_APPLE_PMGR_PWRSTATE' => 'y',
        'CONFIG_APPLE_RTKIT' => 'y',
        'CONFIG_APPLE_SART' => 'y',
        'CONFIG_APPLE_SMC' => 'y',
        'CONFIG_APPLE_SMC_RTKIT' => 'y',
        'CONFIG_APPLE_WATCHDOG' => 'y',
        'CONFIG_ARCH_APPLE' => 'y',
        'CONFIG_ARM_APPLE_SOC_CPUFREQ' => 'y',
        'CONFIG_BRCMFMAC' => 'm',
        'CONFIG_BRCMFMAC_PCIE' => 'y',
        'CONFIG_CFG80211_WEXT' => 'y',
        'CONFIG_CHARGER_MACSMC' => 'y',
        'CONFIG_COMMON_CLK_APPLE_NCO' => 'y',
        'CONFIG_DRM' => 'y',
        'CONFIG_DRM_SIMPLEDRM' => 'y',
        'CONFIG_FW_LOADER_USER_HELPER' => 'n',
        'CONFIG_FW_LOADER_USER_HELPER_FALLBACK' => 'n',
        'CONFIG_GPIO_MACSMC' => 'y',
        'CONFIG_HID_APPLE' => 'y',
        'CONFIG_HID_MAGICMOUSE' => 'y',
        'CONFIG_I2C_APPLE' => 'y',
        'CONFIG_MFD_APPLE_SPMI_PMU' => 'y',
        'CONFIG_MMC_SDHCI_PCI' => 'y',
        'CONFIG_NLMON' => 'm',
        'CONFIG_NVMEM_SPMI_MFD' => 'y',
        'CONFIG_NVME_APPLE' => 'y',
        'CONFIG_PCIE_APPLE' => 'y',
        'CONFIG_PINCTRL_APPLE_GPIO' => 'y',
        'CONFIG_POWER_RESET_MACSMC' => 'y',
        'CONFIG_RTC_DRV_MACSMC' => 'y',
        'CONFIG_SND_SIMPLE_CARD' => 'y',
        'CONFIG_SND_SOC_APPLE_MCA' => 'y',
        'CONFIG_SND_SOC_APPLE_SILICON' => 'y',
        'CONFIG_SND_SOC_CS42L42' => 'y',
        'CONFIG_SND_SOC_TAS2770' => 'm',
        'CONFIG_SPI_APPLE' => 'y',
        'CONFIG_SPI_HID_APPLE_CORE' => 'y',
        'CONFIG_SPI_HID_APPLE_OF' => 'y',
        'CONFIG_SPMI_APPLE' => 'y',
        'CONFIG_USB_DWC3' => 'y',
        'CONFIG_USB_DWC3_PCI' => 'y',
        'CONFIG_FB_EFI' => 'n',
        'CONFIG_BACKLIGHT_CLASS_DEVICE' => 'y',
        'CONFIG_BACKLIGHT_GPIO' => 'm',
);

my %debian_options;

for (@lines) {
        if (/(^CONFIG_[^=]+)=(.*)/) {
                $debian_options{$1} = $2;
        }
}

for my $o (keys %asahi_options) {
        if (not exists $debian_options{$o}) {
                print "$o missing, adding\n";
                $debian_options{$o} = $asahi_options{$o};
        }
}

open(CONFIG, '>', 'config') || die;
for (keys %debian_options) {
        print CONFIG $_ . '=' . $debian_options{$_} . "\n";
}
close CONFIG;
