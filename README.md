# Gentoo AMD Ryzen 7

Also make a reference of https://wiki.gentoo.org/wiki/Lenovo_Ideapad_Slim_7


## Prepare

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
(parted) mkpart primary 1537 165377
(parted) name 3 home
(parted) mkpart primary 165377 247297
(parted) name 4 opt                                                     
(parted) mkpart primary 247297 100%                                          
(parted) name 5 root                                                      
(parted) print                                                          


...
```

```bash
mkfs.vfat /dev/nvme0n1p2
mkfs.ext4 -L root /dev/nvme0n1p5
mkfs.ext4 -L home /dev/nvme0n1p3
mkfs.ext4 -L opt /dev/nvme0n1p4
```

```bash
mount /dev/nvme0n1p5 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount /dev/nvme0n1p2 /mnt/gentoo/boot
mkdir -p /mnt/gentoo/home
mount /dev/nvme0n1p3 /mnt/gentoo/home
mkdir -p /mnt/gentoo/opt
mount /dev/nvme0n1p4 /mnt/gentoo/opt
lsblk
```

```bash
cd /mnt/gentoo
links https://www.gentoo.org/main/en/mirrors.xml

tar xvf stage3-*.tar.xz --xattrs
```

```bash
GENTOO_MIRRORS="https://mirrors.aliyun.com/gentoo/"
sync-uri = rsync://mirrors.tuna.tsinghua.edu.cn/gentoo-portage
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
eselect profile set 7
```

```bash
emerge -avuDN @world
emerge --ask ufed
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
emerge --ask sys-kernel/gentoo-sources sys-apps/pciutils sys-kernel/genkernel

nano -w /etc/genkernel.conf
```

```bash
genfstab -U -p /  >> /etc/fstab
```

```bash
/dev/nvme0n1p2	        /boot/efi	vfat	        noauto,noatime                                  0 1
/dev/nvme0n1p3          /	        ext4	        discard,noatime,commit=600,errors=remount-ro	0 1
```

```bash
genkernel all
```

```bash
emerge cronie
emerge mlocate
emerge dhcpcd
systemctl enable cronie
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
```

```bash
emerge sys-boot/grub:2
grub-install --target=x86_64-efi --efi-directory=/boot --removable
grub-mkconfig -o /boot/grub/grub.cfg
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