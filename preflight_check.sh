#!/usr/bin/env bash
set -euo pipefail

# preflight_check.sh
# Quick checks before running install.sh in a Gentoo live/mini environment.
# Usage: sudo bash preflight_check.sh [--disk /dev/nvme0n1] [--target /mnt/gentoo] [--unattended]

CONFIG_DISK="${1:-${CONFIG_DISK:-/dev/nvme0n1}}"
CONFIG_TARGET="${2:-${CONFIG_TARGET:-/mnt/gentoo}}"
UNATTENDED=${3:-${UNATTENDED:-0}}

ok=0
fail=0
warnc=0

die() { echo -e "\e[31m[ERROR]\e[0m $*" >&2; exit 2; }
info() { echo -e "\e[32m[OK]\e[0m $*"; }
warn() { echo -e "\e[33m[WARN]\e[0m $*"; warnc=$((warnc+1)); }

require_root(){ [[ $(id -u) -eq 0 ]] || die "请以 root 运行 preflight 检查"; }

require_root

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Commands to check
critical_cmds=(parted cryptsetup mkfs.ext4 mkfs.vfat tar curl git grub-install efibootmgr sha512sum)
suggested_cmds=(unzip fc-cache lsblk blkid openssl)

echo "Checking required commands..."
miss=()
for c in "${critical_cmds[@]}"; do
  if ! command -v "$c" >/dev/null 2>&1; then
    miss+=("$c")
  fi
done
if [[ ${#miss[@]} -eq 0 ]]; then
  info "All critical commands available"
else
  die "Missing critical commands: ${miss[*]}\nInstall them in the live environment before running install.sh"
fi

# Check suggested commands
miss_s=()
for c in "${suggested_cmds[@]}"; do
  if ! command -v "$c" >/dev/null 2>&1; then
    miss_s+=("$c")
  fi
done
if [[ ${#miss_s[@]} -gt 0 ]]; then
  warn "Suggested commands not found: ${miss_s[*]} (fonts/log collection may be limited)"
else
  info "Suggested commands available"
fi

# Network checks
echo "\nChecking network (distfiles.gentoo.org and GitHub)..."
if curl -sfS --head https://distfiles.gentoo.org >/dev/null 2>&1; then
  info "distfiles.gentoo.org reachable"
else
  warn "distfiles.gentoo.org not reachable; stage3 download may fail"
fi
if curl -sfS --head https://github.com >/dev/null 2>&1; then
  info "github.com reachable"
else
  warn "github.com not reachable; fetching repo/assets or fonts may fail"
fi

# UEFI / efivars
echo "\nChecking UEFI environment..."
if [[ -d /sys/firmware/efi/efivars ]]; then
  info "EFI variables present (likely booted in UEFI)"
  if command -v efibootmgr >/dev/null 2>&1; then
    info "efibootmgr available"
  else
    warn "efibootmgr not found; GRUB non-removable install may fail"
  fi
else
  warn "Not in UEFI runtime (/sys/firmware/efi/efivars missing). If target is UEFI, ensure booted in UEFI mode"
fi

# Disk and space checks
echo "\nChecking disk and available space..."
if [[ -b "$CONFIG_DISK" ]]; then
  info "Disk $CONFIG_DISK exists"
  # Get total MiB
  if command -v blockdev >/dev/null 2>&1; then
    total_mib=$(( $(blockdev --getsize64 "$CONFIG_DISK") / 1024 / 1024 ))
  else
    total_mib=$(lsblk -bno SIZE "$CONFIG_DISK" | awk '{print int($1/1024/1024)}')
  fi
  echo "  Disk size: ${total_mib} MiB"
  if [[ $total_mib -lt 20000 ]]; then
    warn "Disk seems small (<20GiB). Recommended at least 30GiB for comfortable installation"
  else
    info "Disk size looks sufficient"
  fi
else
  die "Disk $CONFIG_DISK not found. Pass correct device or check connections."
fi

# Check target mountpoint (if exists)
if mountpoint -q "$CONFIG_TARGET"; then
  info "$CONFIG_TARGET is mounted"
else
  warn "$CONFIG_TARGET is not mounted. The script will mount after partition/format steps. Ensure you run install.sh from live environment as root"
fi

# Check repository assets
echo "\nChecking repository assets (make.conf, genkernel.conf, 6.18.48, etc/portage/package.use)..."
missing_assets=()
for f in "make.conf" "genkernel.conf" "6.18.48" "etc/portage/package.use"; do
  if [[ ! -e "$SCRIPT_DIR/$f" ]]; then
    missing_assets+=("$f")
  fi
done
if [[ ${#missing_assets[@]} -eq 0 ]]; then
  info "Repository assets present"
else
  warn "Missing repository assets: ${missing_assets[*]}. If you only downloaded install.sh, the script will try to fetch them; unattended mode requires them present or reachable"
fi

# stage3 check in target
echo "\nChecking for stage3 in target ($CONFIG_TARGET)..."
if [[ -d "$CONFIG_TARGET" ]]; then
  fcount=$(ls "$CONFIG_TARGET"/stage3-*.tar.xz 2>/dev/null | wc -l || true)
  if [[ $fcount -ge 1 ]]; then
    info "Found stage3 in $CONFIG_TARGET"
  else
    warn "No stage3-*.tar.xz in $CONFIG_TARGET. install.sh can download stage3 but network/rate limits can fail"
  fi
else
  warn "$CONFIG_TARGET does not exist yet"
fi

# LUKS unattended settings
echo "\nChecking LUKS/unattended configuration..."
if [[ "${UNATTENDED}" == "1" ]]; then
  if [[ -n "${CONFIG_LUKS_KEYFILE:-}" && -f "$CONFIG_LUKS_KEYFILE" ]]; then
    info "CONFIG_LUKS_KEYFILE present and file exists"
  elif [[ -n "${CONFIG_LUKS_PASSPHRASE:-}" ]]; then
    warn "CONFIG_LUKS_PASSPHRASE provided (sensitive); ensure safe handling"
  else
    warn "Unattended mode selected but no CONFIG_LUKS_KEYFILE or CONFIG_LUKS_PASSPHRASE provided; luksFormat will be interactive and fail unattended"
  fi
else
  info "Interactive mode: LUKS/passphrase prompts will appear during install"
fi

# Final summary
echo "\nPreflight summary:"
if [[ $warnc -eq 0 ]]; then
  info "No warnings detected. Environment looks good for running install.sh"
else
  warn "Total warnings: $warnc. Address warnings before running unattended installs. For interactive installs, most warnings are advisory."
fi

echo "\nSuggested next actions:"
echo " - git clone the full repository rather than downloading a single file"
echo " - Ensure the live environment has the listed critical packages installed"
echo " - If unattended: provide CONFIG_LUKS_KEYFILE or CONFIG_LUKS_PASSPHRASE and pre-stage stage3 + .sha512 in $CONFIG_TARGET"
echo " - For GNOME unattended builds consider using a binaryhost or omit --desktop from CONFIG_BG_STEPS"

echo "\nRun: sudo bash preflight_check.sh /dev/nvme0n1 /mnt/gentoo 1  (for unattended checks)"

exit 0
