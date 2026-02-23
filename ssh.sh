#!/bin/bash

# 1. 修改 root 密码
echo "root:XXZZea" | chpasswd

# 2. 创建 .ssh 目录并设置严格的安全权限 (这一步极其重要)
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# 3. 写入你的 ED25519 公钥并设置权限
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 4. 修改 SSH 配置 (直接追加到文件末尾，简单且不会匹配出错)
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config

# 5. 重启 SSH 服务让配置立即生效
systemctl restart sshd

echo "SSH 配置完毕！请在你的本地终端使用 ssh root@你的VPS_IP 连接。"
