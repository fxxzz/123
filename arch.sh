#!/bin/bash
set -euo pipefail

echo "1. 修改 pacman 配置启用 VerbosePkgLists..."
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf

echo "2. 安装基础软件包..."
pacman -Syu --noconfirm
pacman -S --noconfirm sudo curl wget vim htop

echo "3. 配置DNS..."
cat > /etc/resolv.conf <<EOF
nameserver 1.1.1.1
nameserver 2606:4700:4700::1111
EOF

echo "4. 配置语言环境、时区并启用时间同步..."
# 设置 locale
sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen

# 设置时区
timedatectl set-timezone Asia/Hong_Kong

# 启用并启动时间同步服务
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd

echo "5. 设置 root 密码、SSH 密钥并重启 SSH..."
echo "root:XXZZea" | chpasswd

mkdir -p /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

sed -i -E \
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

echo "7. 创建 bash 配置文件..."
# 创建 .bash_profile
cat > /root/.bash_profile <<'EOF'
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

# 创建 .bashrc
cat > /root/.bashrc <<'EOF'
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
alias c='echo -e "\e[41m \e[41m \e[41m \e[40m \e[44m \e[40m \e[41m \e[46m \e[45m \e[41m \e[46m \e[43m \e[41m \e[44m \e[45m \e[40m \e[44m \e[40m \e[41m \e[44m \e[41m \e[41m \e[46m \e[42m \e[41m \e[44m \e[43m \e[41m \e[45m \e[40m \e[40m \e[44m \e[40m \e[41m \e[44m \e[42m \e[41m \e[46m \e[44m \e[41m \e[46m \e[47m \e[0m"'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
EOF

echo "配置完成!"
