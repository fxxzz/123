#!/bin/bash

set -e
trap 'echo "出现错误，脚本已终止。"; exit 1' ERR

echo "--- 1. 配置宿主机环境 ---"
echo "root:XXZZea" | passwd --stdin root <<EOF
XXZZea
XXZZea
EOF
# 适配 Live ISO 的 SSH 开启方式
sed -i 's/^#\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config
systemctl restart sshd

echo "--- 2. 自动化分区与格式化 ---"
wipefs -a /dev/vda
sgdisk --zap-all /dev/vda

# 修正后的分区命令：1G EFI, 剩余 Root
echo -e "label: gpt\nsize=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\ntype=4F68BCE3-E8CD-4DB1-96E7-FBCAF974B709" | sfdisk /dev/vda

partprobe /dev/vda
sleep 2
mkfs.fat -F 32 /dev/vda1
mkfs.ext4 -F /dev/vda2

mount /dev/vda2 /mnt
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot

echo "--- 3. 基础系统安装 ---"
pacstrap -K /mnt base linux linux-firmware openssh reflector grub efibootmgr vim wget sudo htop cronie base-devel curl
genfstab -U /mnt >> /mnt/etc/fstab

echo "--- 4. 写入 Chroot 配置脚本 ---"
# 确保这里的内容完整闭合
cat > /mnt/setup_inside.sh << 'CHROOT_EOF'
set -e

# 基础服务
systemctl enable systemd-networkd

# 基础设置
echo "arch" > /etc/hostname
ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime
ln -sf /usr/bin/vim /usr/bin/vi

# Locale
sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# 网络配置 (直接在网卡配置里指定 DNS，不碰 resolv.conf)
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

systemctl enable sshd cronie

# === 引导安装 (关键部分) ===
# --removable 参数对 VPS 至关重要，防止引导项丢失
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# 账户权限
echo "root:XXZZea" | chpasswd
sed -i 's/^#\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config
sed -i 's/^#\(PasswordAuthentication\).*/\1 yes/' /etc/ssh/sshd_config

# SSH Key 注入
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
CHROOT_EOF

echo "--- 5. 执行内部配置 ---"
chmod +x /mnt/setup_inside.sh
arch-chroot /mnt /bin/bash /setup_inside.sh

echo "--- 6. 清理并重启 ---"
rm /mnt/setup_inside.sh
sync
umount -R /mnt
echo "安装完成，即将重启..."
sleep 5
reboot
