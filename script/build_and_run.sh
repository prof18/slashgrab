#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

CONFIGURATION="debug"
APP_VARIANT="dev"
VERIFY_ONLY=0
RUN_TESTS=0
SHOW_LOGS=0

usage() {
  cat <<'USAGE'
Usage: script/build_and_run.sh [--debug] [--release] [--dev] [--production] [--verify] [--test] [--logs] [--telemetry]

Options:
  --debug       Build a debug app bundle. Default.
  --release     Build a release app bundle.
  --dev         Run Slashgrab Dev.app with com.prof18.slashgrab.dev. Default.
  --production  Run Slashgrab.app with com.prof18.slashgrab.
  --verify      Build and validate the app bundle without launching it.
  --test        Run unit tests before packaging.
  --logs        Tail recent Slashgrab log lines after launch.
  --telemetry   Reserved for future telemetry smoke checks.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --debug) CONFIGURATION="debug" ;;
    --release) CONFIGURATION="release" ;;
    --dev) APP_VARIANT="dev" ;;
    --production|--prod) APP_VARIANT="production" ;;
    --verify) VERIFY_ONLY=1 ;;
    --test) RUN_TESTS=1 ;;
    --logs) SHOW_LOGS=1 ;;
    --telemetry) ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 2 ;;
  esac
done

EXPLICIT_APP_NAME=${APP_NAME:-}
EXPLICIT_BUNDLE_ID=${BUNDLE_ID:-}

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

PRODUCT_NAME=${PRODUCT_NAME:-Slashgrab}
case "$APP_VARIANT" in
  dev)
    DEFAULT_APP_NAME="Slashgrab Dev"
    DEFAULT_BUNDLE_ID="com.prof18.slashgrab.dev"
    ;;
  production)
    DEFAULT_APP_NAME="Slashgrab"
    DEFAULT_BUNDLE_ID="com.prof18.slashgrab"
    ;;
  *)
    echo "Unknown APP_VARIANT: $APP_VARIANT" >&2
    usage
    exit 2
    ;;
esac

APP_NAME=${EXPLICIT_APP_NAME:-$DEFAULT_APP_NAME}
BUNDLE_ID=${EXPLICIT_BUNDLE_ID:-$DEFAULT_BUNDLE_ID}
APP_BUNDLE="$ROOT_DIR/${APP_NAME}.app"

if [[ "$RUN_TESTS" == "1" ]]; then
  swift test --disable-sandbox -q
fi

APP_NAME="$APP_NAME" \
BUNDLE_ID="$BUNDLE_ID" \
APP_VARIANT="$APP_VARIANT" \
  "$ROOT_DIR/Scripts/package_app.sh" "$CONFIGURATION"

/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/bin/codesign --verify --verbose=2 "$APP_BUNDLE" >/dev/null

if [[ "$VERIFY_ONLY" == "1" ]]; then
  echo "OK: verified $APP_BUNDLE"
  exit 0
fi

/usr/bin/pkill -f "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME" 2>/dev/null || true
/usr/bin/open -n "$APP_BUNDLE"

for _ in {1..20}; do
  if /usr/bin/pgrep -f "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME" >/dev/null 2>&1; then
    echo "OK: $APP_NAME is running."
    if [[ "$SHOW_LOGS" == "1" ]]; then
      /usr/bin/log show --style compact --last 2m --predicate 'process == "Slashgrab"' || true
    fi
    exit 0
  fi
  sleep 0.25
done

echo "ERROR: $APP_NAME did not stay running." >&2
exit 1
