
# ^^^ DISK_DEV must be set above this line ^^^
# ONLY RUN THIS SCRIPT IN A CHROOTED ENVIRONMENT
# RUN 2-basestrap.sh FIRST!!!

# Regenerate the initramfs after changes done with 2-basestrap.sh
echo "Regenerating the initramfs"
mkinitcpio -P

# Run grub install and grub mkconfig
echo "Performing grub-install and grub-mkconfig"
ZPOOL_VDEV_NAME_PATH=1 grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Manjaro
# (if below not done, will get error "SPARSE FILE NOT ALLOWED")
# GRUB_DEFAULT=0
# GRUB_SAVEDEFAULT=false
sed -i 's/GRUB_DEFAULT=saved/GRUB_DEFAULT=0/g' /etc/default/grub
sed -i 's/GRUB_SAVEDEFAULT=true/GRUB_SAVEDEFAULT=false/g' /etc/default/grub
ZPOOL_VDEV_NAME_PATH=1 grub-mkconfig -o /boot/grub/grub.cfg

# above may not be needed, but added just in case
# grub-mkconfig -o /boot/grub/grub.cfg

echo "Enabling necessary services for automatically mounting zfs datasets..."
systemctl enable zfs.target
systemctl enable zfs-import-cache
systemctl enable zfs-mount
systemctl enable zfs-import.target

echo "Enabling Desktop Environment"
systemctl enable sddm.service

echo "Generating HostID"
zgenhostid $(hostid) 

echo "=================================="
echo -e "\nConfiguring other user settings..."

# TODO: This still needs to be done
echo " - setting keyboard settings..."
# Source: /usr/share/kbd/keymaps
# THIS SECTION NEEDS ATTENTION! SET MANUALLY FOR NOW
# KEYMAP=$KEYMAP
# FONT=
# FONT_MAP=
read -e -p "WARNING. Locale Gen issue previously... Check /etc/locale.gen for ${LOCALE_GEN} first! Continue? (y/n): " ANSWER
case $ANSWER in
    y)
        echo "Continuing process...";;
    *)
        echo "Cancelling process.."
        exit 1;;
esac
unset ANSWER
echo " - setting locale"
sed -i -e "/$LOCALE_GEN/s/^#//" /etc/locale.gen # NOTE: this will generate US locale TWICE
locale-gen 
echo "LANG=$(echo $LOCALE_GEN | cut -d ' ' -f1)" > /etc/locale.conf # NOTE: may not work for all languages


echo " - setting timezone and clock"
# Source: /usr/share/zoneinfo/
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc --utc

echo " - setting hostname"
echo "manjaro" > /etc/hostname

echo " - setting /etc/hosts"
cat <<EOF | tee /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    manjaro.localdomain manjaro
EOF

echo " - creating wheel group"
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/10-wheel

echo " - setting up NetworkManager"
systemctl enable NetworkManager

echo " - enabling time synchroniztion"
systemctl enable systemd-timesyncd

echo " - setting root password"
sh -c "echo root:${ROOT_PW} | chpasswd"
# NOTE: Set root password here, find a method of automating this

echo "Creating user for the system: ${CREATE_USER}"
useradd -m -G lp,network,power,sys,wheel -s /bin/bash "${CREATE_USER}"
sh -c "echo ${CREATE_USER}:${USER_PW} | chpasswd"
# NOTE: Set root password here, find a method of automating this

echo "... Done! Now, exit the chroot environment!"
# Self destruct so that passwords/other settings aren't left on the filesystem
rm -f /root/3-chroot.sh