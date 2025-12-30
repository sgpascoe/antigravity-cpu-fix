#!/bin/bash
# Antigravity CPU Fix Rollback
# Undo the patch and restore backups
set -euo pipefail

# --- DETECT OS & PATHS ---
OS_TYPE=$(uname)

if [ "$OS_TYPE" == "Darwin" ]; then
	BASE_INSTALL="/Applications/Antigravity.app/Contents"
	AG_SETTINGS="$HOME/Library/Application Support/Antigravity/User/settings.json"
else
	# Linux: prefer apt path (/usr/share), fallback to Arch/tarball (/opt)
	if [ -d "/usr/share/antigravity/resources" ]; then
		BASE_INSTALL="/usr/share/antigravity"
	elif [ -d "/opt/Antigravity/resources" ]; then
		BASE_INSTALL="/opt/Antigravity"
	else
		BASE_INSTALL="/usr/share/antigravity"
	fi
	AG_SETTINGS="$HOME/.config/Antigravity/User/settings.json"
fi

# Allow User Override (Optional Argument 1)
AG_DIR="${1:-$BASE_INSTALL}"

# Define Executable
if [ "$OS_TYPE" == "Darwin" ]; then
	AG_EXEC="$AG_DIR/MacOS/Antigravity"
else
	AG_EXEC="$AG_DIR/antigravity"
fi

# --- FIND BACKUP ---
BACKUP_DIR=""
if [ -d "/tmp" ]; then
	BACKUP_DIR=$(find /tmp -maxdepth 1 -name "antigravity_backups_*" -type d 2>/dev/null | sort | head -n 1)
fi

echo "=== ANTIGRAVITY CPU FIX ROLLBACK ==="

if [ -z "$BACKUP_DIR" ]; then
	echo "❌ No backup directory found in /tmp/"
	echo "   (Backups are expected in /tmp/antigravity_backups_YYYYMMDD_HHMMSS/)"
	exit 1
fi

echo "✅ Target Dir:  $AG_DIR"
echo "✅ Backup Dir:  $BACKUP_DIR"
echo ""

# --- SUDO REQUEST ---
# FIX: Check permissions for ALL files we might restore.
SUDO_CMD=""
NEED_SUDO=false

TARGET_MAIN="$AG_DIR/resources/app/out/jetskiAgent/main.js"
TARGET_PRODUCT="$AG_DIR/resources/app/product.json"

# 1. Check Main JS
if [ -f "$BACKUP_DIR/main.js.backup" ]; then
	if [ -f "$TARGET_MAIN" ] && [ ! -w "$TARGET_MAIN" ]; then
		NEED_SUDO=true
	fi
fi

# 2. Check Product JSON (Integrity File)
if [ -f "$BACKUP_DIR/product.json.backup" ]; then
	if [ -f "$TARGET_PRODUCT" ] && [ ! -w "$TARGET_PRODUCT" ]; then
		NEED_SUDO=true
	fi
fi

if [ "$NEED_SUDO" = true ]; then
	echo "ℹ️  System files detected (Write Protected). Using 'sudo' to restore."
	SUDO_CMD="sudo"
else
	# Fallback: If we are in /opt or /usr and don't own the dir, default to sudo
	if [[ "$AG_DIR" == "/opt"* ]] || [[ "$AG_DIR" == "/usr"* ]]; then
		if [ ! -w "$AG_DIR" ]; then
			echo "ℹ️  System directory detected. Using 'sudo' for safety."
			SUDO_CMD="sudo"
		fi
	fi
fi

# --- KILL PROCESS ---
if pgrep -f "$AG_EXEC" >/dev/null 2>&1; then
	echo "⚠️  Antigravity is running. Closing it..."
	pkill -f "$AG_EXEC" 2>/dev/null || true
	sleep 3
fi

# --- RESTORE ---
echo "🔄 Restoring files..."

# Restore main.js
if [ -f "$BACKUP_DIR/main.js.backup" ]; then
	$SUDO_CMD cp "$BACKUP_DIR/main.js.backup" "$TARGET_MAIN"
	echo "✓ Restored jetskiAgent/main.js"
else
	echo "⚠️  Backup for main.js not found."
fi

# Restore product.json (The integrity manifest)
if [ -f "$BACKUP_DIR/product.json.backup" ]; then
	$SUDO_CMD cp "$BACKUP_DIR/product.json.backup" "$TARGET_PRODUCT"
	echo "✓ Restored product.json"
fi

# Restore settings
if [ -f "$BACKUP_DIR/settings.json.backup" ]; then
	cp "$BACKUP_DIR/settings.json.backup" "$AG_SETTINGS"
	echo "✓ Restored settings.json"
fi

echo ""
echo "✅ ROLLBACK COMPLETE"
echo "You can now launch Antigravity normally."
