#!/usr/bin/env bash
# Auto-reapply the Antigravity CPU patches after updates, then launch.
# This makes the workaround resilient to app updates: if the bundled JS changes,
# we re-run the patcher before starting Antigravity.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.cache/antigravity-fix"
STATE_FILE="${STATE_DIR}/state.json"
ANTIGRAVITY_BIN="/usr/share/antigravity/antigravity"
TARGETS=(
  "/usr/share/antigravity/resources/app/out/jetskiAgent/main.js"
  "/usr/share/antigravity/resources/app/out/vs/workbench/workbench.desktop.main.js"
)

mkdir -p "${STATE_DIR}"

sha_of() {
  sha256sum "$1" | awk '{print $1}'
}

NEED_PATCH=0
declare -A CUR

for f in "${TARGETS[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "Missing target file: $f"
    NEED_PATCH=1
    continue
  fi
  cur_sha="$(sha_of "$f")"
  CUR["$f"]="$cur_sha"

  # Compare with stored SHA (very small Python helper)
  python3 - "$f" "${STATE_FILE}" "${cur_sha}" <<'PY'
import json, sys, os
f = sys.argv[1]
state_file = sys.argv[2]
cur = sys.argv[3]
try:
    with open(state_file) as fh:
        state = json.load(fh)
except FileNotFoundError:
    sys.exit(1)
if state.get(f) != cur:
    sys.exit(1)
PY
  if [[ $? -ne 0 ]]; then
    NEED_PATCH=1
  fi
done

if [[ "${NEED_PATCH}" -eq 1 ]]; then
  echo "Detected updated/unpatched Antigravity files. Re-applying patches..."
  sudo "${SCRIPT_DIR}/fix-antigravity-balanced.sh"
  # Recompute SHAs after patch
  for f in "${TARGETS[@]}"; do
    if [[ -f "$f" ]]; then
      CUR["$f"]="$(sha_of "$f")"
    fi
  done
fi

# Write state (current SHAs)
CUR_PAIRS=""
for f in "${!CUR[@]}"; do
  CUR_PAIRS+="${f}\t${CUR[$f]}\n"
done
STATE_FILE="${STATE_FILE}" CUR_PAIRS="${CUR_PAIRS}" python3 - <<'PY'
import json, os
state = {}
pairs = os.environ.get("CUR_PAIRS","").splitlines()
for line in pairs:
    if not line.strip():
        continue
    f, sha = line.split("\t",1)
    state[f] = sha
out = os.environ["STATE_FILE"]
with open(out,"w") as fh:
    json.dump(state, fh, indent=2)
print(f"State saved to {out}")
PY

echo "Launching Antigravity with devtools port..."
exec "${ANTIGRAVITY_BIN}" \
  --remote-debugging-port=9223 \
  --remote-allow-origins='*' \
  --user-data-dir=/tmp/antigravity_devtools \
  --disable-features=RendererCodeIntegrity \
  "$@"

