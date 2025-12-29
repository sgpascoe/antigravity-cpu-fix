#!/bin/bash
# Antigravity CPU Fix Installer
# One-click install + verify
set -euo pipefail

SCRIPT_DIR="$(dirname "$0")"
BACKUP_DIR="/tmp/antigravity_backups_$(date +%Y%m%d_%H%M%S)"

echo "=== ANTIGRAVITY CPU FIX INSTALLER ==="
echo "This will apply the CPU fix and show before/after CPU usage."
echo "Backups will be created in: $BACKUP_DIR"
echo ""

# --- ARGUMENT PARSING ---
SUDO_ALLOW=false

for arg in "$@"; do
	case $arg in
	--sudo)
		SUDO_ALLOW=true
		;;
	esac
done

# --- DETECT OS & PATHS ---
OS_TYPE=$(uname)

if [ "$OS_TYPE" == "Darwin" ]; then
	# macOS
	BASE_INSTALL="/Applications/Antigravity.app/Contents"
	CONFIG_BASE="$HOME/Library/Application Support"
	AG_SETTINGS="$CONFIG_BASE/Antigravity/User/settings.json"
else
	# Linux (Arch/Debian)
	if [ -d "/opt/Antigravity" ]; then
		BASE_INSTALL="/opt/Antigravity"
	else
		BASE_INSTALL="/usr/share/antigravity"
	fi
	CONFIG_BASE="$HOME/.config"
	AG_SETTINGS="$CONFIG_BASE/Antigravity/User/settings.json"
fi

# Allow User Override (Optional Argument 1)
# Note: If overriding on macOS, point to the 'Contents' folder
AG_DIR="${1:-$BASE_INSTALL}"
if [ "$OS_TYPE" == "Darwin" ]; then
	antigravity="$AG_DIR/MacOS/Antigravity"
else
	antigravity="$AG_DIR/antigravity"
fi

# Validation
if [ ! -d "$AG_DIR/resources" ]; then
	echo "❌ Error: Could not find 'resources' folder in: $AG_DIR"
	echo "   macOS: Point to .../Antigravity.app/Contents"
	echo "   Linux: Point to .../antigravity (or /opt/Antigravity)"
	echo "Set this by the command line, i.e., AG_DIR=<someplace> bash install.sh"
	echo "You can also set AG_SETTINGS if you have issues."
	exit 1
fi

echo "✅ Detected OS: $OS_TYPE"
echo "✅ Target Dir:  $AG_DIR"
echo "✅ Config File: $AG_SETTINGS"

# --- SUDO REQUEST ---
# FIX: Check write permission on the ACTUAL FILES we need to patch.
TARGET_FILE="$AG_DIR/resources/app/out/jetskiAgent/main.js"
PRODUCT_FILE="$AG_DIR/resources/app/product.json"

# Check write access (if product.json exists, we must be able to write to it too)
if [ -w "$TARGET_FILE" ] && { [ ! -f "$PRODUCT_FILE" ] || [ -w "$PRODUCT_FILE" ]; }; then
	echo "ℹ️  User write access confirmed on target files."
	SUDO_CMD=""
elif [ "$SUDO_ALLOW" = true ]; then
	echo "⚡  System directory detected."
	echo "ℹ️  --sudo flag passed. Using sudo."
	SUDO_CMD="sudo"
else
	echo "⚠️  Write permission missing for target files."
	echo "   This script needs to modify system files:"
	echo "     - $TARGET_FILE"
	echo "     - $PRODUCT_FILE"
	echo ""
	echo "   Options:"
	echo "     [y] Use 'sudo' (Requires root access)"
	echo "     [N] Abort (Select this to manually chown the files, then run the script again.)"
	echo "         HINT: sudo chown $USER \"$TARGET_FILE\" \"$PRODUCT_FILE\""
	echo ""
	read -rp "   Select [y/N]: " choice
	case "$choice" in
	[Yy] | [Yy][Ee][Ss]) SUDO_CMD="sudo" ;;
	*)
		echo "Aborting. Please fix permissions and run again."
		exit 1
		;;
	esac
fi

# --- SMART PROCESS CHECK & BENCHMARK ---
# Check if Antigravity is running
if pgrep -f "$antigravity" >/dev/null 2>&1; then
	echo "⚠️  Antigravity is currently running."
	echo "📊 Benchmarking CPU usage BEFORE fix (10s)..."
	# shellcheck disable=SC2009
	BEFORE_CPU=$(ps aux | grep -E "$antigravity" | grep -v grep | awk '{sum+=$3} END {print sum}' 2>/dev/null || echo "0")
	echo "   Before: ${BEFORE_CPU}% total CPU"

	echo "🛑 Closing Antigravity to apply patch..."
	pkill -f "$antigravity" || true
	sleep 2
else
	echo "ℹ️  Antigravity is not running. Skipping 'Before' benchmark."
	BEFORE_CPU="0"
fi

# --- SMART BACKUP ---
CREATE_BACKUP=true

# Check if any backups already exist
if ls -d /tmp/antigravity_backups_* >/dev/null 2>&1; then
	echo "ℹ️  Existing backups found in /tmp/."
	read -rp "   Create a NEW redundant backup? [y/N] " backup_choice
	case "$backup_choice" in
	[Yy] | [Yy][Ee][Ss]) CREATE_BACKUP=true ;;
	*) CREATE_BACKUP=false ;;
	esac
fi

echo ""
echo "🔧 Applying patch..."

if [ "$CREATE_BACKUP" = true ]; then
	mkdir -p "$BACKUP_DIR"
	echo "📦 Backing up files to: $BACKUP_DIR"
	$SUDO_CMD cp "$AG_DIR/resources/app/out/jetskiAgent/main.js" "$BACKUP_DIR/main.js.backup"
	$SUDO_CMD cp "$AG_DIR/resources/app/product.json" "$BACKUP_DIR/product.json.backup"
	cp "$AG_SETTINGS" "$BACKUP_DIR/settings.json.backup"
else
	echo "⏩ Skipping backup (using existing)."
fi

# --- CALL PYTHON SCRIPTS ---

# 1. Patch Code
$SUDO_CMD python3 "$SCRIPT_DIR/python/patch_code.py" "$AG_DIR"

# 2. Fix Integrity (Checksums)
# Note: Uses the "Nuclear Option" logic if specific key fails
echo "🔧 Updating Integrity Checksums..."
$SUDO_CMD python3 "$SCRIPT_DIR/python/update_integrity.py" "$AG_DIR"

# 3. Optimize Settings
# Note: Edits the user config file, not the install dir
python3 "$SCRIPT_DIR/python/optimize_settings.py" "$CONFIG_BASE"

echo "✓ Patch applied successfully"
echo ""

# --- DIFF DISPLAY ---
OLDEST_BACKUP=$(find /tmp -maxdepth 1 -name "antigravity_backups_*" -type d 2>/dev/null | sort | head -n 1)

BACKUP_MAIN="$OLDEST_BACKUP/main.js.backup"
TARGET_MAIN="$AG_DIR/resources/app/out/jetskiAgent/main.js"
BACKUP_PRODUCT="$OLDEST_BACKUP/product.json.backup"
TARGET_PRODUCT="$AG_DIR/resources/app/product.json"

if [ -f "$BACKUP_MAIN" ]; then
	echo "=== CODE CHANGES ==="
	echo "To compare against oldest backup: $OLDEST_BACKUP"
	echo "Run the below commands:"
	echo "   diff -u \"$BACKUP_MAIN\" \"$TARGET_MAIN\" --color=always || true"
	echo "   diff -u \"$TARGET_PRODUCT\" \"$BACKUP_PRODUCT\" --color=always || true"
	echo "===================="
fi

# macOS warning
if [ "$OS_TYPE" == "Darwin" ]; then
	echo "🔏 If it crashes, you may need to re-sign application"
	echo "   to bypass modification checks."
	echo "run: sudo codesign --force --deep --sign - \"$AG_DIR\""
fi

# Launch Antigravity
echo "🚀 Launching Antigravity with devtools port 9223..."
mkdir -p /tmp/antigravity_diagnostics

"$antigravity" --remote-debugging-port=9223 --remote-allow-origins='*' --disable-features=RendererCodeIntegrity \
	>/tmp/antigravity_diagnostics/antigravity_install.log 2>&1 &

echo ""
echo "💡 HINT: If you are launching it manually (not via the script),"
echo "    try adding --disable-features=RendererCodeIntegrity"
echo "    to your desktop shortcut or command line if you have issues/errors."
echo "       \"$antigravity\" --disable-features=RendererCodeIntegrity"
echo "    The script does this automatically, but your desktop icon does not."
echo "    Otherwise, you should be good to go!"
echo ""
echo "Sleeping 15 seconds..."

sleep 15

# Benchmark after
echo ""
echo "📊 Benchmarking CPU usage AFTER fix (10s)..."
# shellcheck disable=SC2009
AFTER_CPU=$(ps aux | grep -E "$antigravity" | grep -v grep | awk '{sum+=$3} END {print sum}' 2>/dev/null || echo "-1 (n/a)")
echo "   After: ${AFTER_CPU}% total CPU"

echo ""
echo "✅ INSTALL COMPLETE"
if [ "$CREATE_BACKUP" = true ]; then
	echo "   Backups: $BACKUP_DIR"
else
	echo "   Backups: Skipped (Using existing)"
fi
echo "   Before: ${BEFORE_CPU}% CPU"
echo "   After:  ${AFTER_CPU}% CPU"
echo ""
echo "To undo: ./rollback.sh"
