#!/bin/bash

# Colours
YELLOW='\033[33m'
GREEN='\033[32m'
BLUE='\033[34m'
NC='\033[0m' # No Color

# Bash function to check whether a package is installed
check_package () {
  # Setting a variable local to function
  local array=()
  for item in "$@"; do
    local CHECK=$(command -v "$item")
    if [ -z "$CHECK" ]; then
      array+=("$item")
    fi
  done
  # If array is not empty:
  if [ -n "$array" ]; then
    echo -e "${YELLOW}ERROR: The following required packages are not installed:"
    for val in "${array[@]}"; do
      echo "- $val"
    done
    echo -e "\nInstall them using hyour system package manager (linux)${NC}"
    return 1
  fi
}

check_variable () {
  # Setting a variable local to function
  local array=()
  for item in "$@"; do
    if [ -z "$item" ]; then
      array+=("$item")
    fi
  done
  # If array is not empty:
  if [ -n "$array" ]; then
    echo -e "${YELLOW}ERROR: The following required environment variables are not set:"
    for val in "${array[@]}"; do
      echo "- $val"
    done
    echo -e "\nSet these environment variables with \"export VARIABLE_NAME='variable value'\" and rerun the script.${NC}"
    return 1
  fi
}

# TODO: 
# Required tools for installation:
# dosfstools (mkfs vfat)
check_package zfs zpool git
# Exit script, if function does not return code 0
if ! [ $? = 0 ]; then
    exit 1
fi


# TODO: Check if zfs modules are loaded

# Variables used here are set in 0-set_vars.sh
check_variable WORK_DIR POOL_NAME DISK_NAME  LOCALE_GEN KEYMAP TIMEZONE CREATE_USER USER_PW ROOT_PW
# Exit script, if function does not return code 0
if ! [ $? = 0 ]; then
    exit 1
fi

DISK="/dev/disk/by-id/${DISK_NAME}"


# Prompt here for user input!!!
read -e -p "WARNING!!! Will wipe partition table of disk ${DISK} and create partitions. Continue? (y/n): " ANSWER
case $ANSWER in
    y)
        echo "Wiping partition table and creating partitions...";;
    *)
        echo "Cancelling process.."
        exit 1;;
esac
unset ANSWER

# TODO: prompt asking to continue because disk exists (?)
# Delete the ZFS Pool Name if it exists first so there are no interruptions
# zpool import -N -R /mnt "${POOL_NAME}"
# zpool destroy "${POOL_NAME}"

# This option will clear a disk completely (TEST THIS! - it works)
echo -e "\nClearing partitions..."
sgdisk -o "$DISK"

echo -e "\nCreating EFI partition..."
sgdisk --new 1::+512M --typecode 1:EF00 --change-name=1:"EFI system partition" "$DISK"

echo -e "\nCreating ZFS partition..."
sgdisk --new 2::+915G --typecode 2:BF00 --change-name=2:"Solaris root" "$DISK"

echo -e "\nCreating Linux Swap..."
sgdisk --new 3::+16G --typecode 3:8200 --change-name=3:"Linux swap" "$DISK"
echo ""
sgdisk -p "${DISK}"
echo ""

# Prompt here for user input!!!
read -e -p "Will create ZFS pool on partition 2. Continue? (y/n): " ANSWER
case $ANSWER in
    y)
        echo "Creating ZFS pool ${POOL_NAME} on partition ${DISK}-part2...";;
    *)
        echo "Cancelling process.."
        exit 1;;
esac
unset ANSWER

# This will create a new zpool
zpool create -f -o ashift=12          \
            -O acltype=posixacl       \
            -O relatime=on            \
            -O xattr=sa               \
            -O mountpoint=none        \
            -O canmount=off           \
            -O devices=off            \
            -R /mnt                   \
            -O compression=lz4        \
            "${POOL_NAME}" "${DISK}-part2"

if ! zpool list; then
  echo "Error creating zpool..."
  exit 1
fi

# Creating ZFS datasets
zfs create -o mountpoint=none "${POOL_NAME}/DATA"
zfs create -o mountpoint=none "${POOL_NAME}/ROOT"
zfs create -o mountpoint=/ -o canmount=noauto "${POOL_NAME}/ROOT/root"
zfs create -o mountpoint=/home "${POOL_NAME}/DATA/home"
echo -e "\nZFS Datasets created:"
zfs list

# Export pool to 'remember' the changes
echo -e "\nExporting and re-importing pool ${POOL_NAME} "
zpool export "${POOL_NAME}"
zpool import -N -R /mnt "${POOL_NAME}"

# Mount the ZFS Filesystem
echo -e "\nMounting created ZFS Datasets"
zfs mount "${POOL_NAME}/ROOT/root"
zfs mount "${POOL_NAME}/DATA/home"

# Lists ZFS mounts
df -h -t zfs

# Exit script, if previous command does not return code 0
if ! [ $? = 0 ]; then
  exit 1
fi

# Prompt here for user input!!!
read -e -p "Format EFI partition ${DISK}-part1. Continue? (y/n): " ANSWER
case $ANSWER in
    y)
        echo "Formatting EFI partition ${DISK}-part1 & mounting to /mnt/boot/efi ...";;
    *)
        echo "Cancelling process.."
        exit 1;;
esac
unset ANSWER

# Format the EFI Partition & mount (for GRUB)
mkfs.vfat "${DISK}-part1"
mkdir -p /mnt/boot/efi
mount "${DISK}-part1" /mnt/boot/efi


# Set bootfs property on ZFS pool & datasets
echo -e "\nSetting bootfs property on ZFS pool ${POOL_NAME} for dataset:"
echo -e " - ${POOL_NAME}/ROOT/root"
zpool set bootfs="${POOL_NAME}/ROOT/root" "${POOL_NAME}"
zpool set cachefile=/etc/zfs/zpool.cache "${POOL_NAME}"
mkdir -p /mnt/etc/zfs
echo -e "\nCopying generated zpool cache file to /mnt/etc/zfs/zpool.cache"
cp /etc/zfs/zpool.cache /mnt/etc/zfs/zpool.cache
