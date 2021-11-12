# Gentoo AMD Ryzen 7

Also make a reference of https://wiki.gentoo.org/wiki/Lenovo_Ideapad_Slim_7


## firmware 

```bash
amd-ucode/microcode_amd_fam17h.bin amd/amd_sev_fam17h_model3xh.sbin amdgpu/green_sardine_asd.bin amdgpu/green_sardine_me.bin amdgpu/green_sardine_pfp.bin amdgpu/green_sardine_ta.bin amdgpu/green_sardine_ce.bin amdgpu/green_sardine_mec2.bin amdgpu/green_sardine_rlc.bin amdgpu/green_sardine_vcn.bin amdgpu/green_sardine_dmcub.bin amdgpu/green_sardine_mec.bin amdgpu/green_sardine_sdma.bin
```


```bash
parted /dev/nvme0n

(parted) mklabe gpt
(parted) unit mib                                                         
(parted) mkpart ESP fat32 1 513
(parted) set 1 bios_grub on                                               
(parted) name 1 grub                                                      
(parted) mkpart primary 513 800                                           
(parted) name 2 boot                                                      
(parted) set 2 boot on                                                    
(parted) mkpart primary 800 100%                                          
(parted) name 3 root                                                      
(parted) println                                                          


...
```

```bash
mkfs.ext2 /dev/nvme0n1p2
mkfs.ext4 -L root /dev/nvme0n1p3
```

```bash
mount /dev/nvme0n1p3 /mnt/gentoo
mkdir -p /mnt/gentoo/boot
mount /dev/nvme0n1p2 /mnt/gentoo/boot
mkdir -p /mnt/gentoo/boot/efi
mount /dev/nvme0n1p1 /mnt/gentoo/boot/efi
lsblk
```

```bash
cd /mnt/gentoo
links http://www.gentoo.org/main/en/mirrors.xml

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


emerge -avuDN @world

emerge --ask ufed

```bash
echo "Asia/Shanghai" > /etc/timezone
emerge --config sys-libs/timezone-data
nano -w /etc/locale.gen
```

en_US ISO-8859-1
en_US.UTF8 UTF-8
zh_CN GB2312
zh_CN.UTF8 UTF-8
C.UTF8 UTF-8

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
/dev/nvme0n1p1	        /boot/efi	vfat	        noauto,noatime                                  1 2
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
grub-install --target=x86_64-efi --efi-directory=/boot/efi --removable
grub-mkconfig -o /boot/grub/grub.cfg
mkdir -p /boot/efi/EFI/arch
grub-mkconfig -o /boot/efi/EFI/arch/grub.cfg
```

```bash
exit
cd
umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -l /mnt/gentoo{/boot,/proc,}
reboot
```
