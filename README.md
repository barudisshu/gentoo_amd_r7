# Gentoo AMD Ryzen 7

Also make a reference of

- https://wiki.gentoo.org/wiki/Lenovo_Ideapad_Slim_7
- https://wiki.gentoo.org/wiki/Lenovo_Thinkpad_T495

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

# 可选：/boot 另建分区并加密 —— 需配合 GRUB 的 cryptodisk 使用
# cryptsetup luksFormat --type luks2 /dev/nvme0n1p2
# cryptsetup open /dev/nvme0n1p2 boot
# mkfs.ext4 -L boot /dev/mapper/boot
```

```shell
mount /dev/mapper/root /mnt/gentoo
mkdir -p /mnt/gentoo{/boot,/home,/opt,}
mount /dev/nvme0n1p1 /mnt/gentoo/boot
mount /dev/mapper/home /mnt/gentoo/home
lsblk
```

```shell
cd /mnt/gentoo
links https://www.gentoo.org/downloads/mirrors/

tar xvf stage3-*.tar.xz --xattrs
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
eselect repository enable gentoo-zh
emerge --sync
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

在 `/etc/genkernel.conf` 中启用 LUKS 支持：
```
# genkernel.conf
LUKS="yes"
DMCRYPT="yes"
# 若 /boot 也加密，则加上：
# CRYPTBOOT="yes"
```

```shell
emerge --ask genfstab
genfstab -U / >> /etc/fstab
```

```shell
# /etc/crypttab —— 开机时自动解锁加密分区
# 示例：<target> <source_device> <key_file> <options>
root   /dev/nvme0n1p2  none  luks,discard
home   /dev/nvme0n1p3  none  luks,discard
```

```shell
# /etc/fstab (设备可用 UUID/LABEL 替代)
/dev/mapper/root   /        ext4  noatime,commit=600,errors=remount-ro  0 1
/dev/mapper/home   /home    ext4  noatime,commit=600                    0 2
/dev/nvme0n1p1     /boot    vfat  noatime                                     0 1
```

```shell
genkernel --luks all
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

# 若 /boot (ESP) 未加密，仅 root/home 加密，则 GRUB 无需 cryptodisk；
# 根分区解密由 initramfs 依据 /etc/crypttab 在启动时提示输入口令。
grub-mkconfig -o /boot/grub/grub.cfg
```

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
