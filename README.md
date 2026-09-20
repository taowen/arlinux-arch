# Arlinux Arch

Arlinux Arch is the Arch Linux ARM reference distribution for
[arlinux-rootfs](https://github.com/taowen/arlinux-rootfs). It boots into
OpenCode Desktop and demonstrates a rolling, pacman-managed AArch64 userspace
on the shared Arlinux runtime.

This repository contains only the Linux distribution recipe. It does not
contain or require the Android host source.

From an `arlinux-rootfs` checkout:

```bash
./build.sh build arch
./build.sh verify out/arch.arlinux-rootfs
```

The build produces `out/arch.arlinux-rootfs`. See the rootfs project's
[distribution authoring guide](https://github.com/taowen/arlinux-rootfs/blob/main/docs/DISTRIBUTION-AUTHORING.md)
for the interface implemented here.

## Repository layout

- `rootfs.lock.json` pins the Arch Linux ARM bootstrap archive.
- `tools/seed.sh` extracts and minimizes the upstream rootfs.
- `tools/post-seed.sh` initializes trusted package signing keys.
- `guest/first-boot.sh` finishes native package setup on the device.
- `profile.json` launches OpenCode on the host-provided display.
- `native/product-policy.h` scopes pacman compatibility.

Shared glibc, graphics, bundle, and Android integration code belongs to
`arlinux-rootfs` or the host, not this repository.

## License

GPL-3.0-or-later. Arch Linux ARM packages and downloaded applications retain
their respective licenses.
