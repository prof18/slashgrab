#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"

bash -n Scripts/*.sh ci.sh
git --no-pager diff --check
"$ROOT_DIR/Scripts/test.sh"

"$ROOT_DIR/Scripts/build_and_run.sh" --verify

DEV_APP_INFO="$ROOT_DIR/Slashgrab Dev.app/Contents/Info.plist"
if [[ "$(/usr/bin/plutil -extract SUEnableAutomaticChecks raw "$DEV_APP_INFO")" != "false" ||
      -n "$(/usr/bin/plutil -extract SUFeedURL raw "$DEV_APP_INFO")" ||
      -n "$(/usr/bin/plutil -extract SUPublicEDKey raw "$DEV_APP_INFO")" ]]; then
  echo "ERROR: Dev packages must keep Sparkle fully disabled." >&2
  exit 1
fi

has_sparkle_key_material() {
  [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]] && return 0
  [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" && -f "$SPARKLE_PRIVATE_KEY_FILE" ]] && return 0
  [[ -f "$ROOT_DIR/.env" ]] || return 1

  (
    set -a
    source "$ROOT_DIR/.env"
    set +a
    [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]] ||
      [[ -n "${SPARKLE_PRIVATE_KEY_FILE:-}" && -f "$SPARKLE_PRIVATE_KEY_FILE" ]]
  )
}

if [[ "${CI_SKIP_PRODUCTION_VERIFY:-0}" == "1" ]]; then
  echo "Skipping production package verification because CI_SKIP_PRODUCTION_VERIFY=1."
elif has_sparkle_key_material || [[ "${CI_REQUIRE_PRODUCTION_VERIFY:-0}" == "1" ]]; then
  "$ROOT_DIR/Scripts/build_and_run.sh" --production --release --verify
else
  echo "Skipping production package verification because Sparkle key material is not configured."
  echo "Set SPARKLE_PUBLIC_ED_KEY, set SPARKLE_PRIVATE_KEY_FILE, or run CI_REQUIRE_PRODUCTION_VERIFY=1 ./ci.sh to require it."
fi
