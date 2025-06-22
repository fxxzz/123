#!/bin/bash
set -euo pipefail

echo "1. 安装基础软件包..."
pacman -Syu --noconfirm
pacman -S --noconfirm sudo curl wget vim htop

echo "2. 配置DNS..."
cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 2001:4860:4860::8844
EOF
    
echo "3. 配置时区..."
timedatectl set-timezone Asia/Hong_Kong

echo "4. 配置Root密码和SSH..."
echo "root:XXZZea" | chpasswd
    
# 修改SSH配置
sudo sed -i -E \
    -e 's/^[#\s]*PermitRootLogin.*/PermitRootLogin yes/' \
    -e 's/^[#\s]*PasswordAuthentication.*/PasswordAuthentication no/' \
    -e 's/^[#\s]*ClientAliveInterval.*/ClientAliveInterval 6/' \
    -e 's/^[#\s]*ClientAliveCountMax.*/ClientAliveCountMax 6/' \
    /etc/ssh/sshd_config

echo "5. 配置SSH密钥..."
mkdir -p /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

echo "6. 重启SSH服务..."
systemctl restart sshd

if [ $# -eq 1 ]; then
    echo "7. 设置主机名为: $1"
    hostnamectl set-hostname "$1"
    cat > /etc/hosts <<EOF
127.0.0.1   localhost $1
::1         localhost $1
EOF
fi
echo "配置完成!"
