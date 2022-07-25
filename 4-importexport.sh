#!/bin/bash

# The purpose of this script is to mount/unmount ZFS pool
# along with all mounts for chrooting purposes (like for
# example: to fix something)

# TODO: Needs to check for environment variables being set

DISK="/dev/disk/by-id/${DISK_NAME}"

mount_partitions() {

    # ORDER OF OPERATIONS HERE IS IMPORTANT!
    echo -e "\nMounting Partitions"
    zpool import -N -R /mnt "${1}"
    zfs mount "${1}/ROOT/root"
    zfs mount "${1}/DATA/home"
    mount "${2}-part1" /mnt/boot/efi
    df -h -t zfs

}

unmount_partitions() {

    # ORDER OF OPERATIONS HERE IS IMPORTANT!
    echo -e "\nUnmounting partitions..."
    umount /mnt/boot/efi
    zfs umount "${1}/DATA/home"
    zfs umount "${1}/ROOT/root"
    zpool export ${1}

}

case "$1" in
    mount)
        mount_partitions "${POOL_NAME}" "${DISK}";;
    unmount)
        unmount_partitions "${POOL_NAME}";;
    *)
        echo -e "ERROR: Bad syntax. Usage:\n"
        echo -e " - ./4-importexport.sh mount"
        echo -e "       Mounts zfs "
        echo -e " - ./4-importexport.sh unmount"
        echo -e "ERROR: Bad syntax. Usage:\n"

        exit 1
esac