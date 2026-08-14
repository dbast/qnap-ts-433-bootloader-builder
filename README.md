# qnap-ts-433-bootloader-builder

[![Release](https://img.shields.io/github/v/release/dbast/qnap-ts-433-bootloader-builder?display_name=tag&sort=semver)](https://github.com/dbast/qnap-ts-433-bootloader-builder/releases/latest)
[![CI](https://img.shields.io/github/actions/workflow/status/dbast/qnap-ts-433-bootloader-builder/ci.yaml?branch=main&label=CI)](https://github.com/dbast/qnap-ts-433-bootloader-builder/actions/workflows/ci.yaml)
[![Security scan](https://img.shields.io/github/actions/workflow/status/dbast/qnap-ts-433-bootloader-builder/scan.yaml?branch=main&label=Security%20scan)](https://github.com/dbast/qnap-ts-433-bootloader-builder/actions/workflows/scan.yaml)
[![Reproducibility](https://img.shields.io/github/actions/workflow/status/dbast/qnap-ts-433-bootloader-builder/ci.yaml?branch=main&event=push&label=Reproducibility)](https://github.com/dbast/qnap-ts-433-bootloader-builder/actions/workflows/ci.yaml)
[![SLSA Build Level 3](https://slsa.dev/images/gh-badge-level3.svg)](#release-verification)
[![SBOM](https://img.shields.io/badge/SBOM-CycloneDX%201.6-6f42c1)](sbom.cdx.json)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/dbast/qnap-ts-433-bootloader-builder)

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

## Release verification

Download a release bundle and its verification files, replacing `REPLACE_ME` with the release tag:

```sh
REPOSITORY=dbast/qnap-ts-433-bootloader-builder
RELEASE_TAG=REPLACE_ME
BUNDLE="qnap-ts233-ts433-bootloader-$RELEASE_TAG.zip"

gh release download "$RELEASE_TAG" --repo "$REPOSITORY" --pattern "$BUNDLE*"
```

Check the downloaded files using any or all of these independent methods:

| Mechanism                  | What it verifies                                                                           |
| -------------------------- | ------------------------------------------------------------------------------------------ |
| SHA-256 checksum           | The download is byte-for-byte identical to the published checksum                          |
| GitHub release attestation | The asset belongs to this immutable repository release and tag                             |
| Sigstore signature         | This repository's tagged CI workflow signed the release bundle                             |
| SLSA/in-toto provenance    | The source repository, commit, workflow and run that produced the bundle and U-Boot images |
| OpenTimestamps             | The bundle existed no later than its blockchain-anchored timestamp and has not changed     |
| Source NAR hashes          | The exact committed source trees used for the builder, U-Boot, TF-A and rkbin              |
| Reproducible build         | Two independent CI builds from the same inputs produce identical bytes                     |
| CycloneDX SBOM             | Pinned U-Boot, TF-A and rkbin versions and commits for vulnerability matching              |
| VirusTotal                 | Current malware-engine results for the release bundle                                      |

No single method proves that firmware is secure; the methods provide complementary
evidence about identity, integrity, provenance, time and known components.

**Checksum** (quick integrity check):

```sh
sha256sum -c "$BUNDLE.sha256"
```

**GitHub release attestation** (proves the release is immutable and the downloaded asset matches it; requires GitHub CLI 2.81.0 or newer):

```sh
gh release verify "$RELEASE_TAG" --repo "$REPOSITORY"
gh release verify-asset "$RELEASE_TAG" "$BUNDLE" --repo "$REPOSITORY"
```

**Sigstore identity** (proves it was built by this repository's CI; requires Sigstore 3.0 or newer):

```sh
sigstore verify identity \
  --cert-identity "https://github.com/$REPOSITORY/.github/workflows/ci.yaml@refs/tags/$RELEASE_TAG" \
  --cert-oidc-issuer "https://token.actions.githubusercontent.com" \
  "$BUNDLE"
```

**Build provenance** (proves which commit, workflow and run built the images; requires GitHub CLI 2.68.0 or newer):

```sh
gh attestation verify "$BUNDLE" --repo "$REPOSITORY" \
  --signer-workflow "$REPOSITORY/.github/workflows/build.yaml" \
  --source-ref "refs/tags/$RELEASE_TAG" \
  --deny-self-hosted-runners
```

Add `--bundle "$BUNDLE.intoto.jsonl"` to verify offline against the downloaded
attestation instead of querying GitHub.

**OpenTimestamps** (proves the bundle existed at release time and has not changed since):

Drop `$BUNDLE.ots`, then `$BUNDLE`, onto https://opentimestamps.org.

After verification, extract the bundle for flashing:

```sh
unzip "$BUNDLE" -d artifacts
```

The U-Boot images carry their own provenance, so an extracted image can still be
verified on its own, without the bundle it came from:

```sh
gh attestation verify artifacts/u-boot-rockchip-ts433.bin --repo "$REPOSITORY" \
  --signer-workflow "$REPOSITORY/.github/workflows/build.yaml" \
  --source-ref "refs/tags/$RELEASE_TAG" \
  --deny-self-hosted-runners
```

### Software bill of materials

The repository tracks `sbom.cdx.json`, a CycloneDX source SBOM listing the pinned
U-Boot, Trusted Firmware-A and rkbin versions and commits. Components carry NVD
CPEs, which is what CVE scanners match on:

```sh
grype sbom:sbom.cdx.json
```

The same document is included in the bundle and published as the `sbom.cdx.json`
release asset.

GitHub Code Scanning runs Grype against the SBOM and CodeQL against the
repository's Python on every pull request, every push to `main`, and monthly.

## Flashing

With the NAS in maskrom mode and `rkdeveloptool` installed on a host, select its model and flash the matching image:

```sh
cd artifacts/
MODEL=ts433                                         # or ts233
rkdeveloptool db rk356x_spl_loader_v1.*.bin         # USB/maskrom loader (from rkbin)
rkdeveloptool wl 64 "u-boot-rockchip-${MODEL}.bin"  # write U-Boot to eMMC at sector 64
rkdeveloptool rd                                    # reset
```

See above links for the maskrom jumper procedure.

### Checking the installed version

On a running system, read the U-Boot version from the device tree:

```sh
cat /proc/device-tree/chosen/u-boot,version; echo
```

The output combines the upstream U-Boot release with the builder release tag. For release `26.08.0`, for example:

```text
2026.07-builder-26.08.0
```

Development builds include the commit count and abbreviated commit, for example
`2026.07-builder-26.08.0-2-g9930cd2`. Builds with uncommitted builder changes
also end in `-dirty`.

The full builder commit is stored separately in U-Boot's build tag and appears
in the boot banner and the U-Boot `version` command:

```text
U-Boot 2026.07-builder-26.08.0 (...), Build: 159b381c9f0e1201c9fee364881aa360b77f7494
```

The release bundle uses the same builder version, for example
`qnap-ts233-ts433-bootloader-26.08.0.zip`.

## Reproducibility

This project aims for reproducible U-Boot and Trusted Firmware builds via:

- Building every commit twice on independent GitHub-hosted runners and requiring byte-identical release bundles
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
