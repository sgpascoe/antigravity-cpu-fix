# How to Fix Antigravity's CPU Issues (Ongoing Fixes)

## Yes, We Can Fix It!

We found the source code and can apply fixes. Here are your options:

## Option 1: Settings Fixes (Already Applied) ✅

I've already applied aggressive settings optimizations:
- Disabled agent manager panel
- Reduced all rendering
- Throttled updates

**Status:** Applied, but requires restart to take effect.

## Option 2: Wrapper Scripts (Recommended)

I created wrapper scripts that:
- Launch with optimized Electron flags
- Throttle CPU usage
- Apply runtime fixes

**To use:**
```bash
cd "/home/cove-mint/Cursor-Projects/mint jobs 2"
./fix-antigravity-wrapper.sh
```

This creates scripts in `~/.local/bin/`:
- `antigravity-fixed` - Launch with optimizations
- `antigravity-throttle` - Throttle CPU to 50%
- `antigravity-apply-settings` - Apply aggressive settings

## Option 3: Patch Source Code (Advanced)

The source code is at:
```
/usr/share/antigravity/resources/app/out/
```

**Files need sudo to modify**, but we can:

1. **Backup original:**
```bash
sudo cp /usr/share/antigravity/resources/app/out/vs/code/electron-browser/workbench/jetskiAgent.js \
        /usr/share/antigravity/resources/app/out/vs/code/electron-browser/workbench/jetskiAgent.js.backup
```

2. **Find the actual agent code:**
```bash
find /usr/share/antigravity/resources/app -name "*agent*" -type f | grep -E "\.(js|ts)$"
```

3. **The main agent code is likely in:**
```
/usr/share/antigravity/resources/app/out/jetskiAgent/main.js
```

4. **Patch it** (requires finding polling code and replacing it)

**Warning:** This will be overwritten on updates. Better to use wrapper scripts.

## Option 4: CPU Throttling (Quick Fix)

Limit CPU usage without fixing root cause:

```bash
# Install cpulimit
sudo apt install cpulimit

# Throttle renderer processes to 30% CPU each
while true; do
    ps aux | grep "/usr/share/antigravity.*--type=zygote" | grep -v grep | awk '{print $2}' | \
    while read pid; do
        cpulimit -p "$pid" -l 30 &
    done
    sleep 5
done
```

## Option 5: Process Priority (Reduce Impact)

Lower priority so it doesn't hog CPU:

```bash
# Lower priority of all Antigravity processes
ps aux | grep antigravity | grep -v grep | awk '{print $2}' | \
while read pid; do
    sudo renice +10 "$pid"
done
```

## Option 6: DevTools Injection (If Accessible)

If devtools are accessible (Ctrl+Shift+I or Ctrl+Alt+I):

1. Open devtools console
2. Paste the JavaScript fixes from `antigravity-inject-fixes` script
3. This patches polling/throttling at runtime

**Note:** Most production Electron apps disable devtools.

## Option 7: Environment Variables

Set Electron flags via environment:

```bash
export ELECTRON_FLAGS="--disable-background-timer-throttling --js-flags='--expose-gc'"
antigravity
```

## Recommended Approach

**Best combination:**

1. **Apply settings** (already done, restart needed)
2. **Use wrapper script** to launch with optimizations
3. **Throttle CPU** if still too high
4. **Close one window** (cuts CPU in half)

```bash
# Step 1: Apply settings
~/.local/bin/antigravity-apply-settings

# Step 2: Launch with optimizations
~/.local/bin/antigravity-fixed

# Step 3: (Optional) Throttle CPU in another terminal
~/.local/bin/antigravity-throttle 50
```

## What We Found

- Source code is accessible at `/usr/share/antigravity/resources/app/out/`
- Agent code is in `jetskiAgent/` directory
- Files are minified but readable
- Files need sudo to modify (will be overwritten on updates)

## Why Wrapper Scripts Are Best

1. **No root access needed** (except for CPU throttling)
2. **Survives updates** (doesn't modify installed files)
3. **Easy to disable** (just use regular `antigravity` command)
4. **Can combine multiple fixes**

## Next Steps

1. **Restart Antigravity** to apply settings
2. **Use wrapper script** for future launches
3. **Monitor CPU** with `./monitor-antigravity-cpu.sh`
4. **Report to Google** (this is their bug to fix)

The wrapper scripts are ready to use!

