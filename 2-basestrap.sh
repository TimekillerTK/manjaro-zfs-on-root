#!/bin/bash

# Set working directory

# Check if git is installed & clone repository
mkdir -p "${WORK_DIR}/git/iso-profiles"
mkdir "${WORK_DIR}/temp"
if [[ -d "${WORK_DIR}/git/iso-profiles" ]]; then
    echo "Directory ${WORK_DIR}/git/iso-profiles already exists, pulling latest changes"
    cd "${WORK_DIR}/git/iso-profiles" && git pull
else
    git clone https://gitlab.manjaro.org/profiles-and-settings/iso-profiles.git "${WORK_DIR}/git/iso-profiles"
fi

# Copy list of packages required for basestrap to temp folder
# What needs to be stripped and combined
# Packages-Root:
# - Remove lines starting with #
# - Remove lines starting with > 
# - Replace KERNEL with linux515
# - Add package         linux515-zfs
# Packages-Desktop:
# - Remove lines starting with #
# - Remove lines starting with > 
# - Filter out only first word on each line
packages=("Packages-Root" "Packages-Desktop")
for i in "${packages[@]}"; do
    cp "${WORK_DIR}/git/iso-profiles/manjaro/kde/${i}" "${WORK_DIR}/temp/${i}"
    sed -i '/^#/d' "${WORK_DIR}/temp/${i}"
    sed -i '/^>/d' "${WORK_DIR}/temp/${i}"
    sed -i 's/KERNEL/linux515/g' "${WORK_DIR}/temp/${i}"
    sed -i '/linux515/a linux515-zfs' "${WORK_DIR}/temp/${i}"
    sed -i '/linux515-zfs/a zfs-utils' "${WORK_DIR}/temp/${i}"
    sed -i '/^[[:blank:]]*$/ d' "${WORK_DIR}/temp/${i}"
    # Put first column from both files and append to file
    awk '{print $1}' "${WORK_DIR}/temp/${i}" >> "${WORK_DIR}/temp/packages"
done

# Install packages with basestrap
PACKAGES_ARRAY=($(cat ${WORK_DIR}/temp/packages))
echo -e "\nPackages to basestrap into installation:\n${PACKAGES_ARRAY[@]}"
read -e -p "Continue & basestrap installation? (y/n): " ANSWER
case $ANSWER in
    y)
        echo "Basestrapping generated packages for installation...";;
    *)
        echo "Cancelling process.."
        exit 1;;
esac
unset ANSWER

basestrap /mnt "${PACKAGES_ARRAY[@]}"

# Extra Necessary steps in case of error while basestrapping
# pacman-key --refresh-keys
# pacman -Syu
#    this fixes not being able to basestrap

read -e -p "Basestrap completed. Continue? (y/n): " ANSWER
case $ANSWER in
    y)
        echo "Continuing process...";;
    *)
        echo "Cancelling process.."
        exit 1;;
esac
unset ANSWER
# Afterwards copy settings from desktop-overlay folder
echo -e "\nCopying desktop-overlay settings"
cp -r ${WORK_DIR}/git/iso-profiles/manjaro/kde/desktop-overlay/* /mnt

# Set variables used in next steps
DISK_DEV="/dev/$(ls -l /dev/disk/by-id/ | grep -i "${DISK_NAME}" | head -1 | cut -d "/" -f3)"
UUID_EFI=$(blkid | grep "${DISK_DEV}1" | awk '{print $2}')
UUID_SWAP=$(blkid | grep "${DISK_DEV}3" | awk '{print $2}')

# Setting created partitions in /etc/fstab
# TODO: Remove quotes from UUID_EFI and UUID_SWAP
echo -e "\nModifying /etc/fstab with boot and swap partitions"
echo "${UUID_EFI}   /boot   vfat    defaults    0   0" >> /mnt/etc/fstab
echo "${UUID_SWAP}  none    swap    defaults    0   0" >> /mnt/etc/fstab

# Modify mkinitcpio.conf for ZFS
# ZFS should be AFTER keyboard and BEFORE filesystem in HOOKS
# fsck only needed for non-zfs filesystems
echo "Modifying HOOKS for ZFS"
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block keyboard zfs filesystems)/g' /mnt/etc/mkinitcpio.conf

# Copy 3-chroot.sh to /mnt/root to be ran only while chrooted
echo -e "\nPreparing 3-chroot.sh for chrooted environment..."
echo '#!/bin/bash' >> /mnt/root/3-chroot.sh
echo -e "DISK_DEV=${DISK_DEV}" >> /mnt/root/3-chroot.sh
# Add LOCALE_GEN, KEYMAP, TIMEZONE &  variables set by 0-set_vars.sh
echo -e "TIMEZONE=${TIMEZONE}" >> /mnt/root/3-chroot.sh
echo -e "LOCALE_GEN=\"${LOCALE_GEN}\"" >> /mnt/root/3-chroot.sh
echo -e "KEYMAP=${KEYMAP}" >> /mnt/root/3-chroot.sh
echo -e "CREATE_USER=${CREATE_USER}" >> /mnt/root/3-chroot.sh
echo -e "USER_PW=${USER_PW}" >> /mnt/root/3-chroot.sh
echo -e "ROOT_PW=${ROOT_PW}" >> /mnt/root/3-chroot.sh

cat ${WORK_DIR}/git/manjaro_neko/3-chroot.sh >> /mnt/root/3-chroot.sh

echo "... Done! Now chroot into your installation with:"
echo " - manjaro-chroot /mnt /bin/bash"
echo -e "\nAnd execute /root/3-chroot.sh"