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
    repo_file="$root/usr/lib/arlinux/guest/archlinuxcn.conf"
    awk -v repo="$repo_file" '
        BEGIN {
            while ((getline line < repo) > 0) block = block line ORS
            close(repo)
        }
        !added && $0 == "[core]" { printf "%s\n", block; added = 1 }
        { print }
        END { if (!added) printf "\n%s", block }
    ' "$root/etc/pacman.conf" > "$root/etc/pacman.conf.new"
    mv "$root/etc/pacman.conf.new" "$root/etc/pacman.conf"
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
set -- xterm curl ca-certificates ttf-dejavu noto-fonts-cjk fontconfig \
    xorg-xrdb xorg-xprop dbus at-spi2-core python-dbus python-atspi \
    python-gobject python-pip mpg123 wl-clipboard wtype xclip xdotool \
    wayland libx11 libxcb libxxf86vm gtk3 libnotify nss libxss libxtst \
    xdg-utils libsecret alsa-plugins libpulse cups libdrm mesa pango cairo
if [ -n "$cn_setup" ] || ! pacman -Q "$@" >/dev/null 2>&1; then
    echo 'ARLINUX:正在更新 Arch ARM 并安装桌面组件…'
    pacman -Syyu --needed --noconfirm "$@"
fi

# Match Debian's OpenCode automation and asynchronous online speech support.
# Dogtail is not packaged by Arch; keep both PyPI additions reproducible.
if ! python3 -c 'import dogtail, edge_tts' >/dev/null 2>&1; then
    echo 'ARLINUX:正在安装桌面自动化和在线语音进度播报组件…'
    python3 -m pip install --break-system-packages --no-cache-dir \
        'dogtail==1.0.5' 'edge-tts==7.2.8'
fi
guest=$root/usr/lib/arlinux/guest
python_source=$root/usr/lib/arlinux/python
mkdir -p "$python_source/arlinux"
cp "$guest/arlinux/"*.py "$python_source/arlinux/"
python_site=$(python3 -c 'import sys; print("python%d.%d/site-packages" % sys.version_info[:2])')
mkdir -p "$root/usr/lib/$python_site"
printf '/usr/lib/arlinux/python\n' > "$root/usr/lib/$python_site/arlinux.pth"

"$root/bin/sh" "$guest/opencode-install.sh"
"$root/bin/sh" "$guest/opencode-instructions.sh"

mkdir -p "$root/etc/pulse/client.conf.d" "$root/etc/alsa/conf.d"
printf 'default-server = unix:%s/runtime/pulse-native\nautospawn = no\nenable-shm = no\n' \
    "$BIONICX_FILES" > "$root/etc/pulse/client.conf.d/arlinux.conf"
cat > "$root/etc/alsa/conf.d/99-arlinux-pulse.conf" <<'ALSA'
pcm.!default { type pulse }
ctl.!default { type pulse }
ALSA
