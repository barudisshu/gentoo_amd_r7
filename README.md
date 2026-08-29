# Gentoo AMD Ryzen 7

Also make a reference of

- https://wiki.gentoo.org/wiki/Lenovo_Ideapad_Slim_7
- https://wiki.gentoo.org/wiki/Lenovo_Thinkpad_T495

> 自动化安装（UEFI + 可选 LUKS + ext4，按磁盘容量自动分区）见仓库中的 `install.sh`；
> 下方的手动步骤与之对应，可二选一使用。
>
> `install.sh` 支持 init 系统选择：交互时会询问 **systemd / openrc**（默认 systemd），
> 并据所选分支自动下载对应的 stage3、提示匹配的 profile、按 systemctl / rc-update 启用服务。
> 下方手动步骤以 systemd 为例；OpenRC 用户把 stage3 换成 `stage3-amd64-openrc-*`、
> 选不含 systemd 的 profile，并把 `systemctl enable X` 换成 `rc-update add X default` 即可。
>
> `install.sh` 默认会自动启用并同步 **gentoo-zh** overlay（chroot 阶段早期、装其它东西之前）
> ——它会在装 `dev-vcs/git` 后单独 `emerge --sync --repo gentoo-zh`；如需关闭：
> `CONFIG_GENTOO_ZH=no sudo bash install.sh` 或交互时选 n。
>
> 字体 (Powerlevel10k 相关)
> - 脚本在 --zsh 阶段会尝试安装 Nerd Font（Powerlevel10k 推荐）。优先使用 Gentoo 包 `app-fonts/nerd-fonts`；若包不可用或网络受限，会回退到从 GitHub Releases 下载 Meslo.zip（MesloLGS Nerd Font）并安装到 `/usr/local/share/fonts/nerd-fonts`，之后运行 `fc-cache`。
> - 如果在中国大陆或其它受限网络，请设置 `CONFIG_GITHUB_BASE` 指向可用镜像（例如 `https://ghproxy.com`），或手动把 Meslo.zip 放在可访问位置并在安装后复制到 `/usr/local/share/fonts/nerd-fonts` 并运行 `fc-cache`。
>
> 单文件下载场景（只拿到 `install.sh`）
> - 若用户只下载了单个 `install.sh`，脚本会尝试从 GitHub 仓库（默认 `barudisshu/gentoo_amd_r7`）下载仓库 tarball 并提取缺失的辅助文件（`make.conf`、`genkernel.conf`、`6.18.48`、`etc/portage/package.use`）。
> - 若仓库 tarball 不可达，请设置 `CONFIG_GITHUB_BASE` 或直接 git clone 整个仓库以保证完整性。
> - 示例：
>   `CONFIG_GITHUB_BASE=https://ghproxy.com sudo bash install.sh --unattended`

## Prepare

```shell
# check your device
lspci -nnk
lsusb
lsusb -t
lscpu
lsinput -v
libinput list-devices
```

format USB

```shell
sudo umount /dev/sda3

sudo dd if=/isos/gentoo-**-.iso of=/dev/sda bs=1M status=progress
```

```shell
sudo mkfs.ext4 /dev/sda3
sudo fsck /dev/sda3
```

Backup the home directory of your linux system

```shell
sudo rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" /home/ /mnt/usbdrive/
```

Restore the home directory of your linux system

```shell
sudo rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" /mnt/usbdrive/ /home/
```

net work

```shell
rfkill unblock all
net-setup

passwd

/etc/init.d/sshd start

```

## firmware

Ryzen 7 5800HZ

```
amd-ucode/microcode_amd_fam19h.bin,amd/amd_sev_fam19h_model0xh.sbin,iwlwifi-cc-a0-46.ucode,amdgpu/green_sardine_asd.bin,amdgpu/green_sardine_ce.bin,amdgpu/green_sardine_dmcub.bin,amdgpu/green_sardine_me.bin,amdgpu/green_sardine_mec.bin,amdgpu/green_sardine_mec2.bin,amdgpu/green_sardine_pfp.bin,amdgpu/green_sardine_rlc.bin,amdgpu/green_sardine_sdma.bin,amdgpu/green_sardine_ta.bin,amdgpu/green_sardine_vcn.bin
```

```
amd-ucode/microcode_amd_fam19h.bin,amd/amd_sev_fam19h_model0xh.sbin,amd/amd_sev_fam19h_model1xh.sbin,amd/amd_sev_fam1ah_model0xh.sbin,amdgpu/psp_13_0_4_toc.bin,amdgpu/dcn_3_1_4_dmcub.bin,amdgpu/gc_11_0_1_pfp.bin,amdgpu/sdma_6_0_1.bin,amdgpu/vcn_4_0_2.bin,amdgpu/gc_11_0_1_mes_2.bin,amdgpu/gc_11_0_1_mes.bin,amdgpu/psp_13_0_4_ta.bin,amdgpu/gc_11_0_1_me.bin,amdgpu/gc_11_0_1_mes1.bin,amdgpu/gc_11_0_1_rlc.bin,amdgpu/gc_11_0_1_mec.bin,amdgpu/gc_11_0_1_imu.bin,amdnpu/1502_00/npu.sbin
```

Ryzen AI 7

```
amd-ucode/microcode_amd_fam19h.bin,amd/amd_sev_fam19h_model0xh.sbin,amd/amd_sev_fam19h_model1xh.sbin,amd/amd_sev_fam1ah_model0xh.sbin,amdgpu/psp_14_0_2_ta.bin,amdgpu/psp_14_0_2_sos.bin,amdgpu/dcn_4_0_1_dmcub.bin,amdgpu/gc_11_5_1_pfp.bin,amdgpu/gc_11_5_1_me.bin,amdgpu/gc_11_5_1_rlc.bin,amdgpu/gc_11_5_1_mec.bin,amdgpu/gc_11_5_1_imu.bin,amdgpu/sdma_7_0_1.bin,amdgpu/vcn_5_0_1.bin,amdgpu/smu_14_0_2.bin,amdgpu/umsch_mm_4_0_0.bin,amdgpu/vpe_6_1_1.bin,amdnpu/17f0_20/npu.sbin,mediatek/mt7925/WIFI_MT7925_PATCH_MCU_1_1_hdr.bin,mediatek/mt7925/WIFI_RAM_CODE_MT7925_1_1.bin,mediatek/mt7925/BT_RAM_CODE_MT7925_1_1_hdr.bin,rtl_nic/rtl8168h-2.fw,rtl_nic/rtl8156b-2.fw
```

### Ryzen AI 7 — 已加载 (Krackan / Radeon 840M)

Hardware: AMD Krackan (Zen 5 APU), AMD Radeon 840M/860M (RDNA 3.5), AMD NPU `[1022:17f0]` rev 20, MT7925 Wi-Fi
7/Bluetooth, RTL8111/8168 rev15 ethernet, RTL8156 USB 2.5G ethernet.

| 模块     | 固件绝对路径                                                              | 描述                          |
|----------|---------------------------------------------------------------------------|-------------------------------|
| amdgpu   | `/lib/firmware/amdgpu/dcn_4_0_1_dmcub.bin`                                | 显示引擎 DMUB 固件            |
| amdgpu   | `/lib/firmware/amdgpu/vcn_5_0_1.bin`                                      | 视频编解码 (VCN) 固件         |
| amdgpu   | `/lib/firmware/amdgpu/gc_11_5_1_rlc.bin`                                  | 渲染核心 (RLC) 微码           |
| amdgpu   | `/lib/firmware/amdgpu/gc_11_5_1_mec.bin`                                  | 计算队列 (MEC) 微码           |
| amdgpu   | `/lib/firmware/amdgpu/gc_11_5_1_me.bin`                                   | 微引擎 (ME) 固件              |
| amdgpu   | `/lib/firmware/amdgpu/gc_11_5_1_pfp.bin`                                  | 预取前端 (PFP) 固件           |
| amdgpu   | `/lib/firmware/amdgpu/gc_11_5_1_imu.bin`                                  | 初始微码 (IMU)                |
| amdgpu   | `/lib/firmware/amdgpu/smu_14_0_2.bin`                                     | 电源/散热管理单元 (SMU) 固件  |
| amdgpu   | `/lib/firmware/amdgpu/psp_14_0_2_sos.bin`                                 | 平台安全处理器 (PSP) SOS 固件 |
| amdgpu   | `/lib/firmware/amdgpu/psp_14_0_2_ta.bin`                                  | PSP Trusted Application 固件  |
| amdgpu   | `/lib/firmware/amdgpu/umsch_mm_4_0_0.bin`                                 | 用户态调度器 (多媒体) 固件    |
| amdgpu   | `/lib/firmware/amdgpu/sdma_7_0_1.bin`                                     | System DMA 引擎固件           |
| amdgpu   | `/lib/firmware/amdgpu/vpe_6_1_1.bin`                                      | 视频处理引擎 (VPE) 固件       |
| amdxdna  | `/lib/firmware/amdnpu/17f0_20/npu.sbin`                                   | AI 神经处理单元 (NPU) 固件    |
| ccp      | `/lib/firmware/amd/amd_sev_fam19h_model1xh.sbin`                          | AMD SEV 安全加密虚拟化固件    |
| mt7925e  | `/lib/firmware/mediatek/mt7925/WIFI_MT7925_PATCH_MCU_1_1_hdr.bin`         | WiFi Patch MCU 微码           |
| mt7925e  | `/lib/firmware/mediatek/mt7925/WIFI_RAM_CODE_MT7925_1_1.bin`              | WiFi 主固件                   |
| btusb    | `/lib/firmware/mediatek/mt7925/BT_RAM_CODE_MT7925_1_1_hdr.bin`            | 蓝牙固件                      |
| r8169    | `/lib/firmware/rtl_nic/rtl8168h-2.fw`                                     | 以太网 PHY 固件               |
| r8152    | `/lib/firmware/rtl_nic/rtl8156b-2.fw`                                     | USB 2.5G 网卡固件             |
| cfg80211 | `/lib/firmware/regulatory.db` → `/etc/alternatives/regulatory.db`         | 无线频谱法规数据库            |
| cfg80211 | `/lib/firmware/regulatory.db.p7s` → `/etc/alternatives/regulatory.db.p7s` | regulatory.db 数字签名        |

```shell
parted /dev/nvme0n1

(parted) mklabel gpt
(parted) unit mib                                                         
(parted) mkpart primary fat32 1 513
(parted) set 1 esp on                                                      
(parted) name 1 boot                                                      
(parted) mkpart primary 1537 656897
(parted) name 2 root
(parted) mkpart primary 656897 100%                                          
(parted) name 3 home                                                      
(parted) print                                                          


...
```

```shell
mkfs.vfat -F32 /dev/nvme0n1p1
mkdir -p /mnt/gentoo

# 加载 LUKS 所需模块 (若未内建)
modprobe dm-crypt

# 加密 root 分区 (p2) 并创建 ext4 文件系统
cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
cryptsetup open /dev/nvme0n1p2 root
mkfs.ext4 -L root /dev/mapper/root

# 加密 home 分区 (p3) 并创建 ext4 文件系统
cryptsetup luksFormat --type luks2 /dev/nvme0n1p3
cryptsetup open /dev/nvme0n1p3 home
mkfs.ext4 -L home /dev/mapper/home

# 说明：本方案 ESP(p1) 与 已加密的 root(p2)/home(p3) 均已分区，没有专门的
# "/boot" 数据分区——/boot 就是 ESP(p1, vfat)，保持不解密即可由 GRUB 直接读取。
# 若确需把 /boot 单独加密，则需另建分区并在 GRUB 中启用 cryptodisk，
# 且 kernel 需 CONFIG_CRYPTO + command line 指向加密 boot。
```

```shell
mount /dev/mapper/root /mnt/gentoo
mkdir -p /mnt/gentoo{/boot,/home,/opt,}
mount /dev/nvme0n1p1 /mnt/gentoo/boot
mount /dev/mapper/home /mnt/gentoo/home
lsblk
```

```shell
# 下载最新 stable stage3（systemd，amd64）——脚本会自动执行这一步
cd /mnt/gentoo
curl -fL -O https://distfiles.gentoo.org/releases/amd64/autobuilds/20260823T153057Z/stage3-amd64-systemd-20260823T153057Z.tar.xz
# 或改用手动浏览选择：
# links https://distfiles.gentoo.org/releases/amd64/autobuilds/

# 解压（记得带 --xattrs 与 --numeric-owner）
tar xJpf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner
```

```shell
GENTOO_MIRRORS="https://mirrors.tuna.tsinghua.edu.cn/gentoo/"
sync-uri = rsync://mirrors.tuna.tsinghua.edu.cn/gentoo-portage
```

```shell
mkdir /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
nano -w /mnt/gentoo/etc/portage/repos.conf/gentoo.conf 
```

```shell
cp -L /etc/resolv.conf /mnt/gentoo/etc/
```

```shell
# 注意：此处假定加密分区已在 "mkfs / mount" 步骤中解锁并挂载到 /mnt/gentoo 下
# （cryptsetup open + mount /dev/mapper/root|home）。切勿在此处再次打开它们。
mount -t proc proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
```

```shell
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"
```

```shell
emerge-webrsync
emerge eselect-repository
emerge dev-vcs/git        # gentoo-zh 是 git overlay，需要 git
eselect repository enable gentoo-zh
emerge --sync --repo gentoo-zh
```

```shell
eselect profile list
# 选择带 systemd + desktop 的 profile，例如：
# [21]  default/linux/amd64/23.0/desktop/gnome/systemd (stable)
eselect profile set <编号>
```

```shell
emerge --ask ufed
emerge --ask cpuid2cpuflags
emerge --ask resolve-march-native
```

```shell
echo "Asia/Shanghai" > /etc/timezone
emerge --config sys-libs/timezone-data
nano -w /etc/locale.gen
```

```
en_US ISO-8859-1
en_US.UTF-8 UTF-8
zh_CN GB2312
zh_CN.UTF-8 UTF-8
C.UTF-8 UTF-8
```

```shell
locale-gen
```

```shell
eselect locale list
eselect locale set 2

env-update && source /etc/profile && export PS1="(chroot) $PS1"
```

```shell
emerge --ask sys-kernel/gentoo-sources sys-apps/pciutils sys-kernel/genkernel sys-fs/cryptsetup
cat /var/lib/portage/world

nano -w /etc/genkernel.conf
```

在 `/etc/genkernel.conf` 中启用 LUKS 支持（仓库内的 `genkernel.conf` 已写好，可复制）：
```
# genkernel.conf
LUKS="yes"
DMCRYPT="yes"
# 若 /boot 也加密，则加上： CRYPTBOOT="yes"
```
```shell
# 复制仓库中的 genkernel.conf（已含 LUKS / DMCRYPT / FIRMWARE_FILES）
cp /path/to/genkernel.conf /etc/genkernel.conf
```

### 创建 /etc/crypttab（必须在执行 genkernel 之前创建，genkernel 会把它打进 initramfs）
```shell
cat > /etc/crypttab <<'EOF'
root   /dev/nvme0n1p2  none  luks,discard
home   /dev/nvme0n1p3  none  luks,discard
EOF
```

### 加载随仓库提供的内核配置（含已同步的固件），再生成 fstab
```shell
cp /path/to/6.18.48 /usr/src/linux/.config
```

```shell
emerge --ask genfstab
genfstab -U / >> /etc/fstab
```

```shell
# /etc/fstab (设备可用 UUID/LABEL 替代)
/dev/mapper/root   /        ext4  noatime,commit=600,errors=remount-ro  0 1
/dev/mapper/home   /home    ext4  noatime,commit=600                    0 2
/dev/nvme0n1p1     /boot    vfat  noatime                                     0 1
```

```shell
# 使用仓库配置 + LUKS 支持构建内核与 initramfs
genkernel --kernel-config=/usr/src/linux/.config --luks all
```

```shell
emerge cronie mlocate dhcpcd acpid openssh
systemctl enable cronie sshd acpid
```

```shell
passwd
useradd -m -G users,wheel,audio,lp,cdrom,portage,cron,video,usb,input -s /bin/bash galudisu
passwd galudisu
```

```shell
emerge sudo
visudo
```

```shell
emerge net-wireless/iw net-wireless/wpa_supplicant networkmanager
systemctl enable NetworkManager bluetooth
emerge nftables
systemctl enable nftables
eselect iptables list
eselect iptables set 2
```

```shell
emerge sys-boot/grub:2
## there's a bug in `--removable` in new version grub2 while it's merge-usr distribution.
grub-install --target=x86_64-efi --efi-directory=/boot --removable

# ESP 未加密，root/home 加密 → GRUB 无需 cryptodisk，但内核命令行必须指向
# 加密根设备，否则 initramfs 无法解锁 root（会掉进紧急 shell）。
echo 'GRUB_CMDLINE_LINUX="crypt_root=/dev/nvme0n1p2 root=/dev/mapper/root"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
```

### 桌面（GNOME）——安装前先确定 `/etc/portage/package.use/*`

`emerge gnome` 依赖若干覆写 USE（如 `media-libs/opencv features2d`、`net-libs/ngtcp2 gnutls`、`net-dns/dnsmasq script` 等），必须先把这些 USE 落地到 `/etc/portage/package.use/`，否则会因依赖冲突而失败。

仓库已提供一份经过整理的 `package.use`（firefox/gnome/libvirt/nautilus/pipewire/qemu/radeon），拷入 chroot：

```shell
# 在 chroot 内（或由阶段一自动拷入）
mkdir -p /etc/portage/package.use
cp /path/to/etc/portage/package.use/* /etc/portage/package.use/
# 按需确认/修改（使用 `emerge -pv gnome` 复核 flags）
nano /etc/portage/package.use/gnome
```

之后安装 GNOME 桌面：

```shell
emerge gnome vim
gpasswd -a galudisu plugdev
systemctl enable gdm

emerge autojump tmux
```

```shell
timedatectl set-ntp true
timedatectl set-timezone Asia/Shanghai

systemd-machine-id-setup
systemd-firstboot --prompt
systemctl daemon-reexec
hostnamectl  set-hostname <hostname>
```

```shell
exit
cd
umount -R /mnt/gentoo
# 若仍有挂载残留，强制卸载后再关闭加密卷
# umount -l /mnt/gentoo/home
cryptsetup close home
cryptsetup close root
reboot
```

> 建议在 reboot 之前完成桌面编排（否则进系统后手动 `emerge gnome`）：
> ```shell
> # 在 chroot 内
> bash /root/install.sh --desktop   # 先确认 package.use 再编译安装 GNOME
> bash /root/install.sh --zsh       # (可选) zsh + Powerlevel10k
> bash /root/install.sh --grub
> # 回到 ISO 后
> sudo bash /root/install.sh --final   # 卸载/关闭加密卷/重启
> ```


#### zsh + Powerlevel10k + zsh-autosuggestions（可选，`--zsh` 已自动完成）

> `--zsh` 在 clone autosuggestions 时会**自动重试多次**（默认 5 次 / 间隔 3s，
> 用 `CONFIG_GIT_RETRIES`、`CONFIG_GIT_RETRY_SLEEP` 覆盖）。若 GitHub 完全被墙，
> 设镜像前缀即可：`CONFIG_GITHUB_BASE=https://ghproxy.com bash /root/install.sh --zsh`。

```shell
emerge app-shells/zsh app-shells/zsh-completions app-shells/powerlevel10k dev-vcs/git
chsh -s /bin/zsh            # 切换默认 shell（root / 各用户都执行）
# autosuggestions 主树/gentoo-zh 均无，用官方 git clone 方式（失败自动重试）：
git clone --depth 1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
# ~/.zshrc 中加入：
#   [[ -d ~/.zsh/zsh-autosuggestions ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
#   source "/usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme"
#   [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
# 首次登录运行 p10k configure 完成主题向导；图标需 Nerd Font（如 MesloLGS NF）。
```

若启动时 initramfs 未自动解锁，可手动解锁根分区：
```shell
# 在 GRUB 菜单按 'e' 在内核参数追加 crypt_root=/dev/nvme0n1p2 或使用 shell
cryptsetup open /dev/nvme0n1p2 root
```

## KVM

```shell
minikube start --driver=kvm2 --extra-config=kubelet.cgroup-driver=systemd --image-mirror-country='cn' --registry-mirror='https://guqcep47.mirror.aliyuncs.com' --image-repository='registry.cn-hangzhou.aliyuncs.com/google_containers' --kubernetes-version=v1.23.8
```

## App

https://wiki.gentoo.org/wiki/Recommended_applications

```shell
emerge --ask foliate evince gnote libreoffice firefox evolution geary qbittorrent imagemagick gimp flameshot inkscape shotwell mpv vlc smplayer nfs-utils vscode usbview gparted filezilla xournalpp geogebra-bin octave ibus-libpinyin
```

## Repository

https://wiki.gentoo.org/wiki/Eselect/Repository

## Fonts

https://wiki.gentoo.org/wiki/Fontconfig#Picking_fonts

```shell
emerge --ask liberation-fonts libertine noto dejavu droid sil-gentium ubuntu-font-family urw-fonts corefonts unifont wqy-zenhei wqy-microhei media-fonts/wqy-bitmapfont media-fonts/noto-emoji media-fonts/cascadia-code hack media-fonts/fira-code media-fonts/fira-mono media-fonts/fira-sans media-fonts/powerline-symbols media-fonts/nerd-fonts media-fonts/symbols-nerd-font media-fonts/powerline-symbols media-fonts/juliamono
```

## Flatpak

```shell
emerge --ask sys-apps/flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

## Docker

```shell
emerge --ask app-containers/docker-compose app-containers/docker-cli app-containers/docker-buildx app-containers/docker
usermod -aG docker galudisu
systemctl enable docker.service
```

## Libinput

https://wiki.gentoo.org/wiki/Libinput

```shell
cp /usr/share/X11/xorg.conf.d/40-libinput.conf /etc/X11/xorg.conf.d/
```

Edit `vim etc/X11/xorg.conf.d/40-libinput.conf`

```shell
Section "InputClass"
     Identifier "libinput touchpad catchall"
     MatchIsTouchpad "on"
     MatchDevicePath "/dev/input/event*"
     Option "Tapping" "True"
     Option "TappingDrag" "True"
     Option "NaturalScrolling" "True"
     Driver "libinput"
EndSection
```

## Problem

touchpad not detected: https://wiki.gentoo.org/wiki/Asus_Tuf_Gaming_fx505dy#Touchpad

audio no work: https://www.gentoo.org/support/news-items/2022-07-29-pipewire-sound-server.html

```shell
systemctl --global disable pulseaudio.service pulseaudio.socket
systemctl --global enable pipewire.service pipewire-pulse.socket
systemctl --global --force enable wireplumber.service
```

## GDM scaling

tl/dr

```shell
sudo nano /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
```

Change the default value to 2 (or your desired scale factor):

```xml

<key name="scaling-factor" type="u">
    <default>2</default>
```

and then running:

```shell
sudo glib-compile-schemas /usr/share/glib-2.0/schemas
```

This fixed it for me. Let me know if it works for you as well.

## dev-*

```shell
sudo emerge --ask maven-bin gradle-bin sbt-bin
```
