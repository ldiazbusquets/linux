#!/usr/bin/env bash
# Builds Arch Linux 32 (i686) as a v86 9p filesystem: OUT/fs.json + OUT/flat/*.bin.zst
# Runs on GitHub Actions (needs internet, Docker and sudo). Usage: build/build-arch.sh OUT
set -euo pipefail
OUT="$(realpath -m "${1:?output dir}")"
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"; cd "$WORK"

MIRRORS=(https://mirror.archlinux32.org https://de.mirror.archlinux32.org https://mirror.datacenter.by/pub/archlinux32 https://mirror.yandex.ru/archlinux32)
URL=""; MIRROR=""
for m in "${MIRRORS[@]}"; do
  echo "== trying $m"
  list=$(curl -fsSL --max-time 40 "$m/archisos/" 2>/dev/null) || { echo "   unreachable"; continue; }
  f=$(grep -oE 'archlinux32-bootstrap-[0-9.]+-i686\.tar\.(gz|zst)' <<<"$list" | sort -uV | tail -1 || true)
  if [ -n "$f" ]; then URL="$m/archisos/$f"; MIRROR="$m"; break; fi
  echo "   no bootstrap tarball listed; first lines:"; head -c 1500 <<<"$list"; echo
done
[ -n "$URL" ] || { echo "No Arch Linux 32 bootstrap tarball found"; exit 1; }
echo "== bootstrap: $URL"

curl -fL --retry 3 -o bootstrap.tar "$URL"
mkdir boot && sudo tar -xpf bootstrap.tar -C boot --numeric-owner
R=$(ls -d boot/root.* | head -1)
sudo tar -C "$R" -c . | docker import --platform linux/386 - arch32-bootstrap

docker build --platform linux/386 --progress=plain --build-arg MIRROR="$MIRROR" -t arch32-v86 "$HERE/arch"
docker rm -f arch32 >/dev/null 2>&1 || true
docker create --platform linux/386 --name arch32 arch32-v86 /bin/true >/dev/null
mkdir fs && docker export arch32 | sudo tar -xpf - -C fs --numeric-owner
docker rm -f arch32 >/dev/null

# files Docker leaves empty in an exported container
echo arch | sudo tee fs/etc/hostname >/dev/null
printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 arch\n' | sudo tee fs/etc/hosts >/dev/null
sudo rm -f fs/etc/resolv.conf fs/.dockerenv
echo 'nameserver 192.168.86.1' | sudo tee fs/etc/resolv.conf >/dev/null
ls -la fs/boot
sudo du -sh fs

git clone -q --depth 1 https://github.com/copy/v86 v86src
TMP="$OUT.tmp"; rm -rf "$TMP"; mkdir -p "$TMP/flat"
sudo python3 v86src/tools/fs2json.py --zstd --out "$TMP/fs.json" fs
sudo python3 v86src/tools/copy-to-sha256.py --zstd fs "$TMP/flat"
sudo chown -R "$(id -u):$(id -g)" "$TMP"
echo "{\"built\":\"$(date -u +%Y-%m-%d)\",\"bootstrap\":\"$(basename "$URL")\"}" > "$TMP/build.json"
du -sh "$TMP"; ls "$TMP/flat" | wc -l
rm -rf "$OUT"; mv "$TMP" "$OUT"
