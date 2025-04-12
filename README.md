# Gentoo AMD Ryzen 7

Also make a reference of 
- https://wiki.gentoo.org/wiki/Lenovo_Ideapad_Slim_7
- https://wiki.gentoo.org/wiki/Lenovo_Thinkpad_T495

## Prepare

```bash
# check your device
lspci -nnk
lsusb
lsusb -t
lscpu
lsinput -v
libinput list-devices
```

format USB

```bash
sudo umount /dev/sda3

sudo dd if=/isos/gentoo-**-.iso of=/dev/sda bs=1M status=progress
```

```bash
sudo mkfs.ext4 /dev/sda3
sudo fsck /dev/sda3
```

Backup the home directory of your linux system

```bash
sudo rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" /home/ /mnt/usbdrive/
```

Restore the home directory of your linux system

```bash
sudo rsync -a --info=progress2 --exclude="lost+found" --exclude=".cache" /mnt/usbdrive/ /home/
```

net work

```bash
rfkill unblock all
net-setup

passwd

/etc/init.d/ssh start

```

## firmware 

Ryzen 7 5800HZ

```
amd-ucode/microcode_amd_fam19h.bin,amd/amd_sev_fam19h_model0xh.sbin,iwlwifi-cc-a0-46.ucode,amdgpu/green_sardine_asd.bin,amdgpu/green_sardine_ce.bin,amdgpu/green_sardine_dmcub.bin,amdgpu/green_sardine_me.bin,amdgpu/green_sardine_mec.bin,amdgpu/green_sardine_mec2.bin,amdgpu/green_sardine_pfp.bin,amdgpu/green_sardine_rlc.bin,amdgpu/green_sardine_sdma.bin,amdgpu/green_sardine_ta.bin,amdgpu/green_sardine_vcn.bin
```


```bash
parted /dev/nvme0n1

(parted) mklabe gpt
(parted) unit mib                                                         
(parted) mkpart ESP fat32 1 513
(parted) set 1 bios_grub on                                               
(parted) name 1 grub                                                      
(parted) mkpart primary 513 1537                                           
(parted) name 2 boot                                                      
(parted) set 2 boot on
(parted) mkpart primary 1537 247297
(parted) name 3 home
(parted) mkpart primary 247297 100%                                          
(parted) name 4 root                                                      
(parted) print                                                          


...
```

```bash
mkfs.vfat /dev/nvme0n1p2
mkfs.ext4 -L home /dev/nvme0n1p3
mkfs.ext4 -L root /dev/nvme0n1p4
```

```bash
mount /dev/nvme0n1p4 /mnt/gentoo
mkdir -p /mnt/gentoo{/boot,/home,/opt,}
mount /dev/nvme0n1p2 /mnt/gentoo/boot
mount /dev/nvme0n1p3 /mnt/gentoo/home
lsblk
```

```bash
cd /mnt/gentoo
links https://www.gentoo.org/downloads/mirrors/

tar xvf stage3-*.tar.xz --xattrs
```

```bash
GENTOO_MIRRORS="https://mirrors.ustc.edu.cn/gentoo/"
sync-uri = rsync://rsync.mirrors.ustc.edu.cn/gentoo-portage
```

```bash
mkdir /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
nano -w /mnt/gentoo/etc/portage/repos.conf/gentoo.conf 
```

```bash
cp -L /etc/resolv.conf /mnt/gentoo/etc/
```

```bash
mount -t proc proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
```

```bash
chroot /mnt/gentoo /bin/bash
source /etc/profile
export PS1="(chroot) $PS1"
```

```bash
emerge-webrsync
emerge --sync
```

```bash
eselect profile list
eselect profile set 26
```

```bash
emerge --ask ufed
emerge --ask cpuid2cpuflags
```

```bash
echo "Asia/Shanghai" > /etc/timezone
emerge --config sys-libs/timezone-data
nano -w /etc/locale.gen
```

```
en_US ISO-8859-1
en_US.UTF8 UTF-8
zh_CN GB2312
zh_CN.UTF8 UTF-8
C.UTF8 UTF-8
```


```bash
locale-gen
```

```bash
eselect locale list
eselect locale set 6

env-update && source /etc/profile && export PS1="(chroot) $PS1"
```

```bash
emerge --ask sys-kernel/gentoo-sources:6.12.16 sys-apps/pciutils sys-kernel/genkernel

nano -w /etc/genkernel.conf
```

```bash
emerge --ask genfstab
genfstab -U -p /  >> /etc/fstab
```

```bash
/dev/nvme0n1p2	        /boot   	vfat	        noauto,noatime                                  0 1
/dev/nvme0n1p5          /	        ext4	        discard,noatime,commit=600,errors=remount-ro	0 1
```

```bash
genkernel all
```

```bash
emerge cronie
emerge mlocate
emerge dhcpcd
emerge acpid
emerge openssh
systemctl enable cronie
systemctl enable sshd
systemctl enable acpid
systemctl enable sshd
```

```bash
passwd
useradd -m -G users,wheel,audio,lp,cdrom,portage,cron,video,usb -s /bin/bash galudisu
passwd galudisu
```

```bash
emerge sudo
visudo
```

```bash
emerge net-wireless/iw
emerge net-wireless/wpa_supplicant
emerge networkmanager
systemctl enable NetworkManager
systemctl enable bluetooth
```

```bash
emerge sys-boot/grub:2
## there's a bug in `--removable` in new version grub2 while it's merge-usr distribution.
grub-install --target=x86_64-efi --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg
```

```bash
CCACHE_RECACHE=yes MAKEOPTS="-J3" emerge gnome vim
gpasswd -a galudisu plugdev
systemctl enable gdm

emerge autojump tmux
```

```bash
exit
cd
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -l /mnt/gentoo{/boot,/proc,}
reboot
```

## KVM

```bash
minikube start --driver=kvm2 --extra-config=kubelet.cgroup-driver=systemd --image-mirror-country='cn' --registry-mirror='https://guqcep47.mirror.aliyuncs.com' --image-repository='registry.cn-hangzhou.aliyuncs.com/google_containers' --kubernetes-version=v1.23.8
```

## App

https://wiki.gentoo.org/wiki/Recommended_applications

``bash
emerge foliate evince gnote libreoffice firefox evolution geary qbittorrent chromium imagemagick gimp flameshot inkscape shotwell mpv vlc smplayer nfs-utils vscode usbview gparted
``

## Repository
https://wiki.gentoo.org/wiki/Eselect/Repository

## Fonts
https://wiki.gentoo.org/wiki/Fontconfig#Picking_fonts
```bash
emerge liberation-fonts libertine noto dejavu droid sil-gentium ubuntu-font-family urw-fonts corefonts unifont wqy-zenhei wqy-microhei
```

## CPU Flag

```bash
emerge --ask resolve-march-native
```

## Flatpak

```bash
emerge --ask sys-apps/flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
## For chinese mirror
flatpak remote-modify flathub --url=https://mirror.sjtu.edu.cn/flathub
```

## Libinput

https://wiki.gentoo.org/wiki/Libinput

```bash
cp /usr/share/X11/xorg.conf.d/40-libinput.conf /etc/X11/xorg.conf.d/
```

Edit `vim etc/X11/xorg.conf.d/40-libinput.conf`

```bash
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

```bash
systemctl --global disable pulseaudio.service pulseaudio.socket
systemctl --global enable pipewire.service pipewire-pulse.socket
systemctl --global --force enable wireplumber.service
```


## GDM scaling

tl/dr

```bash
sudo nano /usr/share/glib-2.0/schemas/org.gnome.desktop.interface.gschema.xml
```

Change the default value to 2 (or your desired scale factor):

```xml
<key name="scaling-factor" type="u">
<default>2</default>
```

and then running:

```bash
sudo glib-compile-schemas /usr/share/glib-2.0/schemas
```

This fixed it for me. Let me know if it works for you as well.


## dev-*

```bash
sudo emerge --ask maven-bin gradle-bin sbt-bin
```
