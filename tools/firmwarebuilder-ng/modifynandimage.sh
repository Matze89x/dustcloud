#!/bin/bash
# Author: Dennis Giese [dgiese@dontvacuum.me]
# Copyright 2017 by Dennis Giese

BASE_DIR="."
FLAG_DIR="."
IMG_DIR="./squashfs-root"
FEATURES_DIR="./features"

if [ ! -f $BASE_DIR/firmware.zip ]; then
    echo "File firmware.zip not found! Decryption and unpacking was apparently unsuccessful."
    exit 1
fi

if [ ! -f $BASE_DIR/authorized_keys ]; then
    echo "authorized_keys not found"
    exit 1
fi

if [ ! -f $FLAG_DIR/devicetype ]; then
    echo "devicetype definition not found, aborting"
    exit 1
fi

DEVICETYPE=$(cat "$FLAG_DIR/devicetype")
FRIENDLYDEVICETYPE=$(sed "s/\[s|t\]/x/g" $FLAG_DIR/devicetype)
version=$(cat "$FLAG_DIR/version")

mkdir -p $BASE_DIR/output


unzip $BASE_DIR/firmware.zip
mv $BASE_DIR/rootfs.img $BASE_DIR/rootfs.img.template
unsquashfs -d $IMG_DIR $BASE_DIR/rootfs.img.template
mkdir -p $IMG_DIR/etc/dropbear
chown root:root $IMG_DIR/etc/dropbear
cat $BASE_DIR/dropbear_rsa_host_key > $IMG_DIR/etc/dropbear/dropbear_rsa_host_key
cat $BASE_DIR/dropbear_dss_host_key > $IMG_DIR/etc/dropbear/dropbear_dss_host_key
cat $BASE_DIR/dropbear_ecdsa_host_key > $IMG_DIR/etc/dropbear/dropbear_ecdsa_host_key
cat $BASE_DIR/dropbear_ed25519_host_key > $IMG_DIR/etc/dropbear/dropbear_ed25519_host_key

echo "disable SSH firewall rule"
sed -i -e '/    iptables -I INPUT -j DROP -p tcp --dport 22/s/^/#/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/watchdog/WatchDoge
sed -i -E 's/dport 22/dport 29/g' $IMG_DIR/opt/rockrobo/rrlog/rrlogd

echo "reverting rr_login"
sed -i -E 's/::respawn:\/sbin\/rr_login -d \/dev\/ttyS0 -b 115200 -p vt100/::respawn:\/sbin\/getty -L ttyS0 115200 vt100/g' $IMG_DIR/etc/inittab

echo "integrate SSH authorized_keys"
mkdir $IMG_DIR/root/.ssh
chmod 700 $IMG_DIR/root/.ssh
cat $BASE_DIR/authorized_keys > $IMG_DIR/root/.ssh/authorized_keys
cat $BASE_DIR/authorized_keys > $IMG_DIR/etc/dropbear/authorized_keys
chmod 600 $IMG_DIR/root/.ssh/authorized_keys
chmod 600 $IMG_DIR/etc/dropbear/authorized_keys
chown root:root $IMG_DIR/root -R

echo "replacing dropbear"
md5sum $IMG_DIR/usr/sbin/dropbear
install -m 0755 $FEATURES_DIR/dropbear_rr22/dropbear $IMG_DIR/usr/sbin/dropbear
install -m 0755 $FEATURES_DIR/dropbear_rr22/dbclient $IMG_DIR/usr/bin/dbclient
install -m 0755 $FEATURES_DIR/dropbear_rr22/dropbearkey $IMG_DIR/usr/bin/dropbearkey
install -m 0755 $FEATURES_DIR/dropbear_rr22/scp $IMG_DIR/usr/bin/scp
md5sum $IMG_DIR/usr/sbin/dropbear

md5sum $IMG_DIR/opt/rockrobo/miio/miio_client
if grep -q "ots_info_ack" $IMG_DIR/opt/rockrobo/miio/miio_client; then
	echo "found OTS version of miio client, replacing it with 3.5.8"
     cp $FEATURES_DIR/miio_clients/3.5.8/miio_client $IMG_DIR/opt/rockrobo/miio/miio_client
fi
md5sum $IMG_DIR/opt/rockrobo/miio/miio_client


if [ -f $FLAG_DIR/adbd ]; then
    echo "replace adbd"
    install -m 0755 $FEATURES_DIR/adbd $IMG_DIR/usr/bin/adbd
fi

echo "install iptables modules"
    mkdir -p $IMG_DIR/lib/xtables/
    cp $FEATURES_DIR/iptables/xtables/*.* $IMG_DIR/lib/xtables/
    cp $FEATURES_DIR/iptables/ip6tables $IMG_DIR/sbin/


if [ -f $FLAG_DIR/tools ]; then
    echo "installing tools"
    cp -r $FEATURES_DIR/rr_tools/root-dir/* $IMG_DIR/
fi

if [ -f $FLAG_DIR/patch_logging ]; then
    echo "patch logging"
    echo "patch upload stuff"
    # UPLOAD_METHOD=0 (no upload)
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(UPLOAD_METHOD=)([0-9]+)/\10/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Set LOG_LEVEL=3
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlog.conf
    sed -i -E 's/(LOG_LEVEL=)([0-9]+)/\13/' $IMG_DIR/opt/rockrobo/rrlog/rrlogmt.conf

    # Reduce logging of miio_client
    sed -i 's/-l 2/-l 0/' $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf

    # Let the script cleanup logs
    sed -i 's/nice.*//' $IMG_DIR/opt/rockrobo/rrlog/tar_extra_file.sh

    # Disable collecting device info to /dev/shm/misc.log
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/misc.sh

    # Disable logging of 'top'
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/toprotation.sh
    sed -i '/^\#!\/bin\/bash$/a exit 0' $IMG_DIR/opt/rockrobo/rrlog/topstop.sh
    echo "patch watchdog log"
    # Disable watchdog log
    # shellcheck disable=SC2016
    sed -i -E 's/\$RR_UDATA\/rockrobo\/rrlog\/watchdog.log/\/dev\/null/g' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
fi

if [ -f $FLAG_DIR/patch_dns ]; then
	echo "patching DNS"
	sed -i -E 's/110.43.0.83/127.000.0.1/g' $IMG_DIR/opt/rockrobo/miio/miio_client
	sed -i -E 's/110.43.0.85/127.000.0.1/g' $IMG_DIR/opt/rockrobo/miio/miio_client
	sed -i 's/dport 22/dport 27/' $IMG_DIR/opt/rockrobo/watchdog/rrwatchdoge.conf
	cat $FEATURES_DIR/valetudo/deployment/etc/hosts-local > $IMG_DIR/etc/hosts
fi

if [ -f $FLAG_DIR/hostname ]; then
echo "patching Hostname"
	cat $FLAG_DIR/hostname > $IMG_DIR/etc/hostname
fi

mkdir -p $IMG_DIR/etc/hosts-bind
mv $IMG_DIR/etc/hosts $IMG_DIR/etc/hosts-bind/
ln -s /etc/hosts-bind/hosts $IMG_DIR/etc/hosts

sed -i "s/^exit 0//" $IMG_DIR/etc/rc.local
echo "if [[ -f /mnt/reserve/_root.sh ]]; then" >> $IMG_DIR/etc/rc.local
echo "    /mnt/reserve/_root.sh &" >> $IMG_DIR/etc/rc.local
echo "fi" >> $IMG_DIR/etc/rc.local
echo "exit 0" >> $IMG_DIR/etc/rc.local

install -m 0755 $FEATURES_DIR/valetudo/deployment/S10rc_local_for_nand $IMG_DIR/etc/init/S10rc_local

install -m 0755 $FEATURES_DIR/fwinstaller_nand/_root.sh.tpl $IMG_DIR/root/_root.sh.tpl
install -m 0755 $FEATURES_DIR/fwinstaller_nand/how_to_modify.txt $IMG_DIR/root/how_to_modify.txt

touch $IMG_DIR/build.txt
echo "build with dustcloud builder (https://github.com/dgiese/dustcloud)" > $IMG_DIR/build.txt
date -u  >> $IMG_DIR/build.txt
echo "" >> $IMG_DIR/build.txt

echo "finished patching, repacking"

if [ -f $FLAG_DIR/fel ]; then
    echo "create smaller package for fel"
	rm -rf $IMG_DIR/opt/rockrobo/cleaner
	rm -rf $IMG_DIR/opt/rockrobo/rriot
	rm -rf $IMG_DIR/usr/share/zoneinfo
	echo "#name,cmd,keyprocess,killtimeout,startdelay" > $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf
    echo "wlanmgr,setsid wlanmgr&,0,3,0" >> $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf
    echo "miio_client,setsid miio_client -d /mnt/data/miio -l 2 >> /mnt/data/rockrobo/rrlog/miio.log 2>&1&,0,1,0" >> $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf
	cat $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf > $IMG_DIR/opt/rockrobo/watchdog/ProcessListMT.conf
	cat $IMG_DIR/opt/rockrobo/watchdog/ProcessList.conf > $IMG_DIR/opt/rockrobo/watchdog/ProcessListFR.conf
fi

mksquashfs $IMG_DIR/ rootfs_tmp.img -noappend -root-owned -comp gzip -b 128k
rm -rf $IMG_DIR
dd if=$BASE_DIR/rootfs_tmp.img of=$BASE_DIR/rootfs.img bs=128k conv=sync
rm $BASE_DIR/rootfs_tmp.img
md5sum ./*.img > $BASE_DIR/firmware.md5sum

echo "check image file size"
maximumsize=26000000
minimumsize=10000000
actualsize=$(wc -c < $BASE_DIR/rootfs.img)
if [ "$actualsize" -ge "$maximumsize" ]; then
	echo "(!!!) rootfs.img looks to big. The size might exceed the available space on the flash."
	exit 1
fi

if [ "$actualsize" -le "$minimumsize" ]; then
	echo "(!!!) rootfs.img looks to small. Maybe something went wrong with the image generation."
	exit 1
fi

sed "s/DEVICEMODEL=.*/DEVICEMODEL=\"${DEVICETYPE}\"/g" $FEATURES_DIR/fwinstaller_nand/install.sh > install.sh
chmod +x install.sh
tar -czf $BASE_DIR/output/${FRIENDLYDEVICETYPE}_${version}_fw.tar.gz $BASE_DIR/rootfs.img $BASE_DIR/boot.img $BASE_DIR/firmware.md5sum $BASE_DIR/install.sh
md5sum $BASE_DIR/output/${FRIENDLYDEVICETYPE}_${version}_fw.tar.gz > $BASE_DIR/output/md5.txt
echo "${FRIENDLYDEVICETYPE}_${version}_fw.tar.gz" > $BASE_DIR/filename.txt
touch $BASE_DIR/server.txt

if [ -f $FLAG_DIR/diff ]; then
	echo "unpack original"
	unsquashfs -d $BASE_DIR/original $BASE_DIR/rootfs.img.template
	echo "unpack modified"
	unsquashfs -d $BASE_DIR/modified $BASE_DIR/rootfs.img

	/usr/bin/git diff --no-index $BASE_DIR/original/ $BASE_DIR/modified/ > $BASE_DIR/output/diff.txt
	rm -rf $BASE_DIR/original
	rm -rf $BASE_DIR/modified

fi

touch $BASE_DIR/output/done


