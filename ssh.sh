#!/bin/bash


echo "root:XXZZea" | chpasswd


mkdir -p /root/.ssh
chmod 700 /root/.ssh


echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys


echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config


systemctl restart sshd

echo "success"
