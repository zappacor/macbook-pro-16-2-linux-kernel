#!/bin/bash

# Written by: Rolando Zappacosta
#   rolando_dot_zappacosta_at_nokia_dot_com

KERNEL_VERSION=5.9.8
KERNEL_URL=https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz
#
DRIVER_BCE_URL=https://github.com/t2linux/apple-bce-drv/archive/aur.zip
DRIVER_IBRIDGE_URL=https://github.com/roadrunner2/macbook12-spi-driver/archive/mbp15.zip
#
ZAPPACOR_PATCHES=./zappacor-patches-$KERNEL_VERSION
ZAPPACOR_DOWNLOADS=./zappacor-downloads
ZAPPACOR_WORKDIR=./zappacor-work-dir


#####################################################
################## DOWNLOAD KERNEL ##################
#####################################################
mkdir -p $ZAPPACOR_DOWNLOADS
echo '### Kernel version: '$KERNEL_VERSION', downloading kernel'
wget -c -P $ZAPPACOR_DOWNLOADS $KERNEL_URL
mkdir -p $ZAPPACOR_WORKDIR
echo '### Kernel version: '$KERNEL_VERSION', extracting kernel'
tar xf $ZAPPACOR_DOWNLOADS/linux-$KERNEL_VERSION.tar.xz -C $ZAPPACOR_WORKDIR

####################################################
################## ADD BCE DRIVER ##################
####################################################
#   From: https://github.com/aunali1/mbp2018-bridge-drv.git (redirects to https://github.com/t2linux/apple-bce-drv)
#   Will show up as:
#   -> Device Drivers
#     -> Macintosh device drivers
#       -> Apple BCE driver (VHCI and Audio support)
# Download and decompress it
# echo '### Kernel version: '$KERNEL_VERSION', downloading BCE driver'
# wget -c -O $ZAPPACOR_DOWNLOADS/apple-bce.zip $DRIVER_BCE_URL
echo '### Kernel version: '$KERNEL_VERSION', extracting BCE driver'
unzip -d $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION/drivers/macintosh/ $ZAPPACOR_DOWNLOADS/apple-bce.zip -x '*/.gitignore'
mv $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION/drivers/macintosh/apple-bce-drv-aur $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION/drivers/macintosh/apple-bce

#########################################################
################## ADD IBRIDGE DRIVERS ##################
#########################################################
#   From: https://github.com/roadrunner2/macbook12-spi-driver
#   Will show up as (ToDo: add options to enable/disable apple-ib-tb and apple-ib-als independently):
#   -> Device Drivers
#     -> Macintosh device drivers
#       -> Apple iBridge driver (Touchbar and ALS support)
# Download and decompress it
# echo '### Kernel version: '$KERNEL_VERSION', downloading iBridge driver'
# wget -c -O $ZAPPACOR_DOWNLOADS/apple-ibridge.zip $DRIVER_IBRIDGE_URL
echo '### Kernel version: '$KERNEL_VERSION', extracting iBridge driver'
unzip -d $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION/drivers/macintosh/ $ZAPPACOR_DOWNLOADS/apple-ibridge.zip -x '*/.gitignore'
mv $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION/drivers/macintosh/macbook12-spi-driver-mbp15 $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION/drivers/macintosh/apple-ibridge

###################################################
################## APPLY PATCHES ##################
###################################################
# Ubuntu patches
#   From:
#     https://github.com/marcosfad/mbp-ubuntu-kernel/tree/master/patches
#   Excluded patches:
#     0004-debian-changelog.patch
#   Not creating:
#     custom-drivers.patch
############################################################
# SMC patches
#   From:
#     https://github.com/aunali1/linux-mbp-archaunali1/linux-mbp-arch
#   Excluded patches:
#     wifi.patch (not needed anymore)
#     000[0-9]* (excluded by marcosfad/mbp-ubuntu-kernel scripts, blindly doing the same):
#       0001-ZEN-Add-sysctl-and-CONFIG-to-disallow-unprivileged-C.patch
#       0002-virt-vbox-Add-support-for-the-new-VBG_IOCTL_ACQUIRE_.patch
############################################################
# BCE patches
#   Apply this patch to add a modalias to the driver so it can get loaded automatically when booting on a Mac
#     zappacor-patches-apple_bce-0.1.patch
############################################################
# IBRIDGE patches
#   Add this patchfor kernels v5.9
#     zappacor-patches-apple_ib_als-01.patch
############################################################
(ZAPPACOR_PATCHES=`readlink -f $ZAPPACOR_PATCHES`
 cd $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION
 # This patch on $ZAPPACOR_PATCHES is filtered out by the grep command on the following
 # line (just in case, since some folks told marcosfad it breaks their systems):
 #   2001-drm-amd-display-Force-link_rate-as-LINK_RATE_RBR2-fo.patch
 for PATCH_FILE in `ls -1 $ZAPPACOR_PATCHES/*.patch| grep -vE '[2]00[0-9]'`; do
  echo '### Kernel version: '$KERNEL_VERSION', applying patch '`basename $PATCH_FILE`
  # Use this line when checking the patches:
  #   echo 'patch --dry-run -p1 <'$ZAPPACOR_PATCHES/$PATCH_FILE
  # or this one when applying them:
  patch -p1 <$PATCH_FILE
 done
)

#################################################################
################## CONFIG AND BUILD THE KERNEL ##################
#################################################################
echo '### Kernel version: '$KERNEL_VERSION', building'
cd $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION
make clean
# Create a default kernel config 
sed 's/CONFIG_LOCALVERSION=.*/CONFIG_LOCALVERSION="-zappacor"/' /boot/config-`uname -r` >.config
make olddefconfig
# Build it
make -j$((`grep -c ^processor /proc/cpuinfo`*2)) all
cd -

######################################################################
################## LOCAL COMPUTER TEST/INSTALLATION ##################
######################################################################
cd $ZAPPACOR_WORKDIR/linux-$KERNEL_VERSION
# In case the headers were needed, run this:
#   make headers -j$((`grep -c ^processor /proc/cpuinfo`*2)) && make -j$((`grep -c ^processor /proc/cpuinfo`*2)) headers_install
# Install modules and kernel stripping them:
echo '### Kernel version: '$KERNEL_VERSION', installing modules'
make INSTALL_MOD_STRIP=1 -j$((`grep -c ^processor /proc/cpuinfo`*2)) modules_install
echo '### Kernel version: '$KERNEL_VERSION', installing kernel'
make INSTALL_MOD_STRIP=1 -j$((`grep -c ^processor /proc/cpuinfo`*2)) install
cd -
# Need this for the Broadcom WiFi on my *HP laptop* to work (these following steps are *not* related to any Mac at all)
# NOTE: this works for 5.8.18 but not for 5.9.8 (so using broadcom-sta instead of bcmwl-kernel-source until there is an updated version of the later)
#   echo '### Kernel version: '$KERNEL_VERSION', installing bcmwl-kernel-source (for the HP laptop, not related to any Mac)'
#   wget -c -P $ZAPPACOR_DOWNLOADS https://launchpad.net/ubuntu/+source/bcmwl/6.30.223.271+bdcom-0ubuntu7/+build/20102161/+files/bcmwl-kernel-source_6.30.223.271+bdcom-0ubuntu7_amd64.deb
#   apt install $ZAPPACOR_DOWNLOADS/bcmwl-kernel-source_6.30.223.271+bdcom-0ubuntu7_amd64.deb
echo '### Kernel version: '$KERNEL_VERSION', installing broadcom-sta-dkms (for the HP laptop, not related to any Mac)'
wget -c -P $ZAPPACOR_DOWNLOADS http://launchpadlibrarian.net/504153660/broadcom-sta-dkms_6.30.223.271-15_all.deb
apt purge bcmwl-kernel-source
apt install $ZAPPACOR_DOWNLOADS/broadcom-sta-dkms_6.30.223.271-15_all.deb

echo '### Kernel version: '$KERNEL_VERSION', done!'
