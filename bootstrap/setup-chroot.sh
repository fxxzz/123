#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] setup-chroot failed at line $LINENO" >&2' ERR

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/config.sh"

LOG_DIR="/root/install-logs"
LOG_FILE="$LOG_DIR/setup-chroot.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "[ERR] required command not found in chroot: $1" >&2
    exit 1
  }
}

require_cmd pacman-key
require_cmd pacman
require_cmd systemctl
require_cmd grub-install
require_cmd grub-mkconfig
require_cmd chpasswd
require_cmd sshd
require_cmd mountpoint

echo "[*] Stage A: pacman bootstrap"
cat > /etc/pacman.d/mirrorlist <<'EOF'
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF
cat > /etc/resolv.conf <<EOF
nameserver ${DNS_V4}
nameserver ${DNS_V6}
EOF

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm
pacman -S --noconfirm --needed "${PACKAGES_BASE[@]}"

echo "[*] Stage B: hostname, locale, timezone"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1 localhost
::1 localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

sed -i "s/^#\s*${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen || true
if ! grep -q "^${LOCALE} UTF-8" /etc/locale.gen; then
  echo "${LOCALE} UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=${LOCALE}" > /etc/locale.conf
echo "KEYMAP=${KEYMAP}" > /etc/vconsole.conf

echo "[*] Stage C: pacman.conf tuning"
sed -i 's/^#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
sed -i 's/^#\?CleanMethod.*/CleanMethod = KeepInstalled/' /etc/pacman.conf

echo "[*] Stage D: systemd-networkd + resolved"
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-ethernet.network <<EOF
[Match]
Name=*

[Network]
DHCP=ipv4
Address=${IPV6_ADDR}
Gateway=${IPV6_GW}
DNS=${DNS_V4}
DNS=${DNS_V6}
EOF

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/dns.conf <<EOF
[Resolve]
DNS=${DNS_V4} ${DNS_V6}
FallbackDNS=
DNSStubListener=yes
EOF

ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "[*] Stage E: reflector"
mkdir -p /etc/xdg/reflector
cat > /etc/xdg/reflector/reflector.conf <<'EOF'
--save /etc/pacman.d/mirrorlist
--protocol https
--sort rate
--country 'United States'
--latest 20
-n 10
EOF

echo "[*] Stage F: root access + ssh"
echo "root:${ROOT_PASSWORD}" | chpasswd
mkdir -p /root/.ssh
chmod 700 /root/.ssh
printf '%s\n' "$SSH_PUBKEY" > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/10-root-access.conf <<'EOF'
PermitRootLogin yes
PasswordAuthentication no
ClientAliveInterval 6
ClientAliveCountMax 6
EOF
sshd -t

echo "[*] Stage G: journald"
cat > /etc/systemd/journald.conf <<'EOF'
[Journal]
Storage=persistent
SystemMaxUse=500M
SystemMaxFileSize=50M
SystemKeepFree=100M
MaxRetentionSec=1month
EOF

echo "[*] Stage H: bootloader"
genfstab -U / > /etc/fstab
mountpoint -q /boot || {
  echo "[ERR] /boot is not mounted as EFI partition" >&2
  exit 1
}
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id="$BOOTLOADER_ID" --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Stage I: services"
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable sshd
systemctl enable cronie
systemctl enable reflector.timer

echo "[*] Stage J: firstboot hook"
install -Dm755 "$SCRIPT_DIR/firstboot.sh" /usr/local/bin/firstboot.sh
install -Dm644 "$SCRIPT_DIR/systemd/firstboot.service" /etc/systemd/system/firstboot.service
systemctl enable firstboot.service

echo "[*] setup-chroot complete"
echo "[*] Chroot log: $LOG_FILE"
