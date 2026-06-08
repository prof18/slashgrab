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
BUNDLE_ID=${BUNDLE_ID:-com.prof18.slashgrab}
APP_IDENTITY=${APP_IDENTITY:?"Set APP_IDENTITY in .env, for example Developer ID Application: Name (TEAMID)"}
KEYCHAIN_PROFILE=${KEYCHAIN_PROFILE:-NOTARIZATION_PASSWORD}
ARCHES_VALUE=${ARCHES:-"arm64 x86_64"}
ZIP_NAME="${APP_NAME}-${MARKETING_VERSION}.zip"
NOTARIZE_ZIP="/tmp/${APP_NAME}-${MARKETING_VERSION}-notarize.zip"

cleanup() {
  rm -f "$NOTARIZE_ZIP"
}
trap cleanup EXIT

APP_NAME="$APP_NAME" \
PRODUCT_NAME="$PRODUCT_NAME" \
BUNDLE_ID="$BUNDLE_ID" \
APP_VARIANT=production \
SIGNING_MODE=developer-id \
APP_IDENTITY="$APP_IDENTITY" \
ENABLE_SPARKLE_AUTOMATIC_CHECKS=${ENABLE_SPARKLE_AUTOMATIC_CHECKS:-true} \
ARCHES="$ARCHES_VALUE" \
  "$ROOT_DIR/Scripts/package_app.sh" release --production

/usr/bin/ditto --norsrc -c -k --keepParent "$APP_NAME.app" "$NOTARIZE_ZIP"

/usr/bin/xcrun notarytool submit "$NOTARIZE_ZIP" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

/usr/bin/xcrun stapler staple "$APP_NAME.app"
/usr/bin/xattr -cr "$APP_NAME.app"
/usr/bin/find "$APP_NAME.app" -name '._*' -delete

/usr/bin/ditto --norsrc -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME"
/usr/sbin/spctl -a -t exec -vv "$APP_NAME.app"
/usr/bin/xcrun stapler validate "$APP_NAME.app"

echo "Done: $ZIP_NAME"
