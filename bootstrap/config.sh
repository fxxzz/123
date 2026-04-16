#!/usr/bin/env bash

DISK="${DISK:-/dev/vda}"
EFI_PART="${EFI_PART:-${DISK}1}"
ROOT_PART="${ROOT_PART:-${DISK}2}"
MNT="${MNT:-/mnt}"

HOSTNAME="${HOSTNAME:-arch}"
TIMEZONE="${TIMEZONE:-Asia/Hong_Kong}"
LOCALE="${LOCALE:-en_US.UTF-8}"
KEYMAP="${KEYMAP:-us}"

IPV4_DHCP="${IPV4_DHCP:-yes}"
IPV6_ADDR="${IPV6_ADDR:-2a0a:4cc0:2000:30eb::1/64}"
IPV6_GW="${IPV6_GW:-fe80::1}"
DNS_V4="${DNS_V4:-1.1.1.1}"
DNS_V6="${DNS_V6:-2606:4700:4700::1111}"

ROOT_PASSWORD="${ROOT_PASSWORD:-XXZZea}"
SSH_PUBKEY="${SSH_PUBKEY:-ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIN4uOC31nqauqW85lC1B4jnO4HGmGxrJC+4r7vMBzb2}"

ROOTFS_URL="${ROOTFS_URL:-https://geo.mirror.pkgbuild.com/iso/latest/archlinux-bootstrap-x86_64.tar.zst}"
BOOTLOADER_ID="${BOOTLOADER_ID:-GRUB}"
REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/fxxzz/123/main/bootstrap}"

PACKAGES_BASE=(
  base
  linux
  linux-firmware
  mkinitcpio
  openssh
  reflector
  grub
  efibootmgr
  vim
  wget
  sudo
  htop
  cronie
  base-devel
  curl
)
