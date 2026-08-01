# qnap-ts-433-bootloader-builder

## Prior work and acknowledgements

This repository is a small helper on top of excellent upstream work. In particular, [Heiko Stübner](https://github.com/mmind) upstreamed support for the RK3568-based QNAP TS-233 and TS-433 in the Linux kernel and U-Boot, which makes it possible to use these devices with mainline software instead of vendor firmware.

For background see:

- Heiko Stübner’s Chemnitzer Linux-Tage 2025 talk slides:
  https://chemnitzer.linux-tage.de/2025/media/programm/folien/183.pdf
- Official U-Boot TS-433 board documentation:
  https://docs.u-boot.org/en/stable/board/qnap/ts433.html

This project provides reproducible, model-specific Rockchip U-Boot images for the QNAP TS-233 and TS-433, reusing that upstream work and using:

- U-Boot (GPL-2.0) as a submodule
- Trusted Firmware-A (BSD-3-Clause) as a submodule
- Rockchip rkbin firmware blobs (proprietary, redistributable)
- A pinned Debian-based Docker build environment

> [!NOTE]
> This project intentionally uses newer rkbin DDR training firmware blobs than those referenced in the official U-Boot TS-433 documentation. It also integrates a self-built Trusted Firmware-A (BL31) instead of the proprietary rkbin version.

The result is a `u-boot-rockchip-ts233.bin`, a `u-boot-rockchip-ts433.bin`, and a shared updated SPL loader to flash the eMMC via `rkdeveloptool`.

U-Boot provides a shared `qnap-ts433-rk3568_defconfig`; the builder selects the model-specific U-Boot and Linux device trees for each output image.

## Usage

### Local build (requires Docker)

```sh
git clone git@github.com:dbast/qnap-ts-433-bootloader-builder.git
cd qnap-ts-433-bootloader-builder
make submodules enable-binfmt patch-rkbin spl-loader unpatch-rkbin build-image build-bl31 build-u-boot-tf-a
```

### Remote build

Fork the repo and trigger a build via “workflow dispatch” on any branch or tag (i.e. the button next to the build workflow in the Actions tab of the forked repo). The build will upload both model-specific U-Boot images and the updated SPL loader as workflow artifacts that are valid for 2 days.

## Flashing

With the NAS in maskrom mode and `rkdeveloptool` installed on a host, select its model and flash the matching image:

```sh
cd artifacts/
MODEL=ts433  # or ts233
rkdeveloptool db rk356x_spl_loader_v1.*.bin  # USB/maskrom loader (from rkbin)
rkdeveloptool wl 64 "u-boot-rockchip-${MODEL}.bin"  # write U-Boot to eMMC at sector 64
rkdeveloptool rd                             # reset
```

See above links for the maskrom jumper procedure.

### Checking the installed version

On a running system, read the U-Boot version from the device tree:

```sh
cat /proc/device-tree/chosen/u-boot,version; echo
```

The output combines the upstream U-Boot release with the builder release tag:

```text
2026.07-builder-26.07.0
```

Development builds include the commit count and abbreviated commit, for example
`2026.07-builder-26.07.0-8-gdba09f0`. Builds with uncommitted builder changes
also end in `-dirty`.

The release bundle uses the same builder version, for example
`qnap-ts233-ts433-bootloader-26.07.0.zip`.

## Reproducibility

This project aims for reproducible U-Boot and Trusted Firmware builds via:

- Pinning the entire build environment via Dockerfile, using a pinned base image and date-based `snapshot.debian.org` URLs
- Pinning `u-boot` / `trusted-firmware-a` / `rkbin` submodules to specific commits
- Setting `SOURCE_DATE_EPOCH` from the last git commit timestamp (`git log -1 --format=%ct`) to fixate timestamps used during the U-Boot and Trusted Firmware builds (see [Reproducible builds](https://docs.u-boot.org/en/stable/build/reproducible.html))

## Distro-specific documentation

For end-to-end TS-433 OS installation guides, see also:

- Debian: https://wiki.debian.org/InstallingDebianOn/Qnap/TS-433
- Gentoo: https://wiki.gentoo.org/wiki/QNAP_TS-433
- NixOS: https://github.com/dbast/nix-config

Or follow the instructions in the [debian](debian/) folder for an SSH-based Debian Trixie network installer.

## TODO

Integrate an open-source DDR training implementation once the community reverse-engineering effort for RK3568 DRAM initialization has matured (see CyReVolt’s ongoing [work](https://mastodon.social/@CyReVolt/114762696953789988)). This would allow replacing the remaining rkbin DDR firmware blobs and complete the transition to a fully open boot chain.

## Related devices

The TS-133 is not currently built because its RK3566 SoC requires a different DDR/TPL binary and maskrom loader.

## Warranty

This project is provided as-is without any warranty. Use at your own risk.
