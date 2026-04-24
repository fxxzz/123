#!/bin/bash

set -e
trap 'echo "Error on line $LINENO. Script aborted."; exit 1' ERR

echo "1. Partitioning and formatting /dev/vda..."

swapoff -a
umount -R /mnt

echo -e "label: gpt\nsize=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B, name=boot\ntype=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709, name=root" | sfdisk /dev/vda

partprobe /dev/vda

mkfs.fat -F 32 -n BOOT /dev/vda1
mkfs.ext4 -F -L root /dev/vda2

mount /dev/vda2 /mnt
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot

echo "2. Installing base system..."
pacstrap -K /mnt base linux openssh sudo
genfstab -U /mnt >> /mnt/etc/fstab

echo "3. Preparing chroot script..."
cat > /mnt/setup_inside.sh << 'CHROOT_EOF'
set -e

systemctl enable systemd-networkd sshd

mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-ethernet.network << 'EOF'
[Match]
Name=en* eth*
[Network]
DHCP=ipv4
Address=2a03:4000:27:f0d::1/64
Gateway=fe80::1
DNS=1.1.1.1
DNS=2606:4700:4700::1111
EOF

bootctl install

cat > /boot/loader/loader.conf << 'EOF'
default arch.conf
timeout 3
editor no
EOF

cat > /boot/loader/entries/arch.conf << 'EOF'
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=PARTLABEL=root rw
EOF

mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
CHROOT_EOF

echo "4. Entering chroot environment..."
chmod +x /mnt/setup_inside.sh
arch-chroot /mnt /bin/bash /setup_inside.sh

cat > /mnt/etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
EOF

echo "5. Finalizing installation..."
rm /mnt/setup_inside.sh
sync
umount -R /mnt
sleep 5
reboot
