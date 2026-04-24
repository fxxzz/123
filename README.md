# 123

Personal VPS install and post-install scripts.

## Arch install from Arch ISO

Run this in the Arch ISO environment. It will repartition and format `/dev/vda`, install Arch Linux, configure systemd-boot, network, locale, timezone and root SSH key login.

```bash
curl -fsSL https://github.com/fxxzz/123/raw/main/test5.sh | bash
```

## Arch post-install

Run this after booting into the Arch system installed by `test5.sh`.

```bash
curl -fsSL https://github.com/fxxzz/123/raw/main/arch.sh | bash
```

## Generic Arch post-install

Run this on an existing Arch system for general post-install configuration.

```bash
curl -fsSL https://github.com/fxxzz/123/raw/main/newarch.sh | bash
```

## Debian post-install

Run this on a Debian system.

```bash
curl -fsSL https://github.com/fxxzz/123/raw/main/debian.sh | bash
```

## Temporary SSH setup

Run this from a VNC/ISO/rescue environment when SSH access needs to be enabled temporarily.

```bash
curl -fsSL https://github.com/fxxzz/123/raw/main/ssh.sh | bash
```

## Files

| File | Purpose |
|---|---|
| `test5.sh` | Arch installer for UEFI VPS on `/dev/vda` |
| `arch.sh` | Post-install setup for the Arch system installed by `test5.sh` |
| `newarch.sh` | Generic Arch post-install setup |
| `debian.sh` | Debian post-install setup |
| `ssh.sh` | Temporary root password and SSH setup from VNC/ISO/rescue |

## Warning

Review scripts before running them, especially `test5.sh`, because it repartitions and formats `/dev/vda`.

```bash
curl -fsSL https://github.com/fxxzz/123/raw/main/test5.sh
curl -fsSL https://github.com/fxxzz/123/raw/main/arch.sh
curl -fsSL https://github.com/fxxzz/123/raw/main/newarch.sh
curl -fsSL https://github.com/fxxzz/123/raw/main/debian.sh
curl -fsSL https://github.com/fxxzz/123/raw/main/ssh.sh
```
