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
#     bash /root/install.sh --grub        # GRUB
#   尾处理（ISO 环境）:
#     sudo bash install.sh --final
#
#   非交互（跳过提问，全部用环境变量/默认值）:
#     CONFIG_DISK=/dev/nvme0n1 CONFIG_INITSYS=openrc CONFIG_ENCRYPT=yes \
#       sudo bash install.sh --unattended
#   覆盖 gentoo-zh（默认 yes）:
#     CONFIG_GENTOO_ZH=no sudo bash install.sh
#
set -euo pipefail

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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# 工具函数
# ---------------------------------------------------------------------------
die() { echo -e "\e[31m[错误]\e[0m $*" >&2; exit 1; }
info() { echo -e "\e[32m[==>]\e[0m $*"; }
warn() { echo -e "\e[33m[警告]\e[0m $*" >&2; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

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

partition_dev() { # DISK -> 分区设备（nvme 为 pN，其余按 udev 规则）
  case "$1" in
    *nvme*|*mmcblk*|*nbd*|*loop*) echo "${1}p$2" ;;
    *) echo "${1}$2" ;;
  esac
}

require_root() { [[ "$(id -u)" -eq 0 ]] || die "请以 root 运行"; }

require_tools() {
  local t
  for t in parted cryptsetup mkfs.ext4 mkfs.vfat tar links nano blkid curl; do
    has_cmd "$t" || warn "缺少命令: $t（可先 emerge -1 $t）"
  done
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
  confirm "确认继续？" y || die "已取消"
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
    info "为 root 分区 ($P_ROOT) 设置 LUKS 口令..."
    cryptsetup luksFormat --type luks2 "$P_ROOT"
    cryptsetup open "$P_ROOT" root
    mkfs.ext4 -L root "$CRYPT_ROOT"
  else
    info "root 分区不加密，直接 ext4..."
    mkfs.ext4 -L root "$P_ROOT"
  fi

  # home：可选加密
  if [[ "$CONFIG_ENCRYPT" == "yes" ]]; then
    info "为 home 分区 ($P_HOME) 设置 LUKS 口令..."
    cryptsetup luksFormat --type luks2 "$P_HOME"
    cryptsetup open "$P_HOME" home
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
    curl -fL --progress-bar -o "$bn" "$url" || die "stage3 下载失败: $url"
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

  # profile：提示用户选择与 init 系统匹配的 desktop profile
  info "可用 profile："
  eselect profile list
  if is_systemd; then
    warn "请手动: eselect profile set <编号> (选 default/linux/amd64/.../desktop/gnome/systemd) 后继续"
  else
    warn "请手动: eselect profile set <编号> (选 default/linux/amd64/.../desktop/gnome (无 systemd/17.1)) 后继续"
  fi
  # openrc 需要手动把系统切到非 systemd 的 profile；此处仅提示

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

  info "阶段二（基础 + 内核）完成。接下来: bash /root/install.sh --desktop，之后 --grub"
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

  emerge --ask gnome vim
  if [[ -n "$CONFIG_USER" ]]; then
    gpasswd -a "$CONFIG_USER" plugdev 2>/dev/null || true
  fi
  if is_systemd; then
    svc_enable gdm
  else
    rc-update add dbus default 2>/dev/null || true
    rc-update add gdm default
  fi
  info "桌面（GNOME）完成。接下来: bash /root/install.sh --grub"
}

# ---------------------------------------------------------------------------
# 阶段三：GRUB（chroot 内）
# ---------------------------------------------------------------------------
setup_grub() {
  require_root
  compute_devices
  emerge -1 sys-boot/grub:2
  # --removable 在 merge-usr 版本存在 bug，见 README 注释
  grub-install --target=x86_64-efi --efi-directory=/boot --removable
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
    interactive_config
    prep_disk; do_mount; extract_stage3; chroot_prep

  elif [[ "$mode" == "unattended" ]]; then
    UNATTENDED=1
    require_tools
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
CONFIG_ESP_SIZE=$ESP_MIB
CONFIG_ROOT_SIZE=$ROOT_MIB
CONFIG_SWAP_SIZE=$SWAP_MIB
EOF
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
