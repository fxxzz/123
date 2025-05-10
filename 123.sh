#!/bin/bash
set -euo pipefail
PACKAGES="sudo curl wget vim htop"
ROOT_PASSWORD="XXZZea"
SSH_PUBLIC_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2"

configure_system() {
    echo "1. 配置APT..."
    cat > "/etc/apt/apt.conf.d/99norecommends" <<EOF
APT::Install-Recommends "false";
APT::Install-Suggests "false";
EOF
    echo "2. 安装基础软件包..."
    apt-get update
    apt-get install -y $PACKAGES
    
    echo "3. 配置DNS (Cloudflare)..."
    cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
EOF
    
    echo "4. 配置时区..."
    timedatectl set-timezone Asia/Shanghai
    
    echo "5. 配置Root密码和SSH..."
    echo "root:${ROOT_PASSWORD}" | chpasswd
    
    # 修改SSH配置
    sudo sed -i -E \
        's/^[#\s]*PermitRootLogin.*/PermitRootLogin yes/;' \
        's/^[#\s]*PasswordAuthentication.*/PasswordAuthentication no/;' \
        's/^[#\s]*Port.*/Port 99/;' \
        's/^[#\s]*ClientAliveInterval.*/ClientAliveInterval 6/;' \
        's/^[#\s]*ClientAliveCountMax.*/ClientAliveCountMax 6/' \
        /etc/ssh/sshd_config
    
    echo "6. 配置SSH密钥..."
    mkdir -p /root/.ssh
    echo "$SSH_PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 700 /root/.ssh
    chmod 600 /root/.ssh/authorized_keys
    
    echo "7. 重启SSH服务..."
    systemctl restart sshd
    
    if [ $# -eq 1 ]; then
        echo "8. 设置主机名为: $1"
        hostnamectl set-hostname "$1"
        cat > /etc/hosts <<EOF
127.0.0.1   localhost $1
::1         localhost $1
EOF
    fi
    echo "配置完成!"
}

configure_system "$@"
