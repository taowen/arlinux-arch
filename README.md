# Arlinux Arch

Arch Linux ARM rootfs recipe for
[arlinux-rootfs](https://github.com/taowen/arlinux-rootfs). It produces an
AArch64 distribution bundle and contains no Android host build.

From an `arlinux-rootfs` checkout:

```bash
./build.sh build arch
./build.sh verify out/arch.arlinux-rootfs
```

`rootfs.lock.json` pins bootstrap inputs. `tools/seed.sh` creates the root
filesystem, `guest/` contains guest setup and launch files, and
`native/product-policy.h` contains the distribution-specific compatibility
policy. Shared glibc, GPU and bundle logic belongs to `arlinux-rootfs`.
