.ONESHELL:
SHELL=/bin/bash
.DEFAULT_GOAL=_help

# OS Detection
OS := $(shell uname -s)

# Defaults
AG_DIR_LINUX := /usr/share/antigravity
AG_DIR_MAC := /Applications/Antigravity.app/Contents
CONFIG_BASE_LINUX := $(HOME)/.config
CONFIG_BASE_MAC := $(HOME)/Library/Application Support

# Logic
ifeq ($(OS),Darwin)
    TARGET_DIR := $(AG_DIR_MAC)
    CONFIG_DIR := $(CONFIG_BASE_MAC)
else
    # Check for /opt/Antigravity fallback (common on Linux)
    ifneq ("",$(wildcard /opt/Antigravity))
        TARGET_DIR := /opt/Antigravity
    else
        TARGET_DIR := $(AG_DIR_LINUX)
    endif
    CONFIG_DIR := $(CONFIG_BASE_LINUX)
endif

.PHONY: doctor
doctor: ##H@@	Check paths and health (Dry Run)
	@echo "=== Antigravity Doctor ==="
	@echo "Detected OS:       $(OS)"
	@echo "Target Directory:  $(TARGET_DIR)"
	@echo "Target Main:       $(TARGET_DIR)/resources/app/out/jetskiAgent/main.js"
	@echo "Target Product:    $(TARGET_DIR)/resources/app/product.json"
	@echo "Config Base:       $(CONFIG_DIR)"
	@echo "Settings File:     $(CONFIG_DIR)/Antigravity/User/settings.json"
	@echo "Backup Prefix:     /tmp/antigravity_backups_*"
	@echo ""
	@echo "--- Checks ---"
	@if [ -d "$(TARGET_DIR)" ]; then \
		echo "✅ Target Dir found: $(TARGET_DIR)"; \
		# Check main.js \
		if [ -f "$(TARGET_DIR)/resources/app/out/jetskiAgent/main.js" ]; then \
			echo "✅ main.js found"; \
			if [ -w "$(TARGET_DIR)/resources/app/out/jetskiAgent/main.js" ]; then \
				echo "   INFO: main.js is writable (No sudo needed for patch)"; \
			else \
				echo "   ⚠️  main.js NOT writable (Sudo REQUIRED for patch)"; \
			fi \
		else \
			echo "❌ main.js NOT found in resources/app/out/jetskiAgent/"; \
		fi; \
		# Check product.json \
		if [ -f "$(TARGET_DIR)/resources/app/product.json" ]; then \
			echo "✅ product.json found"; \
			if [ -w "$(TARGET_DIR)/resources/app/product.json" ]; then \
				echo "   INFO: product.json is writable (No sudo needed for integrity)"; \
			else \
				echo "   ⚠️  product.json NOT writable (Sudo REQUIRED for integrity)"; \
			fi \
		else \
			echo "❌ product.json NOT found in resources/app/"; \
		fi \
	else \
		echo "❌ Target Dir NOT found (Is Antigravity installed?)"; \
	fi
	@if [ -f "$(CONFIG_DIR)/Antigravity/User/settings.json" ]; then \
		echo "✅ Settings file found"; \
	else \
		echo "❌ Settings file NOT found"; \
	fi
	@echo ""
	@echo "Run 'make 1_optimize_settings' or 'make 2_patch_code' to proceed."

.PHONY: _help
_help:
	@printf "\nUsage: make <command>, valid commands:\n\n"
	@grep -h "##H@@" $(MAKEFILE_LIST) | grep -v IGNORE_ME | sed -e 's/##H@@//' | column -t -s $$'\t'

.PHONY: format
format: ##H@@	Run `shfmt` and `black`
	shfmt -w *.sh
	-isort python/
	-black python/

.PHONY: lint
lint: ##H@@	Run `shellcheck` and `flake8`
	shellcheck *.sh
	-flake8 --max-line-length 88 python/

.PHONY: 1_optimize_settings
1_optimize_settings: ##H@@	Run settings optimization (Auto-detected OS path)
	@echo "Detected OS: $(OS)"
	@echo "Config Base: $(CONFIG_DIR)"
	python3 python/optimize_settings.py "$(CONFIG_DIR)"

.PHONY: 2_patch_code
2_patch_code: ##H@@	Run code patcher (Auto-detected OS path)
	@echo "Detected OS: $(OS)"
	@echo "Target Dir:  $(TARGET_DIR)"
	# This usually requires sudo
	python3 python/patch_code.py "$(TARGET_DIR)"

.PHONY: 3_update_integrity
3_update_integrity: ##H@@	Update integrity manifest
	# This usually requires sudo
	python3 python/update_integrity.py "$(TARGET_DIR)"
