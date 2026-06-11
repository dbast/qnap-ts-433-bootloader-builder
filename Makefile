SHELL := /bin/bash -o pipefail -o errexit

UBOOT_DIR := u-boot
RKBIN_DIR := rkbin
ATF_DIR := trusted-firmware-a
ATF_PLAT := rk3568
ATF_BUILD_DIR := $(ATF_DIR)/build/$(ATF_PLAT)/release
ATF_BL31 := $(ATF_BUILD_DIR)/bl31/bl31.elf

DOCKER_IMAGE := qnap-ts433-uboot-builder:latest
# renovate: datasource=docker depName=debian versioning=regex:^trixie-(?<major>\d{4})(?<minor>\d{2})(?<patch>\d{2})-slim$
RKBIN_TOOLS_IMAGE := debian:trixie-20260610-slim@sha256:eaa4b3f652544c3af35658e9315adab7858b51917b890d5f4b208e5575284e6d

ARTIFACTS_DIR := artifacts
LICENSES_DIR := $(ARTIFACTS_DIR)/LICENSES
DIST_DIR := dist

# Version used for naming the release bundle (override in CI, e.g. VERSION=$tag)
VERSION ?= $(shell git describe --tags --always --dirty)
ZIP_NAME := qnap-ts433-bootloader-$(VERSION).zip
ZIP_PATH := $(DIST_DIR)/$(ZIP_NAME)
UBOOT_URL := https://github.com/u-boot/u-boot
ATF_URL := https://github.com/TrustedFirmware-A/trusted-firmware-a
RKBIN_URL := https://github.com/rockchip-linux/rkbin
BUILDER_URL := https://github.com/dbast/qnap-ts-433-bootloader-builder

# set SOURCE_DATE_EPOCH for reproducible builds, see
# https://docs.u-boot.org/en/stable/build/reproducible.html
SOURCE_DATE_EPOCH := $(shell git log -1 --format=%ct)
BUILD_TAG := $(shell git rev-parse --short HEAD)

DATE_CMD := $(shell which gdate 2>/dev/null || which date)
ATF_BUILD_TIMESTAMP := $(strip $(shell TZ=UTC $(DATE_CMD) -d "@$(SOURCE_DATE_EPOCH)" +'"%H:%M:%S, %b %d %Y"'))
# portable touch timestamp ([[CC]YY]MMDDhhmm.ss) for reproducible zip entries
TOUCH_TS := $(shell TZ=UTC $(DATE_CMD) -d "@$(SOURCE_DATE_EPOCH)" +%Y%m%d%H%M.%S)

clean:
	git clean -fdx
	git submodule foreach --recursive git clean -fdx
	rm -rf $(ARTIFACTS_DIR) $(DIST_DIR)

submodules:
	git submodule update --init --recursive

enable-binfmt:
	docker run --privileged --rm tonistiigi/binfmt --install all

build-image:
	docker build --platform=linux/arm64 -t $(DOCKER_IMAGE) .

patch-rkbin:
	cd $(RKBIN_DIR) && \
	git apply ../ddrbin_param.patch && \
	git apply ../0001-Enable-setting-current_time-from-env-variable.patch

spl-loader:
	# boot_merger = x86_64 elf linux binary
	mkdir -p $(ARTIFACTS_DIR)
	docker run --rm \
	  --platform=linux/amd64 \
	  -v $$PWD:/rkbin-src \
	  -w /rkbin-src/$(RKBIN_DIR) \
	  -e SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	  -e HOST_UID=$$(id -u) \
	  -e HOST_GID=$$(id -g) \
	  $(RKBIN_TOOLS_IMAGE) \
	  bash -exc '\
	    apt-get update && \
		apt-get install -y --no-install-recommends python3 && \
	    tools/ddrbin_tool.py rk3568 tools/ddrbin_param.txt bin/rk35/rk3568_ddr_1560MHz_v1.23.bin && \
	    tools/boot_merger RKBOOT/RK3568MINIALL.ini && \
	    python3 ../normalize-rockchip-loader.py rk356x_spl_loader_v1.*.bin && \
		sha256sum rk356x_spl_loader_v1.*.bin | tee rk356x_spl_loader_v1.sha256 && \
	    cp rk356x_spl_loader_v1.* /rkbin-src/$(ARTIFACTS_DIR)/ && \
	    chown $$HOST_UID:$$HOST_GID /rkbin-src/$(ARTIFACTS_DIR)/rk356x_spl_loader_v1.* \
	  '

build-bl31:
	docker run --rm \
	  --platform=linux/arm64 \
	  -v $$PWD:/src \
	  -e BUILD_MESSAGE_TIMESTAMP='$(ATF_BUILD_TIMESTAMP)' \
	  $(DOCKER_IMAGE) \
	  bash -exc '\
	    cd $(ATF_DIR) && \
	    make PLAT=$(ATF_PLAT) bl31 && \
	    sha256sum build/$(ATF_PLAT)/release/bl31/bl31.elf | tee build/$(ATF_PLAT)/release/bl31/bl31.elf.sha256 \
	  '
	mkdir -p $(ARTIFACTS_DIR)
	cp $(ATF_BL31)* $(ARTIFACTS_DIR)/

build-u-boot:
	docker run --rm \
	  --platform=linux/arm64 \
	  -v $$PWD:/src \
	  -e SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	  $(DOCKER_IMAGE) \
	  bash -exc '\
	    cd $(UBOOT_DIR) && \
	    export BL31=../$(RKBIN_DIR)/bin/rk35/rk3568_bl31_v1.45.elf && \
	    export ROCKCHIP_TPL=../$(RKBIN_DIR)/bin/rk35/rk3568_ddr_1560MHz_v1.23.bin && \
	    make qnap-ts433-rk3568_defconfig && \
	    make BUILD_TAG=$(BUILD_TAG) && \
	    sha256sum u-boot-rockchip.bin | tee u-boot-rockchip.bin.sha256 \
	  '
	mkdir -p $(ARTIFACTS_DIR)
	cp $(UBOOT_DIR)/u-boot-rockchip.* $(ARTIFACTS_DIR)/

build-u-boot-tf-a:
	docker run --rm \
	  --platform=linux/arm64 \
	  -v $$PWD:/src \
	  -e SOURCE_DATE_EPOCH=$(SOURCE_DATE_EPOCH) \
	  $(DOCKER_IMAGE) \
	  bash -exc '\
	    cd $(UBOOT_DIR) && \
	    export BL31=../$(ATF_BL31) && \
	    export ROCKCHIP_TPL=../$(RKBIN_DIR)/bin/rk35/rk3568_ddr_1560MHz_v1.23.bin && \
	    make qnap-ts433-rk3568_defconfig && \
	    scripts/kconfig/merge_config.sh .config ../u-boot-upstream-tf-a.config && \
	    make BUILD_TAG=$(BUILD_TAG) && \
	    sha256sum u-boot-rockchip.bin | tee u-boot-rockchip.bin.sha256 \
	  '
	mkdir -p $(ARTIFACTS_DIR)
	cp $(UBOOT_DIR)/u-boot-rockchip.* $(ARTIFACTS_DIR)/

licenses:
	mkdir -p $(LICENSES_DIR)
	cp $(UBOOT_DIR)/Licenses/gpl-2.0.txt $(LICENSES_DIR)/u-boot-GPL-2.0.txt
	cp $(ATF_DIR)/docs/license.rst $(LICENSES_DIR)/trusted-firmware-a-BSD-3-Clause.txt
	cp $(RKBIN_DIR)/LICENSE $(LICENSES_DIR)/rkbin-LICENSE.txt
	cp LICENSE $(LICENSES_DIR)/builder-BSD-3-Clause.txt
	uboot_commit=$$(git -C $(UBOOT_DIR) rev-parse HEAD); \
	atf_commit=$$(git -C $(ATF_DIR) rev-parse HEAD); \
	rkbin_commit=$$(git -C $(RKBIN_DIR) rev-parse HEAD); \
	builder_commit=$$(git rev-parse HEAD); \
	builder_hash=$$($(MAKE) -s --no-print-directory nar-hash DIR=.); \
	uboot_hash=$$($(MAKE) -s --no-print-directory nar-hash DIR=$(UBOOT_DIR)); \
	atf_hash=$$($(MAKE) -s --no-print-directory nar-hash DIR=$(ATF_DIR)); \
	rkbin_hash=$$($(MAKE) -s --no-print-directory nar-hash DIR=$(RKBIN_DIR)); \
	{ \
	  echo "QNAP TS-433 bootloader artifacts - licensing & source notice"; \
	  echo "============================================================"; \
	  echo ""; \
	  echo "Generated for builder commit $$builder_commit"; \
	  echo "Builder source: $(BUILDER_URL)"; \
	  echo ""; \
	  echo "Per-repo source NAR hashes are listed with each component below."; \
	  echo "Each is the Nix archive (NAR) hash of that repository's committed"; \
	  echo "tree (tracked files only). Reproduce with:"; \
	  echo "  git -C <repo> archive HEAD | tar -x -C tmp && nix hash path tmp"; \
	  echo "(equivalently 'make nar-hash DIR=<repo>'). Reads HEAD, so patches"; \
	  echo "and build outputs do not affect it."; \
	  echo ""; \
	  echo "This release bundles binaries built from / derived from several"; \
	  echo "upstream projects. Each binary and its license terms are listed"; \
	  echo "below. The complete corresponding source for the GPL-licensed"; \
	  echo "U-Boot binary is available at the URL and commit listed; this"; \
	  echo "notice also serves as the written offer for that source."; \
	  echo ""; \
	  echo "License texts are in the LICENSES/ directory next to this file."; \
	  echo ""; \
	  echo "------------------------------------------------------------"; \
	  echo "u-boot-rockchip.bin"; \
	  echo "  Description : U-Boot bootloader image (embeds the Rockchip TPL"; \
	  echo "                and the TF-A BL31 listed below)"; \
	  echo "  License     : GPL-2.0-or-later (see LICENSES/u-boot-GPL-2.0.txt)"; \
	  echo "  Source      : $(UBOOT_URL)"; \
	  echo "  Commit      : $$uboot_commit"; \
	  echo "  NAR hash    : $$uboot_hash"; \
	  echo ""; \
	  echo "bl31.elf"; \
	  echo "  Description : Trusted Firmware-A BL31 (rk3568)"; \
	  echo "  License     : BSD-3-Clause (see LICENSES/trusted-firmware-a-BSD-3-Clause.txt)"; \
	  echo "  Source      : $(ATF_URL)"; \
	  echo "  Commit      : $$atf_commit"; \
	  echo "  NAR hash    : $$atf_hash"; \
	  echo ""; \
	  echo "rk356x_spl_loader_v1.*.bin"; \
	  echo "  Description : Rockchip SPL loader (proprietary DDR init +"; \
	  echo "                miniloader blobs, merged via boot_merger)"; \
	  echo "  License     : Rockchip proprietary (see LICENSES/rkbin-LICENSE.txt)"; \
	  echo "  Source      : $(RKBIN_URL) (redistributable binary blobs)"; \
	  echo "  Commit      : $$rkbin_commit"; \
	  echo "  NAR hash    : $$rkbin_hash"; \
	  echo ""; \
	  echo "------------------------------------------------------------"; \
	  echo "Builder scripts/patches in this repository are licensed under"; \
	  echo "BSD-3-Clause (see LICENSES/builder-BSD-3-Clause.txt)."; \
	  echo "  Commit   : $$builder_commit"; \
	  echo "  NAR hash : $$builder_hash"; \
	} > $(ARTIFACTS_DIR)/NOTICE.txt

# Usage: make nar-hash DIR=u-boot
nar-hash:
	@tmp=$$(mktemp -d); \
	git -C "$(DIR)" archive --format=tar HEAD | tar -x -C "$$tmp"; \
	nix hash path --extra-experimental-features nix-command --type sha256 --sri "$$tmp"; \
	rm -rf "$$tmp"

package:
	mkdir -p $(DIST_DIR)
	rm -f $(ZIP_PATH)
	find $(ARTIFACTS_DIR) -type f -exec touch -t $(TOUCH_TS) {} +
	cd $(ARTIFACTS_DIR) && \
	  find . -type f | sed 's|^\./||' | LC_ALL=C sort | \
	  zip -X -@ "$(CURDIR)/$(ZIP_PATH)"
	cd $(DIST_DIR) && sha256sum $(ZIP_NAME) | tee $(ZIP_NAME).sha256

.PHONY: all $(MAKECMDGOALS)
