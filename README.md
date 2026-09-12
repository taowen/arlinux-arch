# arlinux-arch

An independent Android Linux desktop application built from Arlinux's shared
Android library, process runtime and graphics stack.

Application ID: `io.taowen.arlinux.arch`. This APK has its own
Android UID, private rootfs, package database and home directory. It does not
replace the older `io.taowen.arlinux` application.

## Build

```sh
git submodule update --init --recursive
export JAVA_HOME=/path/to/jdk21
export ANDROID_HOME=/path/to/android-sdk
export HYBRIS_LIB_DIR=/path/to/libhybris/install/usr/lib/hybris
# Build the shared native graphics components once:
third_party/arlinux/tools/build.sh ndk
third_party/arlinux/tools/build.sh mesa
./build.sh
```

The output is `build/arlinux-arch-debug.apk`. `--prepare-only` builds userspace
assets; `--apk-only` assembles existing assets. For development, set
`ARLINUX_DIR=/path/to/arlinux` to use a separate working checkout.
Host requirements and the application input contract are described in
[Arlinux](https://github.com/taowen/arlinux).

`product.json` selects package identity, glibc recipe and library/module paths.
`tools/seed.sh` produces the distribution rootfs. `guest/first-boot.sh` owns
package-manager configuration and desktop initialization. `native/product-policy.h`
is compiled into this product's copy of the common runtime; it is not loaded
as a runtime plugin. Android Activity, input, JNI, sessions, GPU selection,
asset installation and build orchestration are shared without copied Java.

The shared checkout is pinned as a Git submodule. Do not commit generated
rootfs archives, APKs or package caches into this source repository.

## Runtime policy

The seed archive URL and SHA-256 are in `rootfs.lock.json`; a changed upstream
archive fails the build until the lock is deliberately updated. The product
uses the shared glibc 2.43 recipe. Arch rolling upgrades can introduce a newer
glibc ABI, so a future upgrade may require a new shared recipe and APK.

First boot initializes and populates the Arch Linux ARM signing keyring, then
runs `pacman -Syu` and installs desktop components. Package signatures stay
enabled. The default mirrors are owned by this repository in `guest/mirrorlist`
and `guest/archlinuxcn.conf`. Both use Tsinghua TUNA.
Linux kernel and firmware packages are removed through pacman because the APK
uses Android's kernel. It does not boot systemd. The systemd-sysusers, systemd-tmpfiles and OpenSSH service-restart marking
hooks are masked: service-account creation and Linux boot management are
outside this single-Android-UID desktop. The shared installer creates runtime
directories. Package scriptlets and desktop-cache hooks remain enabled;
packages that require Linux service accounts or systemd are not covered.

Downloads use the application UID; this environment cannot switch to an ALPM
service user. `DisableSandboxFilesystem` is required on the tested kernel,
which lacks Landlock. These settings belong to this product's first-boot script.
The application remains confined by Android's UID and SELinux policy.

## Checks

After installing and starting the APK on a device:

```sh
ARLINUX_DIR=third_party/arlinux tests/test-pacman-device.py --serial DEVICE
third_party/arlinux/tests/test-product-device.py --product . --serial DEVICE
third_party/arlinux/tests/test-teapot-device.py --serial DEVICE \
  --package io.taowen.arlinux.arch --gpu turnip
```

The pacman test creates two versions of a disposable package and checks native
install, upgrade, scriptlets, virtual UID and removal. Graphical screenshot
checks need unobscured windows; hide the extra-key bar with a three-finger
swipe down, or start the debug Activity with
`--ez io.taowen.arlinux.extra.HIDE_EXTRA_KEYS true`.

Validated on 2026-09-10 using a Redmi K40 (Android 13, Adreno 650): fresh
signed package bootstrap to xterm, APK update preserving home and package
records, pacman install/upgrade/scriptlets/removal, runtime identity and nested
exec, and Turnip hardware GLX plus Wayland EGL presentation and resize. The
fresh transaction completed without package errors under the policy above.
These checks do not certify every application or future rolling update.

## Arch Linux Chinese Community repository

The APK enables `archlinuxcn` by default, including when upgrading an existing
installation. First boot imports trust from the packaged Arch keyring and
installs `archlinuxcn-keyring` with package signature checks enabled. It preserves
an existing `[archlinuxcn]` stanza and its mirror selection. The repository is
appended after the standard Arch Linux ARM repositories.

This repository supplies native aarch64 packages absent from the standard ARM
repositories, including Blender. The APK does not bundle Blender.

X300 has been tested with the original signed packages `blender 17:5.2.1-1`
and `usd 26.05-4`. USD 26.08 is incompatible with that Blender build and causes
an undefined-symbol error. On the tested device, `IgnorePkg = blender usd`
keeps this pair together; remove that hold only when updating to a compatible
pair. This hold is not part of the APK's default package configuration.

Run the original application with `blender --gpu-backend vulkan`. The shared
libhybris fork compensates for the tested G1-Ultra driver's missing vertex
storage behavior. Startup, a 17-mesh model, fullscreen/restore, save/reopen and
Workbench rendering passed. Eevee still produces an almost-black image and
is not considered working. Blender's executable and packaged resources are
unchanged. See the core's `tests/blender/README.md` and libhybris's
`tests/baseline/vertex-stores.md` for scope and reproduction.

The tested package also needed `python-cattrs` for its asset-library module.
These results concern this specific package/driver pair, not arbitrary future
rolling updates.

Repository setup follows the [TUNA documentation](https://mirrors.tuna.tsinghua.edu.cn/help/archlinuxcn/).
