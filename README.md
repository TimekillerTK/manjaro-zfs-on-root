# Manjaro ZFS-on-Root
This project contains a bunch of scripts which should be executed in sequence to install and configure Manjaro for ZFS-on-root on a target disk of choice.

* `1-partitions-zfs.sh`
  * Partitions your disk, creates a ZFS pool and datasets, then mounts them in preparation for the next steps
* `2-basestrap.sh`
  * Uses manjaro [iso-profiles](https://gitlab.manjaro.org/profiles-and-settings/iso-profiles.git "${WORK_DIR}/git/iso-profiles") to basestrap manjaro on the ZFS partition
  * Also sets up `/etc/fstab` for your installation and sets up `3-chroot.sh`
* `3-chroot.sh`
  * To be run while chooted into the target installation (self destructs after running)
  * Does many things:
    * regenerates initramfs
    * generates grub install & config
    * enables ZFS services
    * enables desktop environment
    * generates hostid
    * sets keyboard layout
    * generates locale
    * sets clock
    * sets hostname
    * sets `/etc/hosts`
    * creates `wheel` group
    * enables networking
    * enables time synchronization
    * sets temporary user and root passwords
* `4-importexport.sh`
  * helper script which mounts/unmounts your ZFS pool and datasets. Also mount/unmounts your efi partition
* `5-post-reboot.sh` (optional)
  * Executes a bunch of recommended things such as:
    * Enable auto ZFS scrub
    * Auto & manual trimming for SSDs
    * to be continued ...

## Requirements
In order to use this project, you **must** have a bootable version of Manjaro on your installation  media with ZFS-modules loaded.

## How to use
Make sure you set the following environment variables prior to running any scripts. You can do this by creating a small shell script like this with your own values:
```sh
#!/bin/bash
export WORK_DIR="/root"
export POOL_NAME="mypoolname"
export DISK_NAME="mydiskname" # locate your disk ID by doing `ls /dev/disk/by-id` 
export LOCALE_GEN="en_US.UTF-8 UTF-8"
export KEYMAP="us"
export TIMEZONE="Europe/Amsterdam"
export CREATE_USER="user"
export USER_PW="abcabc12345"
export ROOT_PW="abcabc54321"
echo "Variables set!"
```



