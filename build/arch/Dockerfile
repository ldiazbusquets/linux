# Arch Linux 32 (i686) for the v86 browser emulator.
# Built on GitHub Actions by build/build-arch.sh: the base image "arch32-bootstrap"
# is the official Arch Linux 32 bootstrap tarball imported into Docker.
FROM arch32-bootstrap
ARG MIRROR
SHELL ["/bin/bash", "-c"]

# pacman: our mirror, i686, and settings that work inside a container
RUN printf 'Server = %s/$arch/$repo\n' "$MIRROR" > /etc/pacman.d/mirrorlist && \
    sed -i -E 's/^#?Architecture.*/Architecture = i686/; s/^CheckSpace/#CheckSpace/; s/^#?ParallelDownloads.*/ParallelDownloads = 8/; s/^#Color/Color/' /etc/pacman.conf && \
    if pacman --version | grep -q 'v7\.'; then sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf; fi && \
    pacman-key --init && (pacman-key --populate archlinux32 || pacman-key --populate) && \
    (pacman -Sy --noconfirm archlinux32-keyring || true)

# base system first, then our boot hook, then the kernel (which builds the initramfs)
RUN pacman -Syu --noconfirm --needed base mkinitcpio || \
    { echo 'signature check failed, retrying without it'; sed -i -E 's/^SigLevel.*/SigLevel = Never/' /etc/pacman.conf; pacman -Syu --noconfirm --needed base mkinitcpio; }

COPY 9p_root.hook /etc/initcpio/hooks/9p_root
COPY 9p_root.install /etc/initcpio/install/9p_root
RUN sed -i -E 's/^MODULES=.*/MODULES=(virtio_pci virtio_net 9p 9pnet 9pnet_virtio)/; s/^HOOKS=.*/HOOKS=(base udev modconf keyboard 9p_root)/' /etc/mkinitcpio.conf && \
    pacman -S --noconfirm --needed linux && \
    printf "PRESETS=('default')\nALL_kver='/boot/vmlinuz-linux'\ndefault_image='/boot/initramfs-linux.img'\n" > /etc/mkinitcpio.d/linux.preset && \
    rm -f /boot/initramfs-linux-fallback.img && mkinitcpio -P && ls -la /boot

# everyday tools; the optional ones are installed one by one so a missing package cannot fail the build
RUN pacman -S --noconfirm --needed sudo nano vim less man-db man-pages bash-completion htop python git tree wget curl which inetutils dhcpcd iproute2 && \
    for p in fastfetch tmux gcc make python-pip unzip zip jq nmap; do pacman -S --noconfirm --needed "$p" || echo "skipped $p"; done

COPY rootfs/ /
RUN chmod 0440 /etc/sudoers.d/wheel && chmod +x /usr/local/bin/* && \
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen && locale-gen && \
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime && \
    useradd -m -G wheel -s /bin/bash arch && echo 'arch:arch' | chpasswd && echo 'root:root' | chpasswd && \
    cp /etc/skel/.bashrc.ldb /home/arch/.bashrc && cp /etc/skel/.bashrc.ldb /root/.bashrc && chown arch:arch /home/arch/.bashrc && \
    systemd-machine-id-setup && \
    systemctl mask systemd-firstboot.service ldconfig.service man-db.timer man-db.service shadow.timer systemd-tmpfiles-clean.timer archlinux-keyring-wkd-sync.timer systemd-timesyncd.service systemd-networkd-wait-online.service 2>/dev/null; \
    true

# make it smaller: drivers a virtual PC never needs, other languages, package cache
RUN K=$(ls /usr/lib/modules | head -1); M=/usr/lib/modules/$K/kernel; \
    rm -rf $M/drivers/{gpu,media,infiniband,staging,scsi,bluetooth,iio,isdn,mtd,usb,hwmon,thunderbolt,net/wireless,net/can,net/usb,input/joystick,input/touchscreen,input/tablet,video/fbdev,firewire,nfc,platform,power/supply,misc,hid} $M/sound $M/net/{bluetooth,wireless,mac80211} 2>/dev/null; \
    depmod -a "$K"; \
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'locale.alias' -exec rm -rf {} +; \
    rm -rf /usr/share/doc/* /usr/share/gtk-doc /var/cache/pacman/pkg/* 2>/dev/null; \
    du -sh / --exclude=/proc --exclude=/sys 2>/dev/null | tail -1
