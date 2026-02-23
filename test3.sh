#!/bin/bash

set -e
trap 'echo "出现错误，脚本已终止。"; exit 1' ERR

echo "--- 1. 配置宿主机环境 ---"
echo "root:XXZZea" | chpasswd
sed -i 's/^#\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config
systemctl restart sshd

echo "--- 2. 自动化分区与格式化 ---"
wipefs -a /dev/vda
sgdisk --zap-all /dev/vda

# 确保 sfdisk 脚本格式严谨
echo "label: gpt
size=1G, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
type=4F68BCE3-E8CD-4DB1-96E7-FBCAF974B709" | sfdisk /dev/vda

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
# 注意：这里使用 cat > /mnt/setup_inside.sh << 'CHROOT_EOF' 结构更稳固
cat > /mnt/setup_inside.sh << 'CHROOT_EOF'
#!/bin/bash
set -e

# 基础服务与 DNS
systemctl enable systemd-networkd systemd-resolved
rm -f /etc/resolv.conf
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
# 基础设置
echo "arch" > /etc/hostname
ln -sf /usr/share/zoneinfo/Asia/Hong_Kong /etc/localtime
ln -s /usr/bin/vim /usr/bin/vi

# Locale
sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf

# 网络配置
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-ethernet.network << 'EOF'
[Match]
Name=en*
Name=eth*
[Network]
DHCP=ipv4
Address=2a03:4000:27:f0d::1/64
Gateway=fe80::1
EOF

# 软件源
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

# 引导安装 (最关键的一步)
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

# 账户权限
echo "root:XXZZea" | chpasswd
sed -i 's/^#\(PermitRootLogin\).*/\1 yes/' /etc/ssh/sshd_config
sed -i 's/^#\(PasswordAuthentication\).*/\1 yes/' /etc/ssh/sshd_config

# SSH Key
mkdir -p /root/.ssh && chmod 700 /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
CHROOT_EOF

echo "--- 5. 执行内部配置 ---"
chmod +x /mnt/setup_inside.sh
# 显式指定 bash 运行，增加日志输出
arch-chroot /mnt /bin/bash /setup_inside.sh

echo "--- 6. 清理并重启 ---"
rm /mnt/setup_inside.sh
sync
umount -R /mnt
echo "安装完成，即将重启..."
sleep 5
reboot
