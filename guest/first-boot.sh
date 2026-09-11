#!/bin/sh
set -eu
root=${BIONICX_ROOTFS:?missing BIONICX_ROOTFS}
export BIONICX_VIRTUAL_ROOT=1 BIONICX_REWRITE_ABSOLUTE_SYMLINKS=1
# The launcher supervises descendants; do not leave the bootstrap signing
# agent running after first boot has finished.
trap 'gpgconf --homedir "$root/etc/pacman.d/gnupg" --kill gpg-agent' EXIT
# libalpm canonicalizes these paths inside libc, so supply real app paths.
mkdir -p "$root/etc/pacman.d/gnupg" "$root/var/lib/pacman" "$root/var/cache/pacman/pkg" "$root/var/log"
cat > "$root/etc/pacman.d/arlinux.conf" <<EOF
RootDir = $root
DBPath = $root/var/lib/pacman
CacheDir = $root/var/cache/pacman/pkg
LogFile = $root/var/log/pacman.log
GPGDir = $root/etc/pacman.d/gnupg
HookDir = $root/etc/pacman.d/hooks
DisableSandboxFilesystem
EOF
if ! grep -q '^Include = /etc/pacman.d/arlinux.conf$' "$root/etc/pacman.conf"; then
    sed -i '/^\[options\]/a Include = /etc/pacman.d/arlinux.conf' "$root/etc/pacman.conf"
fi
# Android already assigns this APK its UID; it cannot switch to the ALPM user.
# The tested Android kernel does not implement Landlock.
sed -i '/^DownloadUser[[:space:]]*=/d' "$root/etc/pacman.conf"
# Preserve the platform cache generator when glibc is upgraded by pacman.
if ! grep -q '^NoExtract = usr/bin/ldconfig$' "$root/etc/pacman.conf"; then
    sed -i '/^\[options\]/a NoExtract = usr/bin/ldconfig' "$root/etc/pacman.conf"
fi
cp "$root/usr/lib/arlinux-platform/ldconfig" "$root/usr/bin/ldconfig"
chmod 755 "$root/usr/bin/ldconfig"
mkdir -p "$root/etc/ld.so.conf.d"
printf '/usr/lib/arlinux-platform\n/usr/lib\n' > "$root/etc/ld.so.conf.d/arlinux.conf"
ldconfig
# Android supplies identity and service management. Keep package scriptlets
# and desktop-cache hooks, but omit Linux boot/service-account operations.
mkdir -p "$root/etc/pacman.d/hooks"
for hook in 20-systemd-sysusers.hook 21-systemd-tmpfiles.hook \
            10-openssh-mark-sshd-for-restart.hook; do
    ln -sfn /dev/null "$root/etc/pacman.d/hooks/$hook"
done
# This userspace runs on Android's kernel; keep the package database accurate.
for pkg in linux-aarch64 linux-firmware; do
    if pacman -Q "$pkg" >/dev/null 2>&1; then
        pacman -Rns --noconfirm "$pkg"
    fi
done
if [ ! -f "$root/etc/pacman.d/gnupg/arlinux-populated" ]; then
    echo 'ARLINUX:正在初始化 Arch ARM 签名密钥…'
    pacman-key --init
    pacman-key --populate archlinuxarm
    touch "$root/etc/pacman.d/gnupg/arlinux-populated"
fi
# Refresh the product's default repository on APK upgrades too. Preserve a
# repository already configured by the user, including their chosen mirror.
if ! grep -q '^\[archlinuxcn\]$' "$root/etc/pacman.conf"; then
    printf '\n' >> "$root/etc/pacman.conf"
    cat "$root/usr/lib/arlinux/guest/archlinuxcn.conf" >> "$root/etc/pacman.conf"
fi
cn_setup=
if ! pacman -Q archlinuxcn-keyring >/dev/null 2>&1; then
    echo 'ARLINUX:正在初始化 Arch Linux 中文社区软件源…'
    # The CN keyring is signed by an Arch packager. Trust it through the
    # packaged Arch keyring, then install CN's keyring with signatures enabled.
    pacman-key --populate archlinux
    pacman -Sy --needed --noconfirm archlinuxcn-keyring
    cn_setup=1
fi
set -- xterm ttf-dejavu noto-fonts-cjk fontconfig xorg-xrdb dbus \
    at-spi2-core wayland libx11 libxcb libxxf86vm
if [ -n "$cn_setup" ] || ! pacman -Q "$@" >/dev/null 2>&1; then
    echo 'ARLINUX:正在更新 Arch ARM 并安装桌面组件…'
    pacman -Syyu --needed --noconfirm "$@"
fi
