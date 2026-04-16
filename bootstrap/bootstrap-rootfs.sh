#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "[ERR] bootstrap-rootfs failed at line $LINENO" >&2' ERR

SCRIPT_PATH="${BASH_SOURCE[0]-}"
SELF_MODE="local"

if [[ -z "$SCRIPT_PATH" || "$SCRIPT_PATH" == "/dev/fd/"* || "$SCRIPT_PATH" == "/proc/self/fd/"* ]]; then
  SELF_MODE="stdin"
  SCRIPT_DIR="$(pwd)"
else
  SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
fi

DEFAULT_REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/fxxzz/123/main/bootstrap}"
FETCH_DIR="${FETCH_DIR:-/run/arch-rootfs-reinstall}"
CONFIG_PATH="${CONFIG_PATH:-$SCRIPT_DIR/config.sh}"
SETUP_PATH="${SETUP_PATH:-$SCRIPT_DIR/setup-chroot.sh}"
FIRSTBOOT_PATH="${FIRSTBOOT_PATH:-$SCRIPT_DIR/firstboot.sh}"
FIRSTBOOT_SERVICE_PATH="${FIRSTBOOT_SERVICE_PATH:-$SCRIPT_DIR/systemd/firstboot.service}"

bootstrap_pacman_install() {
  pacman -Sy --noconfirm --needed "$@"
}

ensure_host_cmd() {
  local cmd="$1"
  shift
  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  fi
  echo "[*] Host command missing: $cmd; installing Arch package(s): $*"
  bootstrap_pacman_install "$@"
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "[ERR] failed to install required host command: $cmd" >&2
    exit 1
  }
}

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "[ERR] must run as root" >&2
  exit 1
fi

if [[ "$SELF_MODE" == "stdin" ]]; then
  mkdir -p "$FETCH_DIR/systemd"
  curl -fsSL "$DEFAULT_REPO_RAW_BASE/config.sh" -o "$FETCH_DIR/config.sh"
  curl -fsSL "$DEFAULT_REPO_RAW_BASE/setup-chroot.sh" -o "$FETCH_DIR/setup-chroot.sh"
  curl -fsSL "$DEFAULT_REPO_RAW_BASE/firstboot.sh" -o "$FETCH_DIR/firstboot.sh"
  curl -fsSL "$DEFAULT_REPO_RAW_BASE/systemd/firstboot.service" -o "$FETCH_DIR/systemd/firstboot.service"
  chmod +x "$FETCH_DIR/setup-chroot.sh" "$FETCH_DIR/firstboot.sh"
  CONFIG_PATH="$FETCH_DIR/config.sh"
  SETUP_PATH="$FETCH_DIR/setup-chroot.sh"
  FIRSTBOOT_PATH="$FETCH_DIR/firstboot.sh"
  FIRSTBOOT_SERVICE_PATH="$FETCH_DIR/systemd/firstboot.service"
fi

if [[ ! -f "$CONFIG_PATH" ]]; then
  echo "[ERR] config.sh not found: $CONFIG_PATH" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$CONFIG_PATH"

if [[ "$SELF_MODE" == "local" ]]; then
  SETUP_PATH="${SETUP_PATH:-$SCRIPT_DIR/setup-chroot.sh}"
  FIRSTBOOT_PATH="${FIRSTBOOT_PATH:-$SCRIPT_DIR/firstboot.sh}"
  FIRSTBOOT_SERVICE_PATH="${FIRSTBOOT_SERVICE_PATH:-$SCRIPT_DIR/systemd/firstboot.service}"
fi

EARLY_LOG_DIR="${EARLY_LOG_DIR:-/tmp/arch-rootfs-install}"
EARLY_LOG_FILE="$EARLY_LOG_DIR/bootstrap-rootfs.log"
mkdir -p "$EARLY_LOG_DIR"
exec > >(tee -a "$EARLY_LOG_FILE") 2>&1

ensure_host_cmd curl curl
ensure_host_cmd tar tar
ensure_host_cmd awk gawk
ensure_host_cmd sed sed
ensure_host_cmd mount util-linux
ensure_host_cmd umount util-linux
ensure_host_cmd chroot coreutils
ensure_host_cmd mkfs.fat dosfstools
ensure_host_cmd mkfs.ext4 e2fsprogs
ensure_host_cmd wipefs util-linux
ensure_host_cmd sfdisk util-linux
ensure_host_cmd sgdisk gptfdisk
ensure_host_cmd sync coreutils
ensure_host_cmd partprobe parted
ensure_host_cmd tee coreutils

if [[ -t 0 ]]; then
  echo "[*] This will ERASE ${DISK}."
  read -r -p "Type 'yes' to continue: " confirm
  [[ "$confirm" == "yes" ]] || {
    echo "[INFO] aborted"
    exit 1
  }
else
  echo "[*] Non-interactive stdin detected. Proceeding with destructive install on ${DISK}."
fi

mkdir -p "$MNT"
umount -R "$MNT" 2>/dev/null || true

cleanup_chroot_mounts() {
  umount -R "$MNT/run" 2>/dev/null || true
  umount -R "$MNT/dev" 2>/dev/null || true
  umount -R "$MNT/sys" 2>/dev/null || true
  umount -R "$MNT/proc" 2>/dev/null || true
}

trap 'cleanup_chroot_mounts' EXIT

echo "[*] Stage 1: partitioning $DISK"
wipefs -a "$DISK"
sgdisk --zap-all "$DISK"
printf 'label: gpt\nsize=1G, type=U\ntype=L\n' | sfdisk "$DISK"
partprobe "$DISK"
sleep 2

echo "[*] Stage 2: formatting partitions"
mkfs.fat -F 32 "$EFI_PART"
mkfs.ext4 -F "$ROOT_PART"

echo "[*] Stage 3: mounting target filesystem"
mount "$ROOT_PART" "$MNT"
mkdir -p "$MNT/boot"
mount "$EFI_PART" "$MNT/boot"

WORK_DIR="${WORK_DIR:-$MNT/root/arch-reinstall-cache}"
BOOTSTRAP_ARCHIVE="$WORK_DIR/archlinux-bootstrap.tar.zst"
BOOTSTRAP_EXTRACT_DIR="$WORK_DIR/bootstrap-extract"
mkdir -p "$WORK_DIR"

echo "[*] Stage 4: downloading Arch bootstrap rootfs"
rm -rf "$BOOTSTRAP_EXTRACT_DIR"
mkdir -p "$BOOTSTRAP_EXTRACT_DIR"
curl -fsSL "$ROOTFS_URL" -o "$BOOTSTRAP_ARCHIVE"

echo "[*] Stage 5: extracting rootfs"
tar --zstd -xpf "$BOOTSTRAP_ARCHIVE" -C "$BOOTSTRAP_EXTRACT_DIR"
BOOTSTRAP_ROOT="$(find "$BOOTSTRAP_EXTRACT_DIR" -mindepth 1 -maxdepth 1 -type d -name 'root.x86_64*' | head -n1)"
if [[ -z "$BOOTSTRAP_ROOT" ]]; then
  echo "[ERR] failed to locate extracted bootstrap rootfs" >&2
  exit 1
fi
[[ -x "$BOOTSTRAP_ROOT/usr/bin/pacman" ]] || {
  echo "[ERR] extracted bootstrap rootfs does not contain /usr/bin/pacman" >&2
  exit 1
}
cp -a "$BOOTSTRAP_ROOT"/. "$MNT/"

mkdir -p "$MNT/etc"
cat > "$MNT/etc/resolv.conf" <<EOF
nameserver ${DNS_V4}
nameserver ${DNS_V6}
EOF

echo "[*] Stage 6: preparing chroot mounts"
mount --types proc /proc "$MNT/proc"
mount --rbind /sys "$MNT/sys"
mount --make-rslave "$MNT/sys"
mount --rbind /dev "$MNT/dev"
mount --make-rslave "$MNT/dev"
mount --bind /run "$MNT/run"
mount --make-slave "$MNT/run"

echo "[*] Stage 7: copying install files"
mkdir -p "$MNT/root/arch-reinstall"
cp "$CONFIG_PATH" "$MNT/root/arch-reinstall/config.sh"
cp "$SETUP_PATH" "$MNT/root/arch-reinstall/setup-chroot.sh"
cp "$FIRSTBOOT_PATH" "$MNT/root/arch-reinstall/firstboot.sh"
mkdir -p "$MNT/root/arch-reinstall/systemd"
cp "$FIRSTBOOT_SERVICE_PATH" "$MNT/root/arch-reinstall/systemd/firstboot.service"
chmod +x "$MNT/root/arch-reinstall/"*.sh

echo "[*] Stage 8: entering chroot"
chroot "$MNT" /bin/bash -lc 'cd /root/arch-reinstall && bash ./setup-chroot.sh'

echo "[*] Stage 9: cleanup"
rm -rf "$WORK_DIR"
cleanup_chroot_mounts
umount "$MNT/boot" 2>/dev/null || true
umount "$MNT" 2>/dev/null || true
trap - EXIT
sync

echo "[*] Install flow complete. Reboot when ready."
echo "[*] Bootstrap log: $EARLY_LOG_FILE"
