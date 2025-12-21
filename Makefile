SHELL := /bin/bash -o pipefail -o errexit

UBOOT_DIR := u-boot
RKBIN_DIR := rkbin
ATF_DIR := trusted-firmware-a
ATF_PLAT := rk3568
ATF_BUILD_DIR := $(ATF_DIR)/build/$(ATF_PLAT)/release
ATF_BL31 := $(ATF_BUILD_DIR)/bl31/bl31.elf

DOCKER_IMAGE := qnap-ts433-uboot-builder:latest
RKBIN_TOOLS_IMAGE := debian:13

ARTIFACTS_DIR := artifacts

# set SOURCE_DATE_EPOCH for reproducible builds, see
# https://docs.u-boot.org/en/stable/build/reproducible.html
SOURCE_DATE_EPOCH := $(shell git log -1 --format=%ct)

DATE_CMD := $(shell which gdate 2>/dev/null || which date)
ATF_BUILD_TIMESTAMP := $(strip $(shell TZ=UTC $(DATE_CMD) -d "@$(SOURCE_DATE_EPOCH)" +'"%H:%M:%S, %b %d %Y"'))

clean:
	git clean -fdx
	git submodule foreach --recursive git clean -fdx
	rm -rf $(ARTIFACTS_DIR)

submodules:
	git submodule update --init --recursive

enable-binfmt:
	docker run --privileged --rm tonistiigi/binfmt --install all

build-image:
	docker build --platform=linux/arm64 -t $(DOCKER_IMAGE) .

patch-rkbin:
	cd $(RKBIN_DIR) && git apply ../ddrbin_param.patch

spl-loader:
	# boot_merger = x86_64 elf linux binary
	mkdir -p $(ARTIFACTS_DIR)
	docker run --rm \
	  --platform=linux/amd64 \
	  -v $$PWD:/rkbin-src \
	  -w /rkbin-src/$(RKBIN_DIR) \
	  $(RKBIN_TOOLS_IMAGE) \
	  bash -exc '\
	    apt-get update && \
		apt-get install -y --no-install-recommends python3 && \
	    tools/ddrbin_tool.py rk3568 tools/ddrbin_param.txt bin/rk35/rk3568_ddr_1560MHz_v1.23.bin && \
	    tools/boot_merger RKBOOT/RK3568MINIALL.ini && \
		sha256sum rk356x_spl_loader_v1.*.bin | tee rk356x_spl_loader_v1.sha256 && \
	    cp rk356x_spl_loader_v1.* /rkbin-src/$(ARTIFACTS_DIR)/ \
	  '

patch-tf-a:
	cd trusted-firmware-a && \
	git apply ../0001-Print-ID_AA64ISAR0_EL1-ID_AA64ISAR1_EL1.patch && \
	git apply ../0002-Set-baudrate-to-115200.patch

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
	    export BL31=../$(ATF_BL31) && \
	    export ROCKCHIP_TPL=../$(RKBIN_DIR)/bin/rk35/rk3568_ddr_1560MHz_v1.23.bin && \
	    make qnap-ts433-rk3568_defconfig && \
	    make && \
	    sha256sum u-boot-rockchip.bin | tee u-boot-rockchip.bin.sha256 \
	  '
	mkdir -p $(ARTIFACTS_DIR)
	cp $(UBOOT_DIR)/u-boot-rockchip.* $(ARTIFACTS_DIR)/

.PHONY: all $(MAKECMDGOALS)
