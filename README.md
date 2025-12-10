# qnap-ts-433-bootloader-builder

## Prior work and acknowledgements

This repository is a small helper on top of excellent upstream work. In particular, [Heiko Stübner](https://github.com/mmind) upstreamed support for the QNAP TS-433 (RK3568) in both the Linux kernel and U-Boot, which makes it possible to use this device with mainline software instead of vendor firmware.

For background see:

- Heiko Stübner’s Chemnitzer Linux-Tage 2025 talk slides:
  https://chemnitzer.linux-tage.de/2025/media/programm/folien/183.pdf
- Official U-Boot TS-433 board documentation:
  https://docs.u-boot.org/en/stable/board/qnap/ts433.html

This project focuses solely on providing a reproducible builder for a TS-433-specific U-Boot image, reusing that upstream work.

It is a helper project to build a Rockchip U-Boot image for the QNAP TS-433 (RK3568) in a reproducible way, using:

- U-Boot (GPL-2.0) as a submodule
- Trusted Firmware-A (BSD-3-Clause) as a submodule
- Rockchip rkbin firmware blobs (proprietary, redistributable)
- A pinned Debian-based Docker build environment

> [!NOTE]
> This project intentionally uses newer rkbin firmware blobs than those referenced in the official U-Boot TS-433 documentation and integrates a self-built Trusted Firmware-A (BL31) instead of the proprietary rkbin version.

The result is a `u-boot-rockchip.bin` + updated spl loader to flash the TS-433 eMMC via `rkdeveloptool`.

## Usage

### Local build (requires Docker)

```sh
git clone git@github.com:dbast/qnap-ts-433-bootloader-builder.git
cd qnap-ts-433-bootloader-builder
make submodules enable-binfmt build-image build-u-boot patch-rkbin spl-loader
```

### Remote build

Fork the repo and trigger a build via “workflow dispatch” on any branch or tag (i.e. the button next to the build workflow in the Actions tab of the forked repo). The build will upload the resulting `u-boot-rockchip.bin` and updated spl loader as workflow artifacts that is valid for 2 days.

## Flashing to TS-433

With the TS-433 in maskrom mode and `rkdeveloptool` installed on a host:

```sh
cd artifacts/
rkdeveloptool db rk356x_spl_loader_v1.*.bin  # USB/maskrom loader (from rkbin)
rkdeveloptool wl 64 u-boot-rockchip.bin      # write U-Boot to eMMC at sector 64
rkdeveloptool rd                             # reset
```

See above links for the maskrom jumper procedure.

## Reproducibility

This project aims for reproducible U-Boot and Trusted Firmware builds via:

- Pinning the entire build environment via Dockerfile, using a pinned base image and date based `snapshot.debian.org` URLs
- Pinning `u-boot` / `trusted-firmware-a` / `rkbin` submodules to specific commits
- Setting `SOURCE_DATE_EPOCH` from the last git commit timestamp (`git log -1 --format=%ct`) to fixate timestamps used during the U-Boot and Trusted Firmware builds (see [Reproducible builds](https://docs.u-boot.org/en/stable/build/reproducible.html))

## Distro-specific documentation

For end-to-end OS installation guides on the TS-433 with different distributions, see also:

- Debian: https://wiki.debian.org/InstallingDebianOn/Qnap/TS-433
- Gentoo: https://wiki.gentoo.org/wiki/QNAP_TS-433

## TODO

Integrate an open-source DDR training implementation once the community reverse-engineering effort for RK3568 DRAM initialization has matured (see CyReVolt’s ongoing work: https://mastodon.social/@CyReVolt/114762696953789988). This would allow replacing the remaining rkbin DDR firmware blobs and complete the transition to a fully open boot chain.

## Warranty

This project is provided as-is without any warranty. Use at your own risk.
