#!/usr/bin/env bash
set -euo pipefail
product="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:?rootfs output required}"
cache="${ARLINUX_DOWNLOAD_CACHE:-/var/cache/arlinux/downloads}"
mkdir -p "$cache" "$out"
python3 - "$product" "$cache" <<'PY'
import hashlib, json, pathlib, subprocess, sys
p, cache = map(pathlib.Path, sys.argv[1:]); lock = json.loads((p / 'rootfs.lock.json').read_text())
archive = cache / ('rootfs-' + lock['sha256'] + '.tar.gz')
if not archive.is_file():
    partial = archive.with_suffix('.part')
    subprocess.run(['curl', '-fL', '--retry', '2', lock['url'], '-o', str(partial)], check=True)
    partial.replace(archive)
with archive.open('rb') as source:
    actual = hashlib.file_digest(source, 'sha256').hexdigest()
if actual != lock['sha256']:
    raise SystemExit('Rootfs hash changed; review and update rootfs.lock.json before building')
PY
archive="$(python3 -c 'import json,sys; x=json.load(open(sys.argv[1])); print(sys.argv[2]+"/rootfs-"+x["sha256"]+".tar.gz")' "$product/rootfs.lock.json" "$cache")"
tar --delay-directory-restore --no-same-owner --exclude=./dev --exclude=./proc --exclude=./sys \
    --exclude=./boot --exclude=./usr/lib/modules -xzf "$archive" -C "$out"
cp "$product/guest/mirrorlist" "$out/etc/pacman.d/mirrorlist"

# Android supplies the kernel. Remove the large bare-metal firmware payload and
# its package records while producing the seed, before any package scriptlets
# or systemd/mkinitcpio hooks can run on the phone.
python3 - "$out" <<'PY'
import pathlib, shutil, sys
root = pathlib.Path(sys.argv[1])
shutil.rmtree(root / 'usr/lib/firmware', ignore_errors=True)
local = root / 'var/lib/pacman/local'
for package in local.iterdir():
    desc = package / 'desc'
    if not desc.is_file():
        continue
    lines = desc.read_text(errors='replace').splitlines()
    try:
        name = lines[lines.index('%NAME%') + 1]
    except (ValueError, IndexError):
        continue
    if name == 'linux-aarch64' or name == 'linux-firmware' or name.startswith('linux-firmware-'):
        shutil.rmtree(package)
PY
