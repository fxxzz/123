#!/bin/bash

# 遇到错误立即停止执行
set -e
trap 'echo "出现错误，脚本已终止。请检查上方日志。"; exit 1' ERR

echo "--- 1. 配置宿主机环境 ---"
echo "root:XXZZea" | chpasswd
sed -i 's/^#\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config
systemctl restart sshd

echo "--- 2. 自动化分区与格式化 ---"
# 抹除旧分区表
sgdisk --zap-all /dev/vda

# 分区逻辑：1G EFI 分区，剩余全部给 Root
# GUID 说明：C12A... 为 EFI，4F68... 为 Linux Root
printf "label: gpt\nsize=1024M, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B\n, , type=4F68BCE3-E8CD-4DB1-96E7-FBCAF974B709\n" | sfdisk /dev/vda

# 刷新分区表并格式化
partprobe /dev/vda
sleep 2
mkfs.fat -F 32 /dev/vda1
mkfs.ext4 -F /dev/vda2

# 挂载
mount /dev/vda2 /mnt
mkdir -p /mnt/boot
mount /dev/vda1 /mnt/boot

echo "--- 3. 基础系统安装 (Pacstrap) ---"
pacstrap -K /mnt base linux linux-firmware openssh reflector grub efibootmgr vim wget sudo htop cronie base-devel curl

# 生成 fstab
genfstab -U /mnt >> /mnt/etc/fstab

echo "--- 4. 写入 Chroot 配置脚本 ---"
cat << 'CHROOT_EOF' > /mnt/setup_inside.sh
set -e
# 网络基础服务
systemctl enable systemd-networkd systemd-resolved
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

# 基础设置
echo "arch" > /etc/hostname
ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime
ln -s /usr/bin/vim /usr/bin/vi

# 本地化 Locale
sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# 网络配置 (IPv4 DHCP + Static IPv6)
mkdir -p /etc/systemd/network
cat << 'EOF' > /etc/systemd/network/20-ethernet.network
[Match]
Name=en*
Name=eth*

[Network]
DHCP=ipv4
Address=2a03:4000:27:f0d::1/64
Gateway=fe80::1
EOF

# 软件源优化配置
cat << 'EOF' > /etc/xdg/reflector/reflector.conf
--save /etc/pacman.d/mirrorlist
--protocol https
--sort rate
--country 'United States'
--latest 20
-n 10
EOF

# 启用关键服务
systemctl enable sshd cronie reflector.timer

# GRUB 引导安装 (针对虚拟化环境开启 --removable)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable
grub-mkconfig -o /boot/grub/grub.cfg

# 账户权限与 SSH 配置
echo "root:XXZZea" | chpasswd
sed -i 's/^#\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config
sed -i 's/^#\(PasswordAuthentication\).*/\1 yes/' /etc/ssh/sshd_config

# SSH Key 注入
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

CHROOT_EOF

echo "--- 5. 执行内部配置 ---"
chmod +x /mnt/setup_inside.sh
arch-chroot /mnt /bin/bash ./setup_inside.sh

echo "--- 6. 清理并重启 ---"
rm /mnt/setup_inside.sh
umount -R /mnt
echo "安装圆满完成！系统将在 5 秒后重启..."
sleep 5
reboot
