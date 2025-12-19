#!/usr/bin/env bash
set -euo pipefail

wget https://deb.debian.org/debian/dists/trixie/main/installer-arm64/current/images/netboot/debian-installer/arm64/linux
wget https://deb.debian.org/debian/dists/trixie/main/installer-arm64/current/images/netboot/debian-installer/arm64/initrd.gz

INITRD_UNPACK="initrd-unpack"
mkdir -p "${INITRD_UNPACK}"
(
    cd "${INITRD_UNPACK}"
    gzip -dc "../initrd.gz" | cpio -id --quiet
    cp "../preseed.cfg" "./preseed.cfg"
    rm "../initrd.gz"
    find . | cpio -H newc -o --quiet | gzip -c > "../initrd.gz"
)

echo "Initrd repacked successfully"
