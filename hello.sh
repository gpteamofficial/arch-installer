#!/bin/bash
set -e

# ---------- Basic variables ----------
DISK="/dev/sda"
HOSTNAME="arch-vm"
TIMEZONE="UTC"
LOCALE="en_US.UTF-8"
KEYMAP="us"

# ---------- Partition disk ----------
echo "Partitioning disk..."
sgdisk --zap-all $DISK
sgdisk -n 1:0:+512M -t 1:ef00 $DISK       # EFI
sgdisk -n 2:0:0 -t 2:8300 $DISK           # Root

# ---------- Format partitions ----------
echo "Formatting partitions..."
mkfs.fat -F32 ${DISK}1
mkfs.ext4 ${DISK}2

# ---------- Mount partitions ----------
echo "Mounting partitions..."
mount ${DISK}2 /mnt
mkdir -p /mnt/boot
mount ${DISK}1 /mnt/boot

# ---------- Install base system ----------
echo "Installing base system..."
pacstrap /mnt base linux linux-firmware vim networkmanager

# ---------- Generate fstab ----------
echo "Generating fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

# ---------- chroot and configure system ----------
echo "Entering chroot..."
arch-chroot /mnt /bin/bash <<EOF
# ---------- Timezone ----------
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# ---------- Locale ----------
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# ---------- Network ----------
echo "$HOSTNAME" > /etc/hostname
cat <<EOL > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOL

# ---------- Bootloader ----------
pacman -S --noconfirm grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# ---------- Set root password ----------
echo "root:archroot" | chpasswd
EOF

# ---------- Unmount and finish ----------
umount -R /mnt
echo "Installation complete! Reboot now."
