#!/usr/bin/env bash
set -euo pipefail
product="$(cd "$(dirname "$0")/.." && pwd)"
out="${1:?rootfs output required}"
mkdir -p "$product/build/cache" "$out"
python3 - "$product" <<'PY'
import hashlib, json, pathlib, subprocess, sys
p = pathlib.Path(sys.argv[1]); lock = json.loads((p / 'rootfs.lock.json').read_text())
archive = p / 'build/cache/rootfs.tar.gz'
if not archive.is_file():
    subprocess.run(['curl', '-fL', '--retry', '2', lock['url'], '-o', str(archive)], check=True)
with archive.open('rb') as source:
    actual = hashlib.file_digest(source, 'sha256').hexdigest()
if actual != lock['sha256']:
    raise SystemExit('Rootfs hash changed; review and update rootfs.lock.json before building')
PY
tar --delay-directory-restore --no-same-owner --exclude=./dev --exclude=./proc --exclude=./sys \
    --exclude=./boot --exclude=./usr/lib/modules -xzf "$product/build/cache/rootfs.tar.gz" -C "$out"
cp "$product/guest/mirrorlist" "$out/etc/pacman.d/mirrorlist"
