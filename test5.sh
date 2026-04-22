#!/bin/bash

set -e
trap 'echo "Error on line $LINENO. Script aborted."; exit 1' ERR

echo "1. Partitioning and formatting /dev/vda..."
wipefs -a /dev/vda
sgdisk --zap-all /dev/vda

echo -e "label: gpt\nsize=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\ntype=4F68BCE3-E8CD-4DB1-96E7-FBCAF984B709" | sfdisk /dev/vda

partprobe /dev/vda
sleep 2

mkfs.fat -F 32 /dev/vda1
mkfs.ext4 -F /dev/vda2

mount /dev/vda2 /mnt
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot

echo "2. Installing base system..."
pacstrap -K /mnt base linux linux-firmware openssh reflector grub efibootmgr vim wget sudo htop cronie base-devel curl
genfstab -U /mnt >> /mnt/etc/fstab

echo "3. Preparing chroot script..."
cat > /mnt/setup_inside.sh << 'CHROOT_EOF'
set -e

systemctl enable systemd-networkd systemd-resolved

awk 'BEGIN { print "nameserver 1.1.1.1" }' > /etc/resolv.conf

echo "arch" > /etc/hostname
ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime
ln -sf /usr/bin/vim /usr/bin/vi

sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-ethernet.network << 'EOF'
[Match]
Name=en*
Name=eth*
[Network]
DHCP=ipv4
Address=2a03:4000:27:f0d::1/64
Gateway=fe80::1
DNS=1.1.1.1
EOF

mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf << 'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--sort rate
--country 'United States'
--latest 20
-n 10
EOF

systemctl enable sshd cronie reflector.timer

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "root:XXZZea" | chpasswd
sed -i 's/^#\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config
sed -i 's/^#\(PasswordAuthentication\).*/\1 yes/' /etc/ssh/sshd_config

mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
CHROOT_EOF

echo "4. Entering chroot environment..."
chmod +x /mnt/setup_inside.sh

umount /etc/resolv.conf || true

arch-chroot /mnt /bin/bash /setup_inside.sh

echo "5. Finalizing installation..."
rm /mnt/setup_inside.sh
sync
umount -R /mnt
sleep 5
reboot
