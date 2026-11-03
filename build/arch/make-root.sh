#!/usr/bin/env bash
# Runs inside a privileged x86_64 archlinux container. Installs Arch Linux 32 (i686)
# into /out/root with pacstrap, configured to boot from v86's 9p filesystem.
set -euo pipefail
B=/build; R=/out/root
pacman -Sy --noconfirm --needed arch-install-scripts curl >/dev/null

MIRRORS=(https://mirror.yandex.ru/archlinux32 https://mirror.datacenter.by/pub/archlinux32 https://mirror.archlinux32.org https://de.mirror.archlinux32.org)
OK=()
for m in "${MIRRORS[@]}"; do curl -fsI --max-time 20 "$m/i686/core/core.db" >/dev/null && OK+=("$m") && echo "mirror ok: $m" || echo "mirror down: $m"; done
[ ${#OK[@]} -gt 0 ] || { echo "no Arch Linux 32 mirror reachable"; exit 1; }
REPOS=(core extra)
curl -fsI --max-time 20 "${OK[0]}/i686/community/community.db" >/dev/null && REPOS+=(community)
echo "repos: ${REPOS[*]}"

mkdir -p "$R/etc/pacman.d"
: > /tmp/mirrorlist32
for m in "${OK[@]}"; do echo "Server = $m/\$arch/\$repo" >> /tmp/mirrorlist32; done
conf() { # $1 = SigLevel, $2 = mirrorlist path
  printf '[options]\nArchitecture = i686\nHoldPkg = pacman glibc\nCheckSpace\nColor\nILoveCandy\nParallelDownloads = 6\nSigLevel = %s\nLocalFileSigLevel = Optional\n' "$1"
  for r in "${REPOS[@]}"; do printf '\n[%s]\nInclude = %s\n' "$r" "$2"; done
}
conf Never /tmp/mirrorlist32 > /tmp/pacman32.conf
sed -i 's/^CheckSpace/#CheckSpace/' /tmp/pacman32.conf

# Our boot hook, initramfs config and preset go in first so the kernel install uses them.
install -Dm644 "$B/9p_root.hook" "$R/etc/initcpio/hooks/9p_root"
install -Dm644 "$B/9p_root.install" "$R/etc/initcpio/install/9p_root"
mkdir -p "$R/etc/mkinitcpio.d"
printf 'MODULES=(virtio_pci virtio_net 9p 9pnet 9pnet_virtio)\nBINARIES=()\nFILES=()\nHOOKS=(base udev modconf keyboard 9p_root)\nCOMPRESSION="zstd"\n' > "$R/etc/mkinitcpio.conf"
printf "PRESETS=('default')\nALL_kver='/boot/vmlinuz-linux'\ndefault_image='/boot/initramfs-linux.img'\n" > "$R/etc/mkinitcpio.d/linux.preset"

pacstrap -C /tmp/pacman32.conf -M -G "$R" base linux mkinitcpio sudo nano vim less man-db man-pages bash-completion htop python git tree wget curl which inetutils dhcpcd iproute2 archlinux32-keyring
cp /tmp/pacman32.conf "$R/etc/pacman.conf"; cp /tmp/mirrorlist32 "$R/etc/pacman.d/mirrorlist"
sed -i 's#Include = /tmp/mirrorlist32#Include = /etc/pacman.d/mirrorlist#' "$R/etc/pacman.conf"
for p in fastfetch neofetch tmux gcc make python-pip unzip zip jq nmap cowsay figlet; do arch-chroot "$R" pacman -S --noconfirm --needed "$p" >/dev/null 2>&1 && echo "added $p" || echo "skipped $p"; done

# overlay files and system setup
cp -a "$B/rootfs/." "$R/"
arch-chroot "$R" bash -euxc '
  chmod 0440 /etc/sudoers.d/wheel; chmod +x /usr/local/bin/*
  echo "en_US.UTF-8 UTF-8" > /etc/locale.gen; locale-gen
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  useradd -m -G wheel -s /bin/bash arch; echo arch:arch | chpasswd; echo root:root | chpasswd
  cp /etc/skel/.bashrc.ldb /home/arch/.bashrc; cp /etc/skel/.bashrc.ldb /root/.bashrc; chown arch:arch /home/arch/.bashrc
  systemd-machine-id-setup
  for u in systemd-firstboot.service ldconfig.service man-db.timer man-db.service shadow.timer systemd-tmpfiles-clean.timer archlinux-keyring-wkd-sync.timer systemd-timesyncd.service systemd-networkd-wait-online.service systemd-homed.service systemd-userdbd.socket; do systemctl mask "$u" >/dev/null 2>&1 || true; done
  rm -f /boot/initramfs-linux-fallback.img
  mkinitcpio -P
  ls -la /boot
'

# Package signatures: use them if the keyring works, otherwise fall back so pacman is usable.
SIG="Required DatabaseOptional"
if arch-chroot "$R" bash -c 'pacman-key --init >/dev/null 2>&1 && pacman-key --populate archlinux32 >/dev/null 2>&1'; then
  conf "$SIG" /etc/pacman.d/mirrorlist > "$R/etc/pacman.conf"
  if arch-chroot "$R" bash -c 'pacman -Sy --noconfirm >/dev/null && pacman -S --noconfirm --needed sl >/dev/null && pacman -Rns --noconfirm sl >/dev/null'; then
    echo "signatures: verified install works"
  else SIG=Never; fi
else SIG=Never; fi
if [ "$SIG" = Never ]; then echo "::warning::Arch Linux 32 keyring check failed, pacman signature checking is off"; conf Never /etc/pacman.d/mirrorlist > "$R/etc/pacman.conf"; fi
arch-chroot "$R" pacman -Sy --noconfirm >/dev/null || true   # fresh package lists for offline pacman -Ss

# smaller: drivers a virtual PC never needs, other languages, caches
K=$(ls "$R/usr/lib/modules" | head -1); M="$R/usr/lib/modules/$K/kernel"
rm -rf "$M"/drivers/{gpu,media,infiniband,staging,scsi,bluetooth,iio,isdn,mtd,usb,hwmon,thunderbolt,firewire,nfc,hid} "$M"/drivers/net/{wireless,can,usb} "$M"/drivers/input/{joystick,touchscreen,tablet} "$M"/sound "$M"/net/{bluetooth,wireless,mac80211} 2>/dev/null || true
arch-chroot "$R" depmod -a "$K"
find "$R/usr/share/locale" -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} +
rm -rf "$R"/usr/share/doc/* "$R/usr/share/gtk-doc" "$R"/var/cache/pacman/pkg/* "$R"/var/log/*.log
echo "root size: $(du -sh "$R" | cut -f1)"
