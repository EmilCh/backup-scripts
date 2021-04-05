#!/usr/bin/bash

# Backup script for backing up all local disks to a USB disk.
#
# This asumes all disk are already mounted in /disks/Disk1 /disks/Disk2 etc, 
# formated using BTRFS filesystem and subvolumes are mounted on the system.
# The subvolumes names start with @ sign (default on Arch and Manjaro)
# MOUNTPOINT is where the external disk (connected thru USB) is mounted during backup
# Backups are being done using borg backup utility ( https://www.borgbackup.org/ )
# 

LOCATION="/disks"
BORG_REPO="/disks/mountpoint/repository"
MOUNTPOINT="/disks/mountpoint"
PREFIX=`/usr/bin/date +%Y%m%d%H`

DISKS="Disk1 Disk2 Disk3"
UUID_USB="000-000000-000-0000-0000"
export BORG_PASSPHRASE="SecretPass"

# When using swapfile we cannot create snapshot of the filesystem where the swapfile is.
swapoff -a

mount UUID=$UUID_USB $MOUNTPOINT
cd $LOCATION
for disk in $DISKS;
do
    cd $disk
     for subvol in @*
     do
         btrfs subvolume snapshot $subvol snapshots/$PREFIX-$subvol;
         borg create --progress $BORG_REPO::$PREFIX-$subvol snapshots/$PREFIX-$subvol
         # we could also delete the snapshot after backing it up:
         # btrfs subvolume delete snapshots/$PREFIX-$subvol;
     done
    cd ..
done

# re-activate the swapfile
# If the root filesystem has compression activated then all this is needed to 
# re-activate the swapfile
truncate -s 0 /swapfile
chattr +C /swapfile
fallocate -l 16G /swapfile
mkswap /swapfile
swapon -a

echo "starting integrity check..."
borg check --verify-data $BORG_REPO
echo "pruning backups..."
borg prune --keep-last 5 $BORG_REPO

umount $MOUNTPOINT
