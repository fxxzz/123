#!/bin/bash
set -euo pipefail

echo "1. 修改 pacman 配置启用 VerbosePkgLists..."
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

echo "2. 安装基础软件包..."
pacman -Syu --noconfirm
pacman -S --noconfirm sudo curl wget vim htop

echo "3. 配置DNS..."
cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 2001:4860:4860::8844
EOF

echo "4. 配置时区..."
timedatectl set-timezone Asia/Hong_Kong

echo "5. 设置 root 密码、SSH 密钥并重启 SSH..."
echo "root:XXZZea" | chpasswd

mkdir -p /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

sudo sed -i -E \
    -e 's/^[#\s]*PermitRootLogin.*/PermitRootLogin yes/' \
    -e 's/^[#\s]*PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/^[#\s]*ClientAliveInterval.*/ClientAliveInterval 6/' \
    -e 's/^[#\s]*ClientAliveCountMax.*/ClientAliveCountMax 6/' \
    /etc/ssh/sshd_config

systemctl restart sshd

echo "6. 配置 systemd-journald 日志策略..."
tee /etc/systemd/journald.conf > /dev/null <<EOF
[Journal]
Storage=persistent
SystemMaxUse=50M
SystemMaxFileSize=10M
SystemKeepFree=10M
MaxRetentionSec=1week
EOF

systemctl restart systemd-journald

echo "配置完成!"
