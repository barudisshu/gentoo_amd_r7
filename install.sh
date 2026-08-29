#!/usr/bin/env bash
#
# Gentoo AMD Krackan (Ryzen AI 7 / Radeon 840M) 安装脚本
# 参考资料: README.md / https://wiki.gentoo.org
#
# 磁盘方案 (UEFI，可选 LUKS + ext4，按磁盘容量自动化分区):
#   p1  ESP   (vfat, /boot)
#   p2  root  (可选 LUKS2 -> ext4, /)
#   p3  home  (可选 LUKS2 -> ext4, /home)
#   p4  swap  (可选，按容量自动)
# 分区大小由「磁盘自动化分析」按容量计算（可交互确认或手动调整）。
# init 系统：交互询问 systemd/openrc（默认 systemd），stage3/profile/服务按所选分支。
#
# 用法:
#   阶段一（ISO 环境，交互式询问磁盘/主机名/加密/init 等）:
#     sudo bash install.sh
#   阶段二/三（chroot 内）:
#     bash /root/install.sh --chroot      # 基础 + 内核
#     bash /root/install.sh --desktop     # 桌面(GNOME)，安装前确认 package.use
#     bash /root/install.sh --zsh         # (可选) zsh + Powerlevel10k + autosuggestions
#     bash /root/install.sh --grub        # GRUB
#   尾处理（ISO 环境）:
#     sudo bash install.sh --final
#
#   非交互（跳过提问，全部用环境变量/默认值）:
#     CONFIG_DISK=/dev/nvme0n1 CONFIG_INITSYS=openrc CONFIG_ENCRYPT=yes \
#       sudo bash install.sh --unattended
#   覆盖 gentoo-zh（默认 yes）:
#     CONFIG_GENTOO_ZH=no sudo bash install.sh
#   网络（中国网络：下载/clone 自动重试多次；GitHub 完全被墙时可换镜像）:
#     CONFIG_GIT_RETRIES=8 CONFIG_GIT_RETRY_SLEEP=5 CONFIG_GITHUB_BASE=https://ghproxy.com \
#       sudo bash install.sh
#
set -euo pipefail
# Simple logging: append output to a logfile when running as root
LOGFILE="${LOGFILE:-/var/log/gentoo_install.log}"
if [[ "$(id -u)" -eq 0 ]]; then
  mkdir -p "$(dirname "${LOGFILE}")" 2>/dev/null || true
  exec > >(tee -a "${LOGFILE}") 2>&1
fi

# ---------------------------------------------------------------------------
# 配置变量（可用环境变量覆盖；默认取自 README / 仓库内 make.conf）
# ---------------------------------------------------------------------------
CONFIG_DISK="${CONFIG_DISK:-/dev/nvme0n1}"        # 目标磁盘
CONFIG_TARGET="${CONFIG_TARGET:-/mnt/gentoo}"
CONFIG_USER="${CONFIG_USER:-galudisu}"            # 创建的用户
CONFIG_HOSTNAME="${CONFIG_HOSTNAME:-gentoo}"
CONFIG_TIMEZONE="${CONFIG_TIMEZONE:-Asia/Shanghai}"
CONFIG_ENCRYPT="${CONFIG_ENCRYPT:-yes}"           # yes/no：是否加密 root+home
CONFIG_INITSYS="${CONFIG_INITSYS:-systemd}"         # systemd / openrc（init 系统）
CONFIG_GENTOO_ZH="${CONFIG_GENTOO_ZH:-yes}"         # yes/no：启用 gentoo-zh overlay
CONFIG_STAGE3_URL=""                               # 留空则阶段一后手动放 stage3

# 分区自动化参数（可覆盖；留空则按磁盘容量自动计算）
CONFIG_ESP_SIZE="${CONFIG_ESP_SIZE:-}"             # MiB，默认 512 或按需
CONFIG_ROOT_SIZE="${CONFIG_ROOT_SIZE:-}"           # MiB，留空 = 剩余全部给 home
CONFIG_SWAP_SIZE="${CONFIG_SWAP_SIZE:-}"           # MiB，0=不建 swap 分区

# 仓库内随附配置（阶段一拷入目标 /root 与 /etc/portage，阶段二在 chroot 内引用）
MAKE_CONF_SRC="${MAKE_CONF_SRC:-/root/make.conf}"           # CFLAGS/MAKEOPTS/镜像/USE
GEKK_CONF_SRC="${GEKK_CONF_SRC:-/root/genkernel.conf}"      # LUKS/DMCRYPT/固件
KERNEL_CONF_SRC="${KERNEL_CONF_SRC:-/root/6.18.48}"         # 内核配置（含固件）
PKG_USE_DIR="${PKG_USE_DIR:-/root/package.use}"             # 仓库 package.use/ 目录（拷入 /etc/portage/）
CONFIG_DESKTOP="${CONFIG_DESKTOP:-gnome}"                    # 桌面：gnome / none（--desktop 阶段使用）
# 字体（Powerlevel10k 推荐 Nerd Font，如 MesloLGS）
CONFIG_NERD_FONT="${CONFIG_NERD_FONT:-meslo}"
# 如果可用，优先使用 gentoo 包 app-fonts/nerd-fonts（不同 overlay 名称可能不同）

# 可选体验包（README 推荐软件）。以空格分隔；可用环境变量覆盖：
# 例如: CONFIG_EXTRAS_PACKAGES="www-client/firefox media-video/vlc app-office/libreoffice"
CONFIG_EXTRAS="${CONFIG_EXTRAS:-no}"                       # yes/no：是否默认安装 extras（交互模式仍会提示）
CONFIG_EXTRAS_PACKAGES="${CONFIG_EXTRAS_PACKAGES:-www-client/firefox media-video/vlc app-office/libreoffice gimp app-admin/synaptic}"

# 网络重试参数（中国网络环境下 clone/下载不稳，默认 5 次 / 间隔 3s）
CONFIG_GIT_RETRIES="${CONFIG_GIT_RETRIES:-5}"
CONFIG_GIT_RETRY_SLEEP="${CONFIG_GIT_RETRY_SLEEP:-3}"
# GitHub 镜像前缀（GitHub 被墙完全不可达时，设为镜像如 https://ghproxy.com/）
CONFIG_GITHUB_BASE="${CONFIG_GITHUB_BASE:-https://github.com}"

# 后台自动化（unattended）相关：在 live 环境以 chroot 调用 --chroot/--desktop 等
# CONFIG_BG_STEPS: 空格分隔的子命令（如 "--chroot --desktop --zsh --grub"）
CONFIG_BG_STEPS="${CONFIG_BG_STEPS:---chroot --desktop --zsh --grub}"
CONFIG_BG_RETRIES="${CONFIG_BG_RETRIES:-5}"
CONFIG_BG_SLEEP="${CONFIG_BG_SLEEP:-60}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 如果用户仅下载单个 install.sh，尝试从仓库自动拉取缺失的辅助文件（make.conf / genkernel.conf / 6.18.48 / etc/portage/package.use）
REPO_OWNER="${REPO_OWNER:-barudisshu}"
REPO_NAME="${REPO_NAME:-gentoo_amd_r7}"

fetch_repo_assets() {
  local needed=("make.conf" "genkernel.conf" "6.18.48" "etc/portage/package.use")
  local miss=()
  for p in "${needed[@]}"; do
    if [[ -e "$SCRIPT_DIR/$p" ]]; then
      continue
    fi
    miss+=("$p")
  done
  [[ ${#miss[@]} -gt 0 ]] || return 0
  info "检测到仓库附件缺失: ${miss[*]}，尝试从 ${CONFIG_GITHUB_BASE%/}/${REPO_OWNER}/${REPO_NAME} 拉取..."
  local tarurl="${CONFIG_GITHUB_BASE%/}/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/main.tar.gz"
  local tmpd tmpf topdir
  tmpd=$(mktemp -d)
  tmpf="$tmpd/repo.tar.gz"

  if ! retry "$CONFIG_GIT_RETRIES" "$CONFIG_GIT_RETRY_SLEEP" curl -fL -o "$tmpf" "$tarurl"; then
    warn "从 main 分支下载失败，尝试 master 分支..."
    tarurl="${CONFIG_GITHUB_BASE%/}/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/master.tar.gz"
    retry "$CONFIG_GIT_RETRIES" "$CONFIG_GIT_RETRY_SLEEP" curl -fL -o "$tmpf" "$tarurl" || die "无法下载仓库 tarball: $tarurl"
  fi

  tar -xzf "$tmpf" -C "$tmpd" || die "解压仓库失败"
  topdir=$(find "$tmpd" -maxdepth 1 -type d -name "${REPO_NAME}-*" | head -1)
  [[ -n "$topdir" ]] || die "未找到解压后的仓库目录"

  for p in "${miss[@]}"; do
    if [[ -e "$topdir/$p" ]]; then
      mkdir -p "$(dirname "$SCRIPT_DIR/$p")"
      cp -a "$topdir/$p" "$SCRIPT_DIR/$p"
      info "已获取并保存: $p"
    else
      warn "仓库中缺少: $p"
    fi
  done
  rm -rf "$tmpd"
}


# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------
die() { echo -e "\e[31m[错误]\e[0m $*" >&2; exit 1; }
info() { echo -e "\e[32m[==>]\e[0m $*"; }
warn() { echo -e "\e[33m[警告]\e[0m $*" >&2; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

# 网络重试：retry <次数> [间隔秒] <cmd...>；成功返回 0，全部失败返回非 0
retry() {
  local n="${1:-3}" sleep_s="${2:-3}" tries=0
  shift 2 2>/dev/null || { n=3; sleep_s=3; }
  until "$@"; do
    tries=$((tries + 1))
    warn "命令失败($tries/$n)，${sleep_s} 秒后重试: $*"
    (( tries >= n )) && return 1
    sleep "$sleep_s"
  done
}

# 交互读取：$1=提示 $2=默认值；输出到全局 read_val
read_val() {
  local prompt="$1" def="$2" input
  printf "%s [%s]: " "$prompt" "$def"
  IFS= read -r input
  read_val="${input:-$def}"
}

confirm() { # $1=提示 $2=默认(y/n)；返回 0 表示是
  local prompt="$1" def="${2:-n}" ans
  local ch; [[ "$def" == "y" ]] && ch="Y/n" || ch="y/N"
  printf "%s [%s] " "$prompt" "$ch"
  IFS= read -r ans
  case "${ans:-$def}" in
    y|Y|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

# 危险操作二次确认：必须输入目标磁盘路径（如 /dev/nvme0n1）才继续，直接回车=取消
confirm_danger() {
  local dev="$1" inp det
  det=$(lsblk -ndo SIZE,MODEL "$dev" 2>/dev/null)
  warn "=============================================="
  warn "即将销毁 $dev 上的【全部数据】！$([[ -n "$det" ]] && echo "($det)")"
  warn "=============================================="
  printf "为确认，请输入磁盘路径 %s（直接回车取消）: " "$dev"
  IFS= read -r inp
  [[ "$inp" == "$dev" ]]
}

partition_dev() { # DISK -> 分区设备（nvme 为 pN，其余按 udev 规则）
  case "$1" in
    *nvme*|*mmcblk*|*nbd*|*loop*) echo "${1}p$2" ;;
    *) echo "${1}$2" ;;
  esac
}

require_root() { [[ "$(id -u)" -eq 0 ]] || die "请以 root 运行"; }

require_tools() {
  local t missing=0
  # Critical tools
  for t in parted cryptsetup mkfs.ext4 mkfs.vfat tar curl git grub-install efibootmgr; do
    if ! has_cmd "$t"; then
      warn "缺少关键命令: $t（请在 live 环境安装或用 emerge 安装）"
      missing=1
    fi
  done
  # Suggested tools
  for t in links nano blkid unzip fc-cache; do
    has_cmd "$t" || warn "建议安装: $t"
  done
  [[ $missing -eq 0 ]] || die "缺少关键工具，无法继续。"
}

# 清理函数（在出错时尝试卸载/关闭加密卷/swap）
cleanup() {
  warn "运行清理..."
  umount -R "${CONFIG_TARGET:-/mnt/gentoo}" 2>/dev/null || true
  if [[ "${CONFIG_ENCRYPT:-no}" == "yes" ]]; then
    cryptsetup close home 2>/dev/null || true
    cryptsetup close root 2>/dev/null || true
  fi
  swapoff "${SWAP_DEV:-}" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# 交互配置（阶段一，除非 --unattended）
# ---------------------------------------------------------------------------
# 时区选择：默认直通；否则按 /usr/share/zoneinfo 列出 区域->城市
select_timezone() {
  [[ "$UNATTENDED" == "1" ]] && return 0
  info "时区：当前默认 $CONFIG_TIMEZONE"
  if confirm "使用默认时区 $CONFIG_TIMEZONE？" y; then
    return 0
  fi

  local zt=/usr/share/zoneinfo
  [[ -d "$zt" ]] || { warn "无 /usr/share/zoneinfo，保持默认 $CONFIG_TIMEZONE"; return 0; }

  # 列出主区域（不含 posix/right/UTC/Etc 等）
  local regions region i city tzname
  regions=$(find "$zt" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' 2>/dev/null \
            | grep -vE '^(posix|right|Etc|SystemV)$' | sort)
  [[ -z "$regions" ]] && { warn "未找到时区区域，保持默认"; return 0; }

  echo "可用区域："
  i=0
  while IFS= read -r region; do
    i=$((i+1)); printf '  %2d) %s\n' "$i" "$region"
  done <<< "$regions"
  local picks=()
  i=0
  while IFS= read -r region; do i=$((i+1)); picks[$i]=$region; done <<< "$regions"
  local choice region
  read -r -p "选择区域 [1]: " choice; choice="${choice:-1}"
  region="${picks[$choice]:-${picks[1]}}"
  [[ -n "$region" ]] || region="Asia"

  # 区域内城市
  local cities citylist
  citylist=$(find "$zt/$region" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort)
  if [[ -z "$citylist" ]]; then
    CONFIG_TIMEZONE="$region"
    info "时区已设为: $CONFIG_TIMEZONE"
    return 0
  fi
  echo "可用城市（区域 $region）："
  i=0
  while IFS= read -r city; do i=$((i+1)); picks[$i]="$region/$city"; printf '  %2d) %s\n' "$i" "$city"; done <<< "$citylist"
  read -r -p "选择城市 [1]: " choice; choice="${choice:-1}"
  city="${picks[$choice]:-${picks[1]}}"
  CONFIG_TIMEZONE="${city:-$CONFIG_TIMEZONE}"
  info "时区已设为: $CONFIG_TIMEZONE"
}

interactive_config() {
  info "==== Gentoo 安装交互配置 ===="
  read_val "目标磁盘" "$CONFIG_DISK"; CONFIG_DISK="$read_val"
  read_val "主机名" "$CONFIG_HOSTNAME"; CONFIG_HOSTNAME="$read_val"
  read_val "用户名" "$CONFIG_USER"; CONFIG_USER="$read_val"
  select_timezone

  if confirm "加密 root 与 home 分区？" "${CONFIG_ENCRYPT/yes/y}"; then
    CONFIG_ENCRYPT=yes
  else
    CONFIG_ENCRYPT=no
  fi

  read_val "系统初始化方式 (systemd/openrc)" "$CONFIG_INITSYS"; CONFIG_INITSYS="${read_val,,}"
  case "$CONFIG_INITSYS" in
    openrc) CONFIG_INITSYS=openrc ;;
    *) CONFIG_INITSYS=systemd ;;
  esac

  if confirm "启用 gentoo-zh overlay？" "${CONFIG_GENTOO_ZH/yes/y}"; then
    CONFIG_GENTOO_ZH=yes
  else
    CONFIG_GENTOO_ZH=no
  fi

  info "配置结果: 磁盘=$CONFIG_DISK 主机名=$CONFIG_HOSTNAME 用户=$CONFIG_USER 时区=$CONFIG_TIMEZONE init=${CONFIG_INITSYS} 加密=${CONFIG_ENCRYPT} gentoo-zh=${CONFIG_GENTOO_ZH}"
}

# ---------------------------------------------------------------------------
# 阶段一：磁盘准备（在 ISO 环境运行）
# ---------------------------------------------------------------------------
P_ESP=""; P_ROOT=""; P_HOME=""; SWAP_DEV=""; CRYPT_ROOT=""; CRYPT_HOME=""
UNATTENDED=0
compute_devices() {
  P_ESP="$(partition_dev "${CONFIG_DISK}" 1)"
  P_ROOT="$(partition_dev "${CONFIG_DISK}" 2)"
  P_HOME="$(partition_dev "${CONFIG_DISK}" 3)"
  SWAP_DEV="$(partition_dev "${CONFIG_DISK}" 4)"
  if [[ "$CONFIG_ENCRYPT" == "yes" ]]; then
    CRYPT_ROOT="/dev/mapper/root"
    CRYPT_HOME="/dev/mapper/home"
  else
    CRYPT_ROOT="$P_ROOT"
    CRYPT_HOME="$P_HOME"
  fi
}

# ---------------------------------------------------------------------------
# 磁盘自动化分析：探测容量并计算分区布局（MiB）
# 布局: p1=pESP  p2=root  p3=home  p4=swap(可选)
# ---------------------------------------------------------------------------
DISK_TOTAL_MIB=""; ESP_MIB=""; ROOT_MIB=""; HOME_MIB=""; SWAP_MIB="0"
disk_analyze() {
  require_root
  [[ -b "$CONFIG_DISK" ]] || die "磁盘不存在: $CONFIG_DISK"

  if has_cmd blockdev; then
    DISK_TOTAL_MIB=$(( $(blockdev --getsize64 "$CONFIG_DISK" 2>/dev/null) / 1024 / 1024 ))
  elif has_cmd lsblk; then
    DISK_TOTAL_MIB=$(lsblk -bno SIZE "$CONFIG_DISK" 2>/dev/null | head -1 | awk '{print int($1/1024/1024)}')
  else
    die "需要 blockdev 或 lsblk 以探测磁盘容量"
  fi
  [[ -n "$DISK_TOTAL_MIB" && "$DISK_TOTAL_MIB" -gt 0 ]] || die "无法获取磁盘容量。"

  # ESP：默认 512 MiB（>=100GB 磁盘用 512，小盘用 256）
  if [[ -n "$CONFIG_ESP_SIZE" ]]; then
    ESP_MIB="$CONFIG_ESP_SIZE"
  else
    ESP_MIB=$(( DISK_TOTAL_MIB >= 100000 ? 512 : 256 ))
  fi

  # swap：默认 = 磁盘容量的 1/8，封顶 16GiB；可强制 0 关闭
  if [[ -n "$CONFIG_SWAP_SIZE" ]]; then
    SWAP_MIB="$CONFIG_SWAP_SIZE"
  else
    SWAP_MIB=$(( DISK_TOTAL_MIB / 8 ))
    local max_swap=$(( 16 * 1024 ))
    [[ $SWAP_MIB -gt $max_swap ]] && SWAP_MIB=$max_swap
  fi

  # root：默认 64GiB；磁盘较小时按容量自适应（约为 30%），保证 home 有空间
  if [[ -n "$CONFIG_ROOT_SIZE" ]]; then
    ROOT_MIB="$CONFIG_ROOT_SIZE"
  else
    ROOT_MIB=65536
    local after=$(( DISK_TOTAL_MIB - ESP_MIB - SWAP_MIB ))
    if [[ $after -lt $(( ROOT_MIB * 2 )) ]]; then
      ROOT_MIB=$(( after * 30 / 100 ))
    fi
    [[ $ROOT_MIB -lt 10240 ]] && ROOT_MIB=10240   # root 至少 10GiB
  fi

  # 剩余全给 home
  local avail=$(( DISK_TOTAL_MIB - ESP_MIB - ROOT_MIB - SWAP_MIB ))
  [[ $avail -gt 1024 ]] || die "磁盘空间不足，无法布局（可用=${avail}MiB）"
  HOME_MIB=$avail

  info "磁盘自动化分析: $CONFIG_DISK 容量=${DISK_TOTAL_MIB}MiB"
  {
    printf "  p1 ESP    %10d MiB\n"   "$ESP_MIB"
    printf "  p2 root   %10d MiB\n"   "$ROOT_MIB"
    printf "  p3 home   %10d MiB\n"   "$HOME_MIB"
    printf "  p4 swap   %10d MiB  %s\n" "$SWAP_MIB" "$([[ $SWAP_MIB -eq 0 ]] && echo "(关闭)" || echo "(swap)")"
  }
}

# 询问是否接受自动布局；不接受则手动输入（--unattended 直接接受）
confirm_layout() {
  disk_analyze
  if [[ "$UNATTENDED" == "1" ]]; then
    info "非交互模式，使用自动布局。"
    return 0
  fi
  if confirm "接受自动分区布局（ESP=$ESP_MIB / root=$ROOT_MIB / home=$HOME_MIB / swap=$SWAP_MIB MiB）？" y; then
    return 0
  fi
  info "手动设置分区大小（MiB），直接回车保留当前值："
  local v
  read_val "ESP 大小"    "$ESP_MIB";   ESP_MIB="$read_val"
  read_val "root 大小"   "$ROOT_MIB";  ROOT_MIB="$read_val"
  read_val "swap 大小(0=无)" "$SWAP_MIB"; SWAP_MIB="$read_val"
  # 重新计算 home = 剩余
  HOME_MIB=$(( DISK_TOTAL_MIB - ESP_MIB - ROOT_MIB - SWAP_MIB ))
  [[ $HOME_MIB -gt 0 ]] || die "布局无效：home 无剩余空间"
  info "最终布局: ESP=$ESP_MIB root=$ROOT_MIB home=$HOME_MIB swap=$SWAP_MIB MiB"
}

prep_disk() {
  require_root
  compute_devices
  confirm_layout
  info "磁盘: $CONFIG_DISK（加密=${CONFIG_ENCRYPT}），将销毁其全部数据!"
  confirm_danger "$CONFIG_DISK" || { warn "已取消分区（未做任何修改）。"; return 1; }
  umount -R "${CONFIG_TARGET}" 2>/dev/null || true

  # GPT 分区表（用自动计算的布局，消除原 513-1537 空洞）
  local start=1
  parted -s "$CONFIG_DISK" mklabel gpt
  parted -s "$CONFIG_DISK" unit MiB
  parted -s "$CONFIG_DISK" mkpart primary fat32 $start $((start + ESP_MIB))
  parted -s "$CONFIG_DISK" set 1 esp on
  parted -s "$CONFIG_DISK" name 1 boot
  start=$((start + ESP_MIB))
  parted -s "$CONFIG_DISK" mkpart primary $start $((start + ROOT_MIB))
  parted -s "$CONFIG_DISK" name 2 root
  start=$((start + ROOT_MIB))
  parted -s "$CONFIG_DISK" mkpart primary $start $((start + HOME_MIB))
  parted -s "$CONFIG_DISK" name 3 home
  start=$((start + HOME_MIB))
  if [[ $SWAP_MIB -gt 0 ]]; then
    parted -s "$CONFIG_DISK" mkpart primary $start $((start + SWAP_MIB))
    parted -s "$CONFIG_DISK" name 4 swap
    parted -s "$CONFIG_DISK" set 4 swap on
  fi
  parted -s "$CONFIG_DISK" print
  partprobe "$CONFIG_DISK" 2>/dev/null || true
  sleep 2

  # ESP
  mkfs.vfat -F32 "$P_ESP"

  # root：可选加密
  modprobe dm-crypt 2>/dev/null || true
  if [[ "$CONFIG_ENCRYPT" == "yes" ]]; then
    info "为 root 分区 ($P_ROOT) 设置 LUKS ..."
    # 支持无交互密钥：CONFIG_LUKS_KEYFILE 或 CONFIG_LUKS_PASSPHRASE (unattended)
    if [[ -n "${CONFIG_LUKS_KEYFILE:-}" && -f "$CONFIG_LUKS_KEYFILE" ]]; then
      cryptsetup luksFormat --type luks2 --key-file "$CONFIG_LUKS_KEYFILE" "$P_ROOT"
      cryptsetup open --key-file "$CONFIG_LUKS_KEYFILE" "$P_ROOT" root
    elif [[ -n "${CONFIG_LUKS_PASSPHRASE:-}" && "$UNATTENDED" == "1" ]]; then
      local _kf
      _kf=$(mktemp -p /tmp lukskey.XXXXXX)
      umask 077; printf '%s' "$CONFIG_LUKS_PASSPHRASE" > "$_kf"
      cryptsetup luksFormat --type luks2 --key-file "$_kf" "$P_ROOT"
      cryptsetup open --key-file "$_kf" "$P_ROOT" root
      shred -u "$_kf" 2>/dev/null || rm -f "$_kf"
    else
      cryptsetup luksFormat --type luks2 "$P_ROOT"
      cryptsetup open "$P_ROOT" root
    fi
    mkfs.ext4 -L root "$CRYPT_ROOT"
  else
    info "root 分区不加密，直接 ext4..."
    mkfs.ext4 -L root "$P_ROOT"
  fi

  # home：可选加密
  if [[ "$CONFIG_ENCRYPT" == "yes" ]]; then
    info "为 home 分区 ($P_HOME) 设置 LUKS ..."
    if [[ -n "${CONFIG_LUKS_KEYFILE:-}" && -f "$CONFIG_LUKS_KEYFILE" ]]; then
      cryptsetup luksFormat --type luks2 --key-file "$CONFIG_LUKS_KEYFILE" "$P_HOME"
      cryptsetup open --key-file "$CONFIG_LUKS_KEYFILE" "$P_HOME" home
    elif [[ -n "${CONFIG_LUKS_PASSPHRASE:-}" && "$UNATTENDED" == "1" ]]; then
      local _hk
      _hk=$(mktemp -p /tmp lukskey.XXXXXX)
      umask 077; printf '%s' "$CONFIG_LUKS_PASSPHRASE" > "$_hk"
      cryptsetup luksFormat --type luks2 --key-file "$_hk" "$P_HOME"
      cryptsetup open --key-file "$_hk" "$P_HOME" home
      shred -u "$_hk" 2>/dev/null || rm -f "$_hk"
    else
      cryptsetup luksFormat --type luks2 "$P_HOME"
      cryptsetup open "$P_HOME" home
    fi
    mkfs.ext4 -L home "$CRYPT_HOME"
  else
    info "home 分区不加密，直接 ext4..."
    mkfs.ext4 -L home "$P_HOME"
  fi

  # swap（可选）
  if [[ $SWAP_MIB -gt 0 ]]; then
    info "初始化 swap 分区 ($SWAP_DEV)..."
    mkswap "$SWAP_DEV"
  fi
}

# ---------------------------------------------------------------------------
# 阶段一：挂载
# ---------------------------------------------------------------------------
do_mount() {
  compute_devices
  mkdir -p "$CONFIG_TARGET"
  mount "$CRYPT_ROOT" "$CONFIG_TARGET"
  mkdir -p "$CONFIG_TARGET"/{boot,home,opt}
  mount "$P_ESP" "$CONFIG_TARGET/boot"
  mount "$CRYPT_HOME" "$CONFIG_TARGET/home"
  if [[ -n "$SWAP_DEV" && -b "$SWAP_DEV" ]]; then
    swapon "$SWAP_DEV" 2>/dev/null || warn "swap 挂载失败，稍后可在 chroot 内 mkswap+swapon"
  fi
  lsblk
}

# ---------------------------------------------------------------------------
# 阶段一：下载并解压 stage3（须先下载再解压）
#   CONFIG_STAGE3_URL 已设 -> 直接下载该 URL
#   未设                -> 从 Gentoo 镜像自动探测最新 stage3-amd64-${init}（init=systemd/openrc）
#   都失败              -> 回退到 links 手动浏览 / 提示手动放置
# ---------------------------------------------------------------------------
extract_stage3() {
  cd "$CONFIG_TARGET"
  local url="$CONFIG_STAGE3_URL" rel bn f init="${CONFIG_INITSYS:-systemd}"

  # 未指定 URL：自动探测最新 stable stage3（按 init 系统选择 systemd/openrc）
  if [[ -z "$url" ]]; then
    info "自动探测最新 stage3-amd64-${init} ..."
    rel=$(curl -s \
        "https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-${init}.txt" \
        2>/dev/null | awk '/^[0-9]{8}T[0-9]{6}Z\// {print $1; exit}') || rel=""
    rel="${rel%%[[:space:]]*}"
    if [[ -n "$rel" ]]; then
      url="https://distfiles.gentoo.org/releases/amd64/autobuilds/$rel"
      info "探测到: $rel"
    fi
  fi

  if [[ -n "$url" ]]; then
    bn="${url##*/}"
    info "下载 stage3: $url"
    # 继续传输 + 失败重试（网络不稳时更可靠）
    retry "$CONFIG_GIT_RETRIES" "$CONFIG_GIT_RETRY_SLEEP" \
      curl -fL -C - --progress-bar -o "$bn" "$url" || die "stage3 下载失败: $url"

    # 尝试校验 sha512（若可用）
    info "尝试获取并校验 sha512..."
    if retry "$CONFIG_GIT_RETRIES" "$CONFIG_GIT_RETRY_SLEEP" curl -fL -o "${bn}.sha512" "${url}.sha512"; then
      # 支持两种 sha 文件格式：包含文件名或仅 checksum
      if grep -q "$(printf '%s' "$bn")" "${bn}.sha512" 2>/dev/null; then
        sha512sum -c "${bn}.sha512" || die "stage3 sha512 校验失败"
      else
        # 将单列 checksum 转换为可被 sha512sum -c 使用的格式（使用临时文件以避免复杂的嵌套引号）
        tmp_sha="$(mktemp)"
        sed -E "s/^[[:space:]]*([0-9a-fA-F]{128}).*/\\1  $bn/" "${bn}.sha512" > "$tmp_sha"
        if ! sha512sum -c "$tmp_sha"; then
          rm -f "$tmp_sha"
          die "stage3 sha512 校验失败"
        fi
        rm -f "$tmp_sha"
      fi
    else
      warn "未能获取 ${bn}.sha512，继续但建议手动校验。"
      [[ "$UNATTENDED" == "1" ]] || true
    fi

  else
    warn "无法自动探测 stage3 地址。"
    if confirm "用 links 手动浏览下载 stage3？" n; then
      links https://distfiles.gentoo.org/releases/amd64/autobuilds/
    fi
    f=$(ls stage3-*.tar.xz 2>/dev/null | head -1)
    [[ -n "$f" ]] || die "未找到 stage3-*.tar.xz；请先下载放入 $CONFIG_TARGET 再重跑 install.sh"
    bn="$f"
  fi

  info "解压 $bn ..."
  tar xJpf "$bn" --xattrs-include='*.*' --numeric-owner
}

# ---------------------------------------------------------------------------
# 阶段一：chroot 前准备（挂载 proc/sys/dev + 网络）
# ---------------------------------------------------------------------------
chroot_prep() {
  cp -L /etc/resolv.conf "$CONFIG_TARGET/etc/" 2>/dev/null || true
  mount -t proc proc "$CONFIG_TARGET/proc"
  mount --rbind /sys "$CONFIG_TARGET/sys"
  mount --make-rslave "$CONFIG_TARGET/sys"
  mount --rbind /dev "$CONFIG_TARGET/dev"
  mount --make-rslave "$CONFIG_TARGET/dev"
}

# ---------------------------------------------------------------------------
# init 系统辅助（systemd / openrc）
# ---------------------------------------------------------------------------
is_systemd() { [[ "${CONFIG_INITSYS:-systemd}" == "systemd" ]]; }

# 自动选择匹配 init 系统的 desktop profile（替代新手手动 eselect）
#   systemd -> .../desktop/gnome/systemd（优先）或 .../desktop/systemd
#   openrc  -> .../desktop/gnome（不含 systemd 的 17.1 变体）
select_profile() {
  local pat target num
  if is_systemd; then
    pat='desktop/gnome/systemd'
  else
    pat='desktop/gnome'
  fi
  target=$(eselect profile list 2>/dev/null | grep "$pat" | head -1)
  if is_systemd && [[ -z "$target" ]]; then
    target=$(eselect profile list 2>/dev/null | grep 'desktop/systemd' | head -1)
  fi
  if ! is_systemd; then
    # openrc：去掉误带 systemd 的行
    target=$(eselect profile list 2>/dev/null | grep "$pat" | grep -v systemd | head -1)
  fi
  if [[ -z "$target" ]]; then
    warn "未自动匹配到 desktop profile，请手动: eselect profile list && eselect profile set <编号>"
    return 1
  fi
  num=$(printf '%s\n' "$target" | sed -E 's/.*\[([0-9]+)\].*/\1/')
  info "自动选择 profile: $(printf '%s\n' "$target" | sed -E 's/^\s*//')"
  if [[ -n "$num" ]]; then
    eselect profile set "$num" || { warn "eselect profile set 失败，请手动设置"; return 1; }
  else
    warn "未解析出 profile 编号，请手动: eselect profile set <编号>"
    return 1
  fi
}


# 启用服务：systemd 用 systemctl，openrc 用 rc-update
svc_enable() {
  local svc
  for svc in "$@"; do
    if is_systemd; then
      systemctl enable "$svc"
    else
      rc-update add "$svc" default
    fi
  done
}

# 设置主机名：systemd 用 hostnamectl，openrc 写 /etc/conf.d/hostname + /etc/hosts
set_hostname() {
  local hn="${1:-gentoo}"
  if is_systemd; then
    hostnamectl set-hostname "$hn"
  else
    printf 'hostname="%s"\n' "$hn" > /etc/conf.d/hostname
    hostname "$hn" 2>/dev/null || true
    grep -qE "[[:space:]]${hn}[[:space:]]*$" /etc/hosts 2>/dev/null \
      || sed -i "/127.0.0.1[[:space:]]/ s/$/ ${hn}/" /etc/hosts
  fi
}

# ---------------------------------------------------------------------------
# 阶段二：chroot 内系统配置（install.sh --chroot）
# ---------------------------------------------------------------------------
chroot_setup() {
  require_root
  compute_devices
  info "应用仓库内配置（make.conf / genkernel.conf / 内核配置）..."
  mkdir -p /etc/portage
  if [[ -f $MAKE_CONF_SRC ]]; then
    cp "$MAKE_CONF_SRC" /etc/portage/make.conf
    info "已应用仓库 make.conf"
  else
    warn "未找到 make.conf ($MAKE_CONF_SRC)"
  fi
  [[ -f "$GEKK_CONF_SRC" ]] && cp "$GEKK_CONF_SRC" /etc/genkernel.conf || warn "未找到 genkernel.conf"

  # repos.conf（emerge-webrsync 会维护 [gentoo] 段）
  mkdir -p /etc/portage/repos.conf
  [[ -f /etc/portage/repos.conf/gentoo.conf ]] || cp /usr/share/portage/config/repos.conf /etc/portage/repos.conf/gentoo.conf

  source /etc/profile
  emerge-webrsync || warn "emerge-webrsync 失败，继续尝试 --sync"
  emerge -1 eselect-repository

  # 可选：启用并同步 gentoo-zh overlay（git 仓库，需先装 git）
  if [[ "${CONFIG_GENTOO_ZH:-yes}" == "yes" ]]; then
    eselect repository enable gentoo-zh || die "启用 gentoo-zh 失败"
    emerge -1 dev-vcs/git
    emerge --sync --repo gentoo-zh || warn "gentoo-zh 同步失败"
  else
    info "CONFIG_GENTOO_ZH=no，跳过 gentoo-zh"
  fi

  emerge --sync || true

  # profile：自动选择匹配 init 系统的 desktop profile
  if ! select_profile; then
    # 自动匹配失败：列出供手动选择
    info "可用 profile："
    eselect profile list
    confirm "是否打开 eselect 手动选择 profile？" n && eselect profile set
  fi

  # 时区 / locale
  echo "$CONFIG_TIMEZONE" > /etc/timezone
  emerge --config sys-libs/timezone-data
  cat > /etc/locale.gen <<'EOF'
en_US.UTF-8 UTF-8
en_US ISO-8859-1
zh_CN.UTF-8 UTF-8
zh_CN GB2312
C.UTF-8 UTF-8
EOF
  locale-gen

  # 内核源码 + 工具
  emerge -1 sys-kernel/gentoo-sources sys-apps/pciutils sys-kernel/genkernel sys-fs/cryptsetup

  # /etc/crypttab（加密时才需要，且必须先于 genkernel）
  if [[ "$CONFIG_ENCRYPT" == "yes" ]]; then
    cat > /etc/crypttab <<EOF
root   ${P_ROOT}  none  luks,discard
home   ${P_HOME}  none  luks,discard
EOF
  fi

  # 内核配置：拷入仓库 6.18.48（含固件）
  if [[ -f "$KERNEL_CONF_SRC" ]]; then
    mkdir -p /usr/src/linux
    cp "$KERNEL_CONF_SRC" /usr/src/linux/.config
    info "已使用内核配置: $KERNEL_CONF_SRC"
  fi
  genkernel --kernel-config=/usr/src/linux/.config --luks all

  # genfstab + fstab
  emerge -1 genfstab
  genfstab -U / > /etc/fstab.v && cp /etc/fstab.v /etc/fstab

  # 基础服务（按 init 系统启用：systemd=systemctl，openrc=rc-update）
  emerge cronie mlocate dhcpcd acpid openssh sudo
  svc_enable cronie sshd acpid dhcpcd
  if is_systemd; then
    warn "请设置 root 密码: passwd（并视需要 visudo 配置 sudo）"
  else
    warn "OpenRC：请设置 root 密码: passwd；并核对 /etc/conf.d/hostname、/etc/hosts"
  fi

  # 主机名 + 用户
  set_hostname "$CONFIG_HOSTNAME"
  if ! id -u "$CONFIG_USER" >/dev/null 2>&1; then
    useradd -m -G users,wheel,audio,lp,cdrom,portage,cron,video,usb,input -s /bin/bash "$CONFIG_USER"
    warn "请为 $CONFIG_USER 设置密码: passwd $CONFIG_USER"
  fi

  info "阶段二（基础 + 内核）完成。接下来: bash /root/install.sh --desktop，之后 --zsh、--grub"
}

# ---------------------------------------------------------------------------
# 阶段三：桌面（chroot 内，安装 GNOME；先在 /etc/portage/package.use 确认 USE）
# ---------------------------------------------------------------------------
setup_desktop() {
  require_root
  if [[ "$CONFIG_DESKTOP" == "none" || -z "$CONFIG_DESKTOP" ]]; then
    info "CONFIG_DESKTOP=none，跳过桌面安装。"
    return 0
  fi

  # 安装 GNOME 前的 USE 确认：package.use 必须先就位
  if [[ -d /etc/portage/package.use && -n "$(ls -A /etc/portage/package.use 2>/dev/null)" ]]; then
    info "确认 /etc/portage/package.use/: $(ls /etc/portage/package.use | tr '\n' ' ')"
  else
    warn "/etc/portage/package.use 为空或不存在（需在 emerge gnome 前确定 USE）。"
    confirm "仍然继续安装 GNOME？" n || die "已取消；请先配置 /etc/portage/package.use"
  fi

  # 可选：安装前让用户 review 各 USE 文件
  confirm "编辑 /etc/portage/package.use/* 后再安装 GNOME？" n && {
    nano /etc/portage/package.use/gnome
  }

  # 编译 GNOME 会耗时很久（可能 1-2 小时+），先给新手明确提示
  warn "即将编译并安装 GNOME，可能耗时 1~2 小时以上，过程中请勿中断。"
  warn "（并行任务数受 make.conf 的 MAKEOPTS=-j8 -l8 控制）"

  # 去掉 --ask（避免卡在交互确认），改用 --jobs/--load-average 并行编译多个包
  local ncores; ncores=$(nproc 2>/dev/null || echo 4)
  [[ $ncores -gt 8 ]] && ncores=8
  emerge --jobs "$ncores" --load-average 8 gnome vim
  if [[ -n "$CONFIG_USER" ]]; then
    gpasswd -a "$CONFIG_USER" plugdev 2>/dev/null || true
  fi
  if is_systemd; then
    svc_enable gdm
  else
    rc-update add dbus default 2>/dev/null || true
    rc-update add gdm default
  fi
  info "桌面（GNOME）完成。接下来: bash /root/install.sh --zsh，之后 --grub"
}

# ---------------------------------------------------------------------------
# 阶段：extras（可选体验包，chroot 内，可单独运行 --extras）
# 推荐软件集合由 CONFIG_EXTRAS_PACKAGES 指定，可交互确认或 unattended 自动化
setup_extras() {
  require_root
  # 如果用户未显式要求，交互时询问
  if [[ "${UNATTENDED:-0}" != "1" ]]; then
    if [[ "${CONFIG_EXTRAS}" != "yes" ]]; then
      if ! confirm "是否安装 README 中推荐的额外体验软件（${CONFIG_EXTRAS_PACKAGES%% *} ...）？" n; then
        info "跳过 extras 安装"
        return 0
      fi
    fi
  else
    # unattended 模式：若未配置为安装，直接跳过
    if [[ "${CONFIG_EXTRAS}" != "yes" ]]; then
      warn "unattended 模式且 CONFIG_EXTRAS != yes，跳过 extras 安装"
      return 0
    fi
  fi

  warn "开始安装 extras：${CONFIG_EXTRAS_PACKAGES}。这可能很耗时，视包与编译情况而定。"
  local ncores; ncores=$(nproc 2>/dev/null || echo 2)
  [[ $ncores -gt 8 ]] && ncores=8
  emerge --jobs "$ncores" --load-average $((ncores*2)) ${CONFIG_EXTRAS_PACKAGES}
  info "extras 安装完成（或部分失败，查看 emerge 输出）。"
}

# 阶段：zsh + Powerlevel10k + zsh-autosuggestions（chroot 内，可选运行）
#   autosuggestions 主树/gentoo-zh 均无，用官方 git clone 方式装入 ~/.zsh/
# ---------------------------------------------------------------------------
# 安装 Nerd Font 的辅助函数（尝试 emerge，失败则从 GitHub release 拉取 Meslo）
install_nerd_font() {
  require_root
  local fontdir="/usr/local/share/fonts/nerd-fonts"
  mkdir -p "$fontdir"
  # 先尝试 gentoo 包
  if has_cmd emerge; then
    if emerge --search -s "nerd-fonts" >/dev/null 2>&1; then
      info "尝试通过 emerge 安装 nerd-fonts"
      emerge -1 app-fonts/nerd-fonts || warn "emerge app-fonts/nerd-fonts 失败，回退到手动下载"
      fc-cache -f -v || true
      return 0
    fi
  fi

  # 回退：从官方 release 下载 Meslo.zip（使用 latest release 下载链接）
  local mesh_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Meslo.zip"
  local tmpd tmpf
  tmpd=$(mktemp -d)
  tmpf="$tmpd/meslo.zip"
  if retry "$CONFIG_GIT_RETRIES" "$CONFIG_GIT_RETRY_SLEEP" curl -fL -o "$tmpf" "$mesh_url"; then
    info "解压 Meslo 到 $fontdir"
    unzip -qq -o "$tmpf" -d "$tmpd" || true
    find "$tmpd" -type f -iname "*Meslo*.ttf" -exec cp -a {} "$fontdir/" \; || true
    fc-cache -f -v || true
  else
    warn "下载 Meslo Nerd Font 失败，请手动安装 MesloLGS NF 或其他 Nerd Font"
  fi
  rm -rf "$tmpd"
}

setup_zsh() {
  require_root
  emerge app-shells/zsh app-shells/zsh-completions app-shells/powerlevel10k dev-vcs/git

  # 为指定 home 准备 zsh 环境：clone autosuggestions + 写入 ~/.zshrc
  setup_user_zsh() {
    local home="$1" owner="$2"
    mkdir -p "$home/.zsh"
    if [[ ! -d "$home/.zsh/zsh-autosuggestions/.git" ]]; then
      # 中国网络环境：clone 失败自动重试多次；GitHub 完全被墙时可用镜像前缀
      # （CONFIG_GITHUB_BASE 如 https://ghproxy.com/ 会拼成 ghproxy.com/zsh-users/...）
      local clone_url="${CONFIG_GITHUB_BASE%/}/zsh-users/zsh-autosuggestions"
      retry "$CONFIG_GIT_RETRIES" "$CONFIG_GIT_RETRY_SLEEP" \
        git clone --depth 1 "$clone_url" \
        "$home/.zsh/zsh-autosuggestions" || warn "clone zsh-autosuggestions 多次失败（可设 CONFIG_GITHUB_BASE 换镜像）"
    fi
    [[ -e "$home/.zshrc" ]] || : > "$home/.zshrc"
    grep -q "powerlevel10k" "$home/.zshrc" 2>/dev/null && return 0
    cat >> "$home/.zshrc" <<'ZSHRC'

# History
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory incappendhistory histignorealldups sharehistory

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' use-cache 1

# zsh-autosuggestions（git clone 方式，需先装 git）
[[ -d ~/.zsh/zsh-autosuggestions ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh

# Powerlevel10k
source "/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme"
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
ZSHRC
    chown -R "$owner" "$home/.zsh" "$home/.zshrc"
  }

  # root 默认 shell
  chsh -s /bin/zsh
  setup_user_zsh /root root

  # 目标用户（若存在）
  if [[ -n "$CONFIG_USER" ]] && id -u "$CONFIG_USER" >/dev/null 2>&1; then
    chsh -s /bin/zsh "$CONFIG_USER"
    local home; home="$(getent passwd "$CONFIG_USER" | cut -d: -f6)"
    setup_user_zsh "$home" "$CONFIG_USER"
  fi

  # 安装/提示 Nerd Font
  install_nerd_font || warn "自动安装 Nerd Font 失败，请手动安装 MesloLGS NF 或其他 Nerd Font"

  info "zsh + Powerlevel10k + zsh-autosuggestions 已就绪。首次登录运行 'p10k configure' 完成主题向导；"
  info "主题图标需 Nerd Font（如 MesloLGS NF），请到终端设置里切换字体。"
}

# ---------------------------------------------------------------------------
# 阶段三：GRUB（chroot 内）
# ---------------------------------------------------------------------------
setup_grub() {
  require_root
  compute_devices
  emerge -1 sys-boot/grub:2
  # prefer non-removable installation when efibootmgr and efivars are present
  if has_cmd efibootmgr && [[ -d /sys/firmware/efi/efivars ]]; then
    grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Gentoo
    if has_cmd efibootmgr; then
      efibootmgr --create --disk "$CONFIG_DISK" --part 1 --label "Gentoo" --loader '\\EFI\\Gentoo\\grubx64.efi' || warn "efibootmgr 创建引导项失败（请手动检查）"
    fi
  else
    warn "无法使用 efibootmgr 或未在 EFI 环境，回退到 --removable 模式"
    grub-install --target=x86_64-efi --efi-directory=/boot --removable
  fi
  if [[ "$CONFIG_ENCRYPT" == "yes" ]]; then
    echo 'GRUB_CMDLINE_LINUX="crypt_root='"${P_ROOT}"' root=/dev/mapper/root"' >> /etc/default/grub
  fi
  grub-mkconfig -o /boot/grub/grub.cfg
}

# ---------------------------------------------------------------------------
# 阶段四：尾处理（卸载 / 关闭加密卷 / 重启）
# ---------------------------------------------------------------------------
finalize() {
  require_root
  compute_devices
  cd /
  umount -R "$CONFIG_TARGET"
  if [[ "$CONFIG_ENCRYPT" == "yes" ]]; then
    cryptsetup close home 2>/dev/null || true
    cryptsetup close root 2>/dev/null || true
  fi
  swapoff "$SWAP_DEV" 2>/dev/null || true
  confirm "重启？" y && reboot
}

# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
main() {
  local mode="${1:-interactive}"

  if [[ "$mode" == "interactive" ]]; then
    require_tools
    trap cleanup ERR
    if ! fetch_repo_assets; then warn "自动获取仓库附件失败，部分功能可能缺失（可手动放入仓库）"; fi
    interactive_config
    prep_disk; do_mount; extract_stage3; chroot_prep

  elif [[ "$mode" == "unattended" ]]; then
    UNATTENDED=1
    require_tools
    trap cleanup ERR
    fetch_repo_assets || die "无法获取必要的仓库附件，退出"
    prep_disk; do_mount; extract_stage3; chroot_prep

  elif [[ "$mode" == "--chroot" ]]; then
    # 读取阶段一写入的配置（若存在），否则用命令行环境变量
    [[ -f /root/install.env ]] && source /root/install.env
    chroot_setup
    return 0

  elif [[ "$mode" == "--grub" ]]; then
    [[ -f /root/install.env ]] && source /root/install.env
    setup_grub
    return 0

  elif [[ "$mode" == "--desktop" ]]; then
    [[ -f /root/install.env ]] && source /root/install.env
    setup_desktop
    return 0

  elif [[ "$mode" == "--zsh" ]]; then
    [[ -f /root/install.env ]] && source /root/install.env
    setup_zsh
    return 0

  elif [[ "$mode" == "--extras" ]]; then
    [[ -f /root/install.env ]] && source /root/install.env
    setup_extras
    return 0

  elif [[ "$mode" == "--final" ]]; then
    [[ -f /root/install.env ]] && source /root/install.env
    finalize
    return 0

  else
    die "未知参数: $mode"
  fi

  # 阶段一公共收尾：拷贝仓库配置 + 写入分区布局，供 chroot 阶段读取
  cp "$SCRIPT_DIR/make.conf" "$SCRIPT_DIR/genkernel.conf" "$SCRIPT_DIR/6.18.48" "$CONFIG_TARGET/root/" 2>/dev/null || true
  # package.use 直接拷入 /etc/portage（须在 emerge gnome 前就位）
  if [[ -d "$SCRIPT_DIR/etc/portage/package.use" ]]; then
    mkdir -p "$CONFIG_TARGET/etc/portage/package.use"
    cp "$SCRIPT_DIR"/etc/portage/package.use/* "$CONFIG_TARGET/etc/portage/package.use/" 2>/dev/null || true
    info "已拷入 package.use: $(ls "$SCRIPT_DIR/etc/portage/package.use" | tr '\n' ' ')"
  else
    warn "仓库缺少 etc/portage/package.use/ 目录"
  fi
  cat > "$CONFIG_TARGET/root/install.env" <<EOF
CONFIG_DISK=$CONFIG_DISK
CONFIG_TARGET=$CONFIG_TARGET
CONFIG_USER=$CONFIG_USER
CONFIG_HOSTNAME=$CONFIG_HOSTNAME
CONFIG_TIMEZONE=$CONFIG_TIMEZONE
CONFIG_ENCRYPT=$CONFIG_ENCRYPT
CONFIG_INITSYS=$CONFIG_INITSYS
CONFIG_GENTOO_ZH=$CONFIG_GENTOO_ZH
CONFIG_DESKTOP=$CONFIG_DESKTOP
CONFIG_GIT_RETRIES=$CONFIG_GIT_RETRIES
CONFIG_GIT_RETRY_SLEEP=$CONFIG_GIT_RETRY_SLEEP
CONFIG_GITHUB_BASE=$CONFIG_GITHUB_BASE
CONFIG_ESP_SIZE=$ESP_MIB
CONFIG_ROOT_SIZE=$ROOT_MIB
CONFIG_SWAP_SIZE=$SWAP_MIB
CONFIG_BG_STEPS="$CONFIG_BG_STEPS"
CONFIG_BG_RETRIES=$CONFIG_BG_RETRIES
CONFIG_BG_SLEEP=$CONFIG_BG_SLEEP
EOF

  # 生成后台 runner 脚本并复制到目标 /root/（供 live 环境以 chroot 调用）
  write_bg_runner() {
    cat > "$SCRIPT_DIR/auto_install_runner.sh" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail
# 这个 runner 在 live(host) 环境运行：它会 chroot 到目标并执行 install.sh 子命令
LOG="/var/log/gentoo_auto_install_runner.log"
exec > >(tee -a "$LOG") 2>&1

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARTDIR="$SCRIPT_DIR/artifacts"
mkdir -p "$ARTDIR"

TARGET="${CONFIG_TARGET:-/mnt/gentoo}"
RETRIES=${CONFIG_BG_RETRIES:-5}
SLEEP_SECS=${CONFIG_BG_SLEEP:-60}
STEPS="${CONFIG_BG_STEPS:---chroot --desktop --zsh --grub}"

read -r -a steps <<< "$STEPS"

for step in "${steps[@]}"; do
  ok=0
  attempt=0
  while [[ $attempt -lt $RETRIES ]]; do
    attempt=$((attempt+1))
    ts=$(date -u +%Y%m%dT%H%M%SZ)
    echo "[runner] 执行 step=$step (尝试 $attempt/$RETRIES)"
    # 在目标 chroot 中运行子任务并收集返回码
    if chroot "$TARGET" /bin/bash -lc "/root/install.sh '$step'"; then
      ok=1
      # 成功后抓取 emerge/日志快照到 artifacts
      echo "[runner] step=$step 成功，收集日志..."
      chroot "$TARGET" /bin/bash -lc "mkdir -p /root/artifacts && tar czf /root/artifacts/${step}-${ts}.tgz /var/log /var/tmp/portage || true"
      cp "$TARGET/root/artifacts/${step}-${ts}.tgz" "$ARTDIR/" 2>/dev/null || true
      break
    fi
    echo "[runner] step=$step 失败，$SLEEP_SECS 秒后重试"
    # 在失败时仍尝试收集日志以便诊断
    chroot "$TARGET" /bin/bash -lc "mkdir -p /root/artifacts && tar czf /root/artifacts/${step}-failed-${ts}.tgz /var/log /var/tmp/portage || true"
    cp "$TARGET/root/artifacts/${step}-failed-${ts}.tgz" "$ARTDIR/" 2>/dev/null || true
    sleep "$SLEEP_SECS"
  done
  if [[ $ok -ne 1 ]]; then
    echo "[runner] step=$step 多次失败，退出并保留日志（在 $ARTDIR）"
    exit 2
  fi
done

echo "[runner] 所有步骤完成。 日志与抓取文件位于: $ARTDIR"
RUNNER
    chmod +x "$SCRIPT_DIR/auto_install_runner.sh"
    # 也把 runner 复制到目标 root 便于离线查看
    cp "$SCRIPT_DIR/auto_install_runner.sh" "$CONFIG_TARGET/root/" 2>/dev/null || true
  }

  if [[ "$UNATTENDED" == "1" ]]; then
    write_bg_runner
    info "启动后台自动化 runner（nohup + setsid）"
    # 在 host 上直接运行 runner（它会负责 chroot 到目标），避免在 chroot 内再 chroot
    nohup setsid "$SCRIPT_DIR/auto_install_runner.sh" >/dev/null 2>&1 &
    info "后台 runner 已启动（日志: /var/log/gentoo_auto_install_runner.log，抓取文件位于 $SCRIPT_DIR/artifacts/）"
  fi

  cat <<EOF
==================================================
阶段一完成。接下来：
  1) 进入 chroot:
     chroot "$CONFIG_TARGET" /bin/bash && source /etc/profile
  2) 在 chroot 内继续（基础 + 内核）:
     bash /root/install.sh --chroot
  3) 桌面（安装 GNOME 前先确认 /etc/portage/package.use/）:
     bash /root/install.sh --desktop
  4) 安装 GRUB:
     bash /root/install.sh --grub
  5) 回到 ISO，卸载并重启（此时 GNOME 已编译完成）:
     sudo bash /root/install.sh --final
==================================================
EOF
}

main "${1:-interactive}"
