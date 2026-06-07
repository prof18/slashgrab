#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

swift test -q
swift build -q

"$ROOT_DIR/Scripts/build_and_run.sh" --verify --test

has_sparkle_public_key() {
  [[ -n "${SPARKLE_PUBLIC_ED_KEY:-}" ]] && return 0
  [[ -f "$ROOT_DIR/.env" ]] && /usr/bin/grep -Eq '^SPARKLE_PUBLIC_ED_KEY=.+$' "$ROOT_DIR/.env"
}

if [[ "${CI_SKIP_PRODUCTION_VERIFY:-0}" == "1" ]]; then
  echo "Skipping production package verification because CI_SKIP_PRODUCTION_VERIFY=1."
elif has_sparkle_public_key || [[ "${CI_REQUIRE_PRODUCTION_VERIFY:-0}" == "1" ]]; then
  "$ROOT_DIR/Scripts/build_and_run.sh" --production --release --verify
else
  echo "Skipping production package verification because SPARKLE_PUBLIC_ED_KEY is not configured."
  echo "Set SPARKLE_PUBLIC_ED_KEY or run CI_REQUIRE_PRODUCTION_VERIFY=1 ./ci.sh to require it."
fi
