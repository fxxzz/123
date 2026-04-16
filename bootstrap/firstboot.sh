#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] firstboot failed at line $LINENO" >&2' ERR

LOG_DIR="/var/log/arch-reinstall"
LOG_FILE="$LOG_DIR/firstboot.log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[*] firstboot: minimal cleanup"
systemctl disable firstboot.service || true
rm -f /etc/systemd/system/firstboot.service
systemctl daemon-reload

echo "[*] firstboot complete"
echo "[*] Firstboot log: $LOG_FILE"
