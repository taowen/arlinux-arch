#!/bin/sh
# Build-only package preparation in a disposable instance. Never a consumer entry point.
set -eu
root=/
# Pacman's agent must not keep Android's installer output pipes open.
trap 'gpgconf --homedir "$root/etc/pacman.d/gnupg" --kill all >/dev/null 2>&1 || true' EXIT
if [ ! -s "$root/etc/machine-id" ]; then
    chmod u+w "$root/etc/machine-id"
    tr -d '-' < /proc/sys/kernel/random/uuid > "$root/etc/machine-id"
    chmod 444 "$root/etc/machine-id"
fi
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
mkdir -p "$root/etc/ld.so.conf.d"
ldconfig
# Android supplies identity and service management. Keep package scriptlets
# and desktop-cache hooks, but omit Linux boot/service-account operations.
mkdir -p "$root/etc/pacman.d/hooks"
for hook in 20-systemd-sysusers.hook 21-systemd-tmpfiles.hook \
            10-openssh-mark-sshd-for-restart.hook \
            60-mkinitcpio-remove.hook 90-mkinitcpio-install.hook; do
    ln -sfn /dev/null "$root/etc/pacman.d/hooks/$hook"
done
[ -f "$root/etc/pacman.d/gnupg/arlinux-populated" ] || {
    echo 'Bundle is missing its prebuilt pacman trust database' >&2; exit 1;
}
runtime_epoch=$root/var/lib/arlinux/runtime-epoch-1
if [ ! -f "$runtime_epoch" ]; then
    echo 'ARLINUX:Updating the base runtime...'
    pacman -Syy --needed --noconfirm glibc coreutils bash pacman
    mkdir -p "$(dirname "$runtime_epoch")"
    : > "$runtime_epoch"
    exit 75
fi
/bin/sh /usr/lib/arlinux/install-mesa-arch.sh
set -- foot xterm curl ca-certificates ttf-dejavu noto-fonts-cjk fontconfig \
    xorg-xrdb xorg-xprop dbus at-spi2-core ibus python-dbus python-atspi \
    python-gobject python-pip mpg123 wl-clipboard wtype xclip xdotool \
    wayland libx11 libxcb libxxf86vm gtk3 libnotify nss libxss libxtst \
    xdg-utils libsecret alsa-plugins libpulse cups libdrm pango cairo
if ! pacman -Q "$@" >/dev/null 2>&1; then
    echo 'ARLINUX:Updating Arch Linux ARM and installing desktop components...'
    pacman -Syyu --needed --noconfirm "$@"
fi

# Match Debian's OpenCode automation and asynchronous online speech support.
# Dogtail is not packaged by Arch; keep both PyPI additions reproducible.
if ! python3 -c 'import dogtail, edge_tts' >/dev/null 2>&1; then
    echo 'ARLINUX:Installing desktop automation and online speech support...'
    python3 -m pip install --break-system-packages --no-cache-dir \
        'dogtail==1.0.5' 'edge-tts==7.2.8'
fi
# Guest Tools owns OpenCode and the arlinux Python package. The instance's
# first boot supplies its Android PulseAudio socket, which is unknown here.
mkdir -p "$root/etc/alsa/conf.d"
cat > "$root/etc/alsa/conf.d/99-arlinux-pulse.conf" <<'ALSA'
pcm.!default { type pulse }
ctl.!default { type pulse }
ALSA

python3 -c 'import dogtail, edge_tts, pyatspi'
mkdir -p /usr/share/arlinux
pacman -Q | awk '{print $1 "\t" $2}' > /usr/share/arlinux/packages.tsv
printf '%s\n' 'arch' > /usr/share/arlinux/offline-distribution
printf '1\n' > /usr/share/arlinux/offline-desktop
