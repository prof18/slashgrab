#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

source "$ROOT_DIR/version.env"

PRODUCT_NAME=${PRODUCT_NAME:-Slashgrab}
APP_NAME=${APP_NAME:-Slashgrab}
APP_BUNDLE=${APP_BUNDLE:-"$ROOT_DIR/${APP_NAME}.app"}
APP_IDENTITY=${APP_IDENTITY:-}
KEYCHAIN_PROFILE=${KEYCHAIN_PROFILE:-NOTARIZATION_PASSWORD}
DMG_NAME=${DMG_NAME:-"${APP_NAME}.dmg"}
VOLUME_NAME=${VOLUME_NAME:-"$APP_NAME"}
NOTARIZE_DMG=0

usage() {
  cat <<'USAGE'
Usage: Scripts/make_dmg.sh [--notarize]

Options:
  --notarize   Submit the DMG to Apple notarization and staple the ticket.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --notarize) NOTARIZE_DMG=1 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 2 ;;
  esac
done

if [[ ! -d "$APP_BUNDLE" ]]; then
  echo "App bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_BUNDLE/Contents/Info.plist")"
if [[ "$APP_VERSION" != "$MARKETING_VERSION" ]]; then
  echo "App version $APP_VERSION does not match version.env $MARKETING_VERSION." >&2
  exit 1
fi

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
/usr/bin/xcrun stapler validate "$APP_BUNDLE" >/dev/null

STAGING_DIR="$ROOT_DIR/.build/dmg/${APP_NAME}-${MARKETING_VERSION}"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

/usr/bin/ditto "$APP_BUNDLE" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_NAME"
/usr/bin/hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_NAME" \
  >/dev/null

if [[ -n "$APP_IDENTITY" ]]; then
  /usr/bin/codesign --force --timestamp --sign "$APP_IDENTITY" "$DMG_NAME"
fi

/usr/bin/hdiutil verify "$DMG_NAME" >/dev/null

if [[ "$NOTARIZE_DMG" == "1" ]]; then
  /usr/bin/xcrun notarytool submit "$DMG_NAME" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait
  /usr/bin/xcrun stapler staple "$DMG_NAME"
  /usr/bin/xcrun stapler validate "$DMG_NAME"
  /usr/sbin/spctl -a -t open --context context:primary-signature -vv "$DMG_NAME"
fi

echo "Done: $DMG_NAME"
