###########################################################

TARGET=Onion
VERSION=4.2.0-beta
RA_SUBVERSION=1.14.0.2

###########################################################

ifneq ($(VERSION_OVERRIDE),)
VERSION = $(VERSION_OVERRIDE)
endif
 
RELEASE_NAME := $(TARGET)-v$(VERSION)

ifdef OS
	current_dir := $(shell cd)
	ROOT_DIR := $(subst \,/,$(current_dir))
	makedir := mkdir
	createfile := echo.>
else
	ROOT_DIR := $(shell pwd)
	makedir := mkdir -p
	createfile := touch
endif

# Directories
SRC_DIR             := $(ROOT_DIR)/src
THIRD_PARTY_DIR     := $(ROOT_DIR)/third-party
BUILD_DIR           := $(ROOT_DIR)/build
BUILD_TEST_DIR      := $(ROOT_DIR)/build_test
TEST_SRC_DIR		:= $(ROOT_DIR)/test
BIN_DIR             := $(ROOT_DIR)/build/.tmp_update/bin
DIST_DIR            := $(ROOT_DIR)/dist
INSTALLER_DIR       := $(DIST_DIR)/miyoo/app/.tmp_update
RELEASE_DIR         := $(ROOT_DIR)/release
STATIC_BUILD        := $(ROOT_DIR)/static/build
STATIC_DIST         := $(ROOT_DIR)/static/dist
STATIC_CONFIGS      := $(ROOT_DIR)/static/configs
CACHE               := $(ROOT_DIR)/cache
STATIC_PACKAGES     := $(ROOT_DIR)/static/packages
PACKAGES_DIR        := $(ROOT_DIR)/build/App/PackageManager/data
PACKAGES_EMU_DEST   := $(PACKAGES_DIR)/Emu
PACKAGES_APP_DEST   := $(PACKAGES_DIR)/App
PACKAGES_RAPP_DEST  := $(PACKAGES_DIR)/RApp
TEMP_DIR            := $(ROOT_DIR)/cache/temp
ifeq (,$(GTEST_INCLUDE_DIR))
GTEST_INCLUDE_DIR = /usr/include/
endif

TOOLCHAIN := mholdg16/miyoomini-toolchain:latest

include ./src/common/commands.mk

###########################################################

.PHONY: all version core apps external release clean deepclean git-clean with-toolchain patch lib test

all: dist

version: # used by workflow
	@echo $(VERSION)
print-version:
	@echo Onion v$(VERSION)
	@echo RetroArch sub-v$(RA_SUBVERSION)

$(CACHE)/.setup:
	@$(ECHO) $(PRINT_RECIPE)
	@mkdir -p $(BUILD_DIR) $(DIST_DIR) $(RELEASE_DIR)
	@rsync -a --exclude='.gitkeep' $(STATIC_BUILD)/ $(BUILD_DIR)
	@rsync -a --exclude='.gitkeep' $(STATIC_DIST)/ $(DIST_DIR)
# Copy shared libraries
	@cp -R $(ROOT_DIR)/lib/. $(DIST_DIR)/miyoo/app/.tmp_update/lib
# Set version number
	@mkdir -p $(BUILD_DIR)/.tmp_update/onionVersion
	@echo -n "v$(VERSION)" > $(BUILD_DIR)/.tmp_update/onionVersion/version.txt
	@sed -i "s/{VERSION}/$(VERSION)/g" $(BUILD_DIR)/autorun.inf
# Copy all resources from src folders
	@find \
		$(SRC_DIR)/gameSwitcher \
		$(SRC_DIR)/chargingState \
		$(SRC_DIR)/bootScreen \
		$(SRC_DIR)/themeSwitcher \
		$(SRC_DIR)/tweaks \
		$(SRC_DIR)/randomGamePicker \
		$(SRC_DIR)/easter \
		-depth -type d -name res -exec cp -r {}/. $(BUILD_DIR)/.tmp_update/res/ \;
	@find \
		$(SRC_DIR)/packageManager \
		$(SRC_DIR)/themeSwitcher \
		-depth -type d -name script -exec cp -r {}/. $(BUILD_DIR)/.tmp_update/script/ \;
	@find $(SRC_DIR)/installUI -depth -type d -name res -exec cp -r {}/. $(INSTALLER_DIR)/res/ \;
# Download themes from theme repo
	@chmod a+x $(ROOT_DIR)/.github/get_themes.sh && $(ROOT_DIR)/.github/get_themes.sh
# Copy static configs
	@mkdir -p $(TEMP_DIR)/configs $(BUILD_DIR)/.tmp_update/config
	@rsync -a --exclude='.gitkeep' $(STATIC_CONFIGS)/ $(TEMP_DIR)/configs
# Copy static packages
	@mkdir -p $(PACKAGES_APP_DEST) $(PACKAGES_EMU_DEST) $(PACKAGES_RAPP_DEST)
	@rsync -a --exclude='.gitkeep' $(STATIC_PACKAGES)/App/ $(PACKAGES_APP_DEST)
	@rsync -a --exclude='.gitkeep' $(STATIC_PACKAGES)/Emu/ $(PACKAGES_EMU_DEST)
	@rsync -a --exclude='.gitkeep' $(STATIC_PACKAGES)/RApp/ $(PACKAGES_RAPP_DEST)
	@$(STATIC_PACKAGES)/common/apply.sh "$(PACKAGES_EMU_DEST)"
	@$(STATIC_PACKAGES)/common/apply.sh "$(PACKAGES_RAPP_DEST)"
	@$(STATIC_PACKAGES)/common/auto_advmenu_rc.sh "$(PACKAGES_EMU_DEST)" "$(TEMP_DIR)/configs/BIOS/.advance/advmenu.rc"
	@$(STATIC_PACKAGES)/common/auto_advmenu_rc.sh "$(PACKAGES_RAPP_DEST)" "$(TEMP_DIR)/configs/BIOS/.advance/advmenu.rc"
# Set flag: finished setup
	@touch $(CACHE)/.setup

build: core apps external
	@$(ECHO) "\n-> [BUILD READY!]"

core: $(CACHE)/.setup
	@$(ECHO) $(PRINT_RECIPE)
# Build Onion binaries
	@cd $(SRC_DIR)/bootScreen && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/chargingState && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/gameSwitcher && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/mainUiBatPerc && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/keymon && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/playActivity && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/themeSwitcher && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/tweaks && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/packageManager && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/sendkeys && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/setState && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/renameRom && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/infoPanel && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/prompt && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/batmon && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/easter && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/read_uuid && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/detectKey && BUILD_DIR=$(BIN_DIR) make
	@cd $(SRC_DIR)/axp && BUILD_DIR=$(BIN_DIR) make
# Build dependencies for installer
	@mkdir -p $(INSTALLER_DIR)/bin
	@cd $(SRC_DIR)/installUI && BUILD_DIR=$(INSTALLER_DIR)/bin/ VERSION=$(VERSION) make
	@cp $(BIN_DIR)/prompt $(INSTALLER_DIR)/bin/
	@cp $(BIN_DIR)/batmon $(INSTALLER_DIR)/bin/
	@cp $(BIN_DIR)/detectKey $(INSTALLER_DIR)/bin/
	@cp $(BIN_DIR)/infoPanel $(INSTALLER_DIR)/bin/

apps: $(CACHE)/.setup
	@$(ECHO) $(PRINT_RECIPE)
	@cd $(SRC_DIR)/playActivityUI && BUILD_DIR="$(PACKAGES_APP_DEST)/Activity Tracker/App/PlayActivity" make
	@find $(SRC_DIR)/playActivityUI -depth -type d -name res -exec cp -r {}/. "$(PACKAGES_APP_DEST)/Activity Tracker/App/PlayActivity/res/" \;
	@find $(SRC_DIR)/packageManager -depth -type d -name res -exec cp -r {}/. $(BUILD_DIR)/App/PackageManager/res/ \;
	@cd $(SRC_DIR)/clock && BUILD_DIR="$(BIN_DIR)" make
	@cd $(SRC_DIR)/randomGamePicker && BUILD_DIR="$(BIN_DIR)" make
# Preinstalled apps
	@cp -a "$(PACKAGES_APP_DEST)/Activity Tracker/." $(BUILD_DIR)/
	@cp -a "$(PACKAGES_APP_DEST)/Quick Guide/." $(BUILD_DIR)/
	@cp -a "$(PACKAGES_APP_DEST)/RetroArch (Shortcut)/." $(BUILD_DIR)/
	@cp -a "$(PACKAGES_APP_DEST)/Tweaks/." $(BUILD_DIR)/
	@cp -a "$(PACKAGES_APP_DEST)/ThemeSwitcher/." $(BUILD_DIR)/

$(THIRD_PARTY_DIR)/RetroArch/retroarch_miyoo354:
	@$(ECHO) $(PRINT_RECIPE)
# RetroArch
	@cd $(THIRD_PARTY_DIR)/RetroArch && make clean all
	@cd $(THIRD_PARTY_DIR)/RetroArch && make clean all ADD_NETWORKING=1 PACKAGE_NAME=retroarch_miyoo354

external: $(CACHE)/.setup $(THIRD_PARTY_DIR)/RetroArch/retroarch_miyoo354
	@$(ECHO) $(PRINT_RECIPE)
# Add RetroArch
	@$(ECHO) "\n-- Add RetroArch"
	@cp $(THIRD_PARTY_DIR)/RetroArch/retroarch $(BUILD_DIR)/RetroArch/
	@cp $(THIRD_PARTY_DIR)/RetroArch/retroarch_miyoo354 $(BUILD_DIR)/RetroArch/
	@echo $(RA_SUBVERSION) > $(BUILD_DIR)/RetroArch/onion_ra_version.txt
# SearchFilter
	@$(ECHO) "\n-- Build SearchFilter"
	@cd $(THIRD_PARTY_DIR)/SearchFilter && make build && cp -a build/. $(BUILD_DIR)
	@cp -a $(BUILD_DIR)/App/Search/. "$(PACKAGES_APP_DEST)/Search (Find your games)/App/Search"
	@mv $(BUILD_DIR)/App/Filter "$(PACKAGES_APP_DEST)/List shortcuts (Filter+Refresh)/App/Filter"
# Other
	@$(ECHO) "\n-- Build Terminal"
	@cd $(THIRD_PARTY_DIR)/Terminal && make && cp ./st "$(BIN_DIR)"
	@$(ECHO) "\n-- Build DinguxCommander"
	@cd $(THIRD_PARTY_DIR)/DinguxCommander && make && cp ./output/DinguxCommander "$(PACKAGES_APP_DEST)/File Explorer (DinguxCommander)/App/Commander_Italic"

dist: build
	@$(ECHO) $(PRINT_RECIPE)
# Package configs
	@cp -R $(TEMP_DIR)/configs/Saves/CurrentProfile/ $(TEMP_DIR)/configs/Saves/GuestProfile
	@cd $(TEMP_DIR)/configs && zip -rq $(BUILD_DIR)/.tmp_update/config/configs.pak .
	@rm -rf $(TEMP_DIR)/configs
	@rmdir $(TEMP_DIR)
# Package RetroArch separately
	@cd $(BUILD_DIR) && zip -rq retroarch.pak RetroArch
	@mkdir -p $(DIST_DIR)/RetroArch
	@mv $(BUILD_DIR)/retroarch.pak $(DIST_DIR)/RetroArch/
	@echo $(RA_SUBVERSION) > $(DIST_DIR)/RetroArch/ra_package_version.txt
# Package Onion core
	@cd $(BUILD_DIR) && zip -rq $(DIST_DIR)/miyoo/app/.tmp_update/onion.pak . -x RetroArch RetroArch/\*
	@$(ECHO) "\n-> [DIST READY!]"

release: dist
	@$(ECHO) $(PRINT_RECIPE)
	@rm -f $(RELEASE_DIR)/$(RELEASE_NAME).zip
	@cd $(DIST_DIR) && zip -rq $(RELEASE_DIR)/$(RELEASE_NAME).zip .
	@$(ECHO) "\n-> [RELEASE READY!]"

clean:
	@$(ECHO) $(PRINT_RECIPE)
	@rm -rf $(BUILD_DIR) $(BUILD_TEST_DIR) $(ROOT_DIR)/dist $(TEMP_DIR)/configs
	@rm -f $(CACHE)/.setup
	@find include src -type f -name *.o -exec rm -f {} \;

deepclean: clean
	@rm -rf $(CACHE)
	@cd $(THIRD_PARTY_DIR)/RetroArch && make clean
	@cd $(THIRD_PARTY_DIR)/SearchFilter && make clean
	@cd $(THIRD_PARTY_DIR)/Terminal && make clean
	@cd $(THIRD_PARTY_DIR)/DinguxCommander && make clean

dev: clean
	@$(MAKE_DEV)

git-clean:
	@git clean -xfd -e .vscode

git-submodules:
	@git submodule update --init --recursive

pwd:
	@echo $(ROOT_DIR)

$(CACHE)/.docker:
	docker pull $(TOOLCHAIN)
	$(makedir) cache
	$(createfile) $(CACHE)/.docker

toolchain: $(CACHE)/.docker
	docker run -it --rm -v "$(ROOT_DIR)":/root/workspace $(TOOLCHAIN) /bin/bash

with-toolchain: $(CACHE)/.docker
	docker run --rm -v "$(ROOT_DIR)":/root/workspace $(TOOLCHAIN) /bin/bash -c "source /root/.bashrc; make $(CMD)"

patch:
	@chmod a+x $(ROOT_DIR)/.github/create_patch.sh && $(ROOT_DIR)/.github/create_patch.sh

lib:
	@cd $(ROOT_DIR)/include/cJSON && make clean && make
	@cd $(ROOT_DIR)/include/SDL && make clean && make

test:
	@mkdir -p $(BUILD_TEST_DIR)/infoPanel_test_data && cd $(TEST_SRC_DIR) && BUILD_DIR=$(BUILD_TEST_DIR)/ make dev
	@cp -R $(TEST_SRC_DIR)/infoPanel_test_data $(BUILD_TEST_DIR)/
	cd $(BUILD_TEST_DIR) && ./test

format:
	@find ./src -regex '.*\.\(c\|h\|cpp\|hpp\)' -exec clang-format -style=file -i {} \;
