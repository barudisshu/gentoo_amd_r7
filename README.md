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
amd-ucode/microcode_amd_fam19h.bin,amd/amd_sev_fam19h_model0xh.sbin,amd/amd_sev_fam19h_model1xh.sbin,amd/amd_sev_fam1ah_model0xh.sbin,amdgpu/psp_14_0_2_ta.bin,amdgpu/psp_14_0_2_sos.bin,amdgpu/dcn_4_0_1_dmcub.bin,amdgpu/gc_11_5_1_pfp.bin,amdgpu/gc_11_5_1_me.bin,amdgpu/gc_11_5_1_rlc.bin,amdgpu/gc_11_5_1_mec.bin,amdgpu/gc_11_5_1_imu.bin,amdgpu/sdma_7_0_1.bin,amdgpu/vcn_5_0_1.bin,amdgpu/smu_14_0_2.bin,amdgpu/umsch_mm_4_0_0.bin,amdgpu/vpe_6_1_1.bin,amdnpu/17f0_11/npu.sbin,mediatek/mt7925/WIFI_MT7925_PATCH_MCU_1_1_hdr.bin,mediatek/mt7925/WIFI_RAM_CODE_MT7925_1_1.bin,mediatek/mt7925/BT_RAM_CODE_MT7925_1_1_hdr.bin,rtl_nic/rtl8168h-2.fw,rtl_nic/rtl8156b-2.fw
```

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

mkfs.ext4 -L root /dev/nvme0n1p2
mkfs.ext4 -L home /dev/nvme0n1p3

```

```shell
mount /dev/nvme0n1p2 /mnt/gentoo
mkdir -p /mnt/gentoo{/boot,/home,/opt,}
mount /dev/nvme0n1p1 /mnt/gentoo/boot
mount /dev/nvme0n1p3 /mnt/gentoo/home
lsblk
```

```shell
cd /mnt/gentoo
links https://www.gentoo.org/downloads/mirrors/

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
```

```shell
eselect profile list
# [6]  default/linux/amd64/23.0/desktop/gnome/systemd (stable)
eselect profile set 6
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
emerge -avuDN @world
cat /var/lib/portage/world
```

```shell
emerge eselect-repository
eselect repository enable gentoo-zh
emerge --sync
```

```shell
nano -w /etc/genkernel.conf
```

```shell
emerge --ask genfstab
genfstab -U / >> /etc/fstab
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
hostnamectl set-hostname <hostname>
```

```shell
exit
cd
umount -R /mnt/gentoo
reboot
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
