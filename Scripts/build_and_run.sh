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
Usage: Scripts/build_and_run.sh [--debug] [--release] [--dev] [--production] [--verify] [--test] [--logs] [--telemetry]

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
EXPLICIT_DEV_APP_GROUP_ID=${DEV_APP_GROUP_ID:-}

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

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

if [[ -z "$APP_NAME" || "$APP_NAME" == "." || "$APP_NAME" == ".." || "$APP_NAME" == */* ]]; then
  echo "ERROR: APP_NAME must be a non-empty file name without path components." >&2
  exit 1
fi

APP_BUNDLE="$ROOT_DIR/${APP_NAME}.app"
ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN=${ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN:-0}
DEV_APP_IDENTITY=${DEV_APP_IDENTITY:-}
DEV_INSTALL_DIR=${DEV_INSTALL_DIR:-"$HOME/Applications"}
PACKAGE_DEV_APP_GROUP_ID=${EXPLICIT_DEV_APP_GROUP_ID:-${DEV_APP_GROUP_ID:-}}

if [[ "$APP_VARIANT" == "production" && "$VERIFY_ONLY" != "1" && -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
  ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN=1
fi

if [[ "$RUN_TESTS" == "1" ]]; then
  "$ROOT_DIR/Scripts/test.sh"
fi

PACKAGE_SIGNING_MODE=${SIGNING_MODE:-adhoc}
PACKAGE_APP_IDENTITY=${APP_IDENTITY:-}

if [[ "$APP_VARIANT" == "dev" && "$VERIFY_ONLY" != "1" ]]; then
  if [[ -z "$DEV_APP_IDENTITY" ]]; then
    DEVELOPMENT_IDENTITIES="$(
      /usr/bin/security find-identity -p codesigning -v 2>/dev/null \
        | /usr/bin/awk -F'"' '/"Apple Development:/{print $2}'
    )"

    if [[ -n "${APPLE_ID:-}" ]]; then
      DEV_APP_IDENTITY="$(
        /usr/bin/printf '%s\n' "$DEVELOPMENT_IDENTITIES" \
          | /usr/bin/awk -v apple_id="$APPLE_ID" 'index($0, apple_id) {print; exit}'
      )"
    fi

    if [[ -z "$DEV_APP_IDENTITY" ]]; then
      DEVELOPMENT_IDENTITY_COUNT="$(
        /usr/bin/printf '%s\n' "$DEVELOPMENT_IDENTITIES" \
          | /usr/bin/awk 'NF { count += 1 } END { print count + 0 }'
      )"
      if [[ "$DEVELOPMENT_IDENTITY_COUNT" == "1" ]]; then
        DEV_APP_IDENTITY=$DEVELOPMENT_IDENTITIES
      fi
    fi
  fi

  if [[ -z "$DEV_APP_IDENTITY" ]]; then
    echo "ERROR: Running the Finder extension requires an Apple Development-signed app." >&2
    echo "Set DEV_APP_IDENTITY in .env when no identity matches APPLE_ID or several identities are installed." >&2
    if [[ -n "${DEVELOPMENT_IDENTITIES:-}" ]]; then
      echo "Available Apple Development identities:" >&2
      /usr/bin/printf '  %s\n' "$DEVELOPMENT_IDENTITIES" >&2
    fi
    exit 1
  fi

  PACKAGE_SIGNING_MODE=development
  PACKAGE_APP_IDENTITY=$DEV_APP_IDENTITY
fi

APP_NAME="$APP_NAME" \
BUNDLE_ID="$BUNDLE_ID" \
APP_VARIANT="$APP_VARIANT" \
SIGNING_MODE="$PACKAGE_SIGNING_MODE" \
APP_IDENTITY="$PACKAGE_APP_IDENTITY" \
DEV_APP_GROUP_ID="$PACKAGE_DEV_APP_GROUP_ID" \
ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN="$ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN" \
  "$ROOT_DIR/Scripts/package_app.sh" "$CONFIGURATION"

/usr/bin/plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null

EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/SlashgrabFinderSync.appex"
if [[ ! -d "$EXTENSION_BUNDLE" ]]; then
  echo "ERROR: Finder Sync extension is missing from $APP_BUNDLE" >&2
  exit 1
fi
/usr/bin/codesign --verify --strict --verbose=2 "$EXTENSION_BUNDLE" >/dev/null

if [[ "$VERIFY_ONLY" == "1" ]]; then
  echo "OK: verified $APP_BUNDLE"
  exit 0
fi

RUN_APP_BUNDLE=$APP_BUNDLE

if [[ "$APP_VARIANT" == "dev" ]]; then
  if [[ "$DEV_INSTALL_DIR" != /* ]]; then
    echo "ERROR: DEV_INSTALL_DIR must be an absolute, non-root directory." >&2
    exit 1
  fi

  /bin/mkdir -p "$DEV_INSTALL_DIR"
  if ! CANONICAL_DEV_INSTALL_DIR="$(cd "$DEV_INSTALL_DIR" && pwd -P)"; then
    echo "ERROR: Could not resolve DEV_INSTALL_DIR: $DEV_INSTALL_DIR" >&2
    exit 1
  fi
  if [[ "$CANONICAL_DEV_INSTALL_DIR" == "/" ]]; then
    echo "ERROR: DEV_INSTALL_DIR must resolve to a non-root directory." >&2
    exit 1
  fi

  DEV_INSTALL_DIR=$CANONICAL_DEV_INSTALL_DIR
  INSTALLED_APP_BUNDLE="$DEV_INSTALL_DIR/$APP_NAME.app"
  INSTALLED_EXTENSION_BUNDLE="$INSTALLED_APP_BUNDLE/Contents/PlugIns/SlashgrabFinderSync.appex"
  if [[ "$(/usr/bin/dirname "$INSTALLED_APP_BUNDLE")" != "$DEV_INSTALL_DIR" ]]; then
    echo "ERROR: Installed app must be a direct child of DEV_INSTALL_DIR." >&2
    exit 1
  fi

  /usr/bin/pkill -f "$APP_BUNDLE/Contents/MacOS/" 2>/dev/null || true
  /usr/bin/pkill -f "$INSTALLED_APP_BUNDLE/Contents/MacOS/" 2>/dev/null || true
  if [[ -d "$INSTALLED_EXTENSION_BUNDLE" ]]; then
    /usr/bin/pluginkit -r "$INSTALLED_EXTENSION_BUNDLE" 2>/dev/null || true
  fi
  /bin/rm -rf "$INSTALLED_APP_BUNDLE"
  /usr/bin/ditto "$APP_BUNDLE" "$INSTALLED_APP_BUNDLE"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$INSTALLED_APP_BUNDLE" >/dev/null

  /usr/bin/pluginkit -r "$EXTENSION_BUNDLE" 2>/dev/null || true
  /usr/bin/pluginkit -a "$INSTALLED_EXTENSION_BUNDLE"
  RUN_APP_BUNDLE=$INSTALLED_APP_BUNDLE
fi

/usr/bin/pkill -f "$RUN_APP_BUNDLE/Contents/MacOS/" 2>/dev/null || true
/usr/bin/open -n "$RUN_APP_BUNDLE"

for _ in {1..20}; do
  if /usr/bin/pgrep -f "$RUN_APP_BUNDLE/Contents/MacOS/$APP_NAME" >/dev/null 2>&1; then
    echo "OK: $APP_NAME is running from $RUN_APP_BUNDLE."
    if [[ "$SHOW_LOGS" == "1" ]]; then
      /usr/bin/log show --style compact --last 2m --predicate 'process == "Slashgrab"' || true
    fi
    exit 0
  fi
  sleep 0.25
done

echo "ERROR: $APP_NAME did not stay running." >&2
exit 1
