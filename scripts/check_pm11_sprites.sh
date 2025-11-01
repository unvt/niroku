#!/usr/bin/env bash
# Simple verification script for PM11 sprites and style.json
# Usage: sudo ./scripts/check_pm11_sprites.sh [HOST]
# Default HOST: 127.0.0.1

set -euo pipefail
HOST=${1:-127.0.0.1}
BASE_URL="http://$HOST"
STYLE_URL="$BASE_URL/pm11/style.json"
SPRITE_JSON="$BASE_URL/sprites/v4/light.json"
SPRITE_PNG="$BASE_URL/sprites/v4/light.png"
SPRITE_2X="$BASE_URL/sprites/v4/light@2x.png"

echo "Checking PM11 viewer endpoints on $BASE_URL"

check() {
  local url="$1"
  local name="$2"
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" || echo "000")
  if [ "$status" = "200" ]; then
    echo "[OK]   $name -> $url (HTTP $status)"
    return 0
  else
    echo "[FAIL] $name -> $url (HTTP $status)"
    return 1
  fi
}

all_ok=0
check "$STYLE_URL" "PM11 style.json" || all_ok=1
check "$SPRITE_JSON" "sprite JSON" || all_ok=1
check "$SPRITE_PNG" "sprite PNG" || all_ok=1
# @2x optional
check "$SPRITE_2X" "sprite @2x PNG" || echo "[WARN] sprite @2x may be missing (fall back to light.png)"

# Validate JSON if available
if command -v jq >/dev/null 2>&1; then
  if curl -s --max-time 5 "$SPRITE_JSON" | jq empty >/dev/null 2>&1; then
    echo "[OK]   sprite JSON is valid JSON"
  else
    echo "[FAIL] sprite JSON is invalid JSON or not reachable"
    all_ok=1
  fi
else
  echo "[INFO] jq not installed; skipping JSON validation (install jq to validate)"
fi

if [ $all_ok -eq 0 ]; then
  echo "\nAll critical PM11 sprite/style checks passed. Open http://$HOST/pm11/ to view the map."
  exit 0
else
  echo "\nSome checks failed. Inspect /opt/niroku/data/sprites/v4 and /opt/niroku/data/pm11/style.json and Caddy logs (journalctl -u caddy-niroku)."
  exit 2
fi
