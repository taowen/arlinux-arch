# Arlinux Arch

Arlinux Arch is the Arch Linux ARM reference distribution for
[arlinux-rootfs](https://github.com/taowen/arlinux-rootfs). It boots into
a desktop session and demonstrates a rolling, pacman-managed AArch64 userspace
on the shared Arlinux runtime.
OpenCode is available from Apps and the AI voice entry. Its first launch
downloads and installs the pinned official package; later launches reuse it.

This repository contains only the Linux distribution recipe. It does not
contain or require the Android host source.

From an `arlinux-rootfs` checkout:

```bash
./build.sh prepare arch
# Install build/offline/arch/prepare.zip in a disposable build-only instance,
# then export its prepared rootfs (never a personal home or application state).
./build.sh offline arch /path/to/build-only-rootfs.tar
./build.sh verify out/arch.zip
```

The build produces `out/arch.zip`. See the rootfs project's
[distribution authoring guide](https://github.com/taowen/arlinux-rootfs/blob/main/docs/DISTRIBUTION-AUTHORING.md)
for the interface implemented here.

## Repository layout

- `rootfs.lock.json` pins the Arch Linux ARM bootstrap archive.
- `tools/seed.sh` extracts and minimizes the upstream rootfs.
- `tools/post-seed.sh` initializes trusted package signing keys.
- `guest/build-desktop.sh` prepares packages in a disposable build instance.
- `guest/first-boot.sh` applies device-local configuration without network access.
- `profile.json` launches OpenCode on the host-provided display.

Shared glibc, graphics, bundle, and Android integration code belongs to
`arlinux-rootfs` or the host, not this repository.

## License

GPL-3.0-or-later. Arch Linux ARM packages and downloaded applications retain
their respective licenses.
