#!/bin/bash
set -euo pipefail

echo "1. 修改 pacman 配置..."
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#\?CleanMethod.*/CleanMethod = KeepInstalled/' /etc/pacman.conf

cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF

echo "2. 配置 systemd-resolved 和 DNS..."
systemctl enable --now systemd-resolved
rm -f /etc/resolv.conf
ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "3. 安装基础软件包..."
pacman -Syu --noconfirm
pacman -S --noconfirm wget vim htop cronie
systemctl enable --now cronie

echo "4. 配置语言环境、时区并启用时间同步..."
sed -i 's/^#\s*en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen
echo 'KEYMAP=us' > /etc/vconsole.conf

timedatectl set-timezone Asia/Hong_Kong
systemctl enable --now systemd-timesyncd

echo "5. 设置 root 密码、SSH 密钥并重启 SSH..."
echo "root:XXZZea" | chpasswd

mkdir -p /root/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 700 /root/.ssh
chmod 600 /root/.ssh/authorized_keys

sed -i -E \
    -e 's/^[#[:space:]]*ClientAliveInterval.*/ClientAliveInterval 6/' \
    -e 's/^[#[:space:]]*ClientAliveCountMax.*/ClientAliveCountMax 6/' \
    /etc/ssh/sshd_config
systemctl restart sshd

echo "6. 配置 systemd-journald 日志策略..."
cat > /etc/systemd/journald.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
SystemMaxFileSize=50M
SystemKeepFree=100M
MaxRetentionSec=1month
EOF
systemctl restart systemd-journald

echo "7. 创建 bash 配置文件..."
cat > /root/.bash_profile <<'EOF'
[[ -f ~/.bashrc ]] && . ~/.bashrc
EOF

cat > /root/.bashrc <<'EOF'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
export EDITOR=vim
export VISUAL=vim
EOF

source ~/.bashrc

echo "配置完成!"
