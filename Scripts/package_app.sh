#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION=${1:-release}
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

PRODUCT_NAME=${PRODUCT_NAME:-Slashgrab}
APP_NAME=${APP_NAME:-"Slashgrab Dev"}
BUNDLE_ID=${BUNDLE_ID:-com.prof18.slashgrab.dev}
MACOS_MIN_VERSION=${MACOS_MIN_VERSION:-13.0}
SIGNING_MODE=${SIGNING_MODE:-adhoc}
APP_IDENTITY=${APP_IDENTITY:-}
SPARKLE_FEED_URL=${SPARKLE_FEED_URL:-}
SPARKLE_PUBLIC_ED_KEY=${SPARKLE_PUBLIC_ED_KEY:-}
ENABLE_SPARKLE_AUTOMATIC_CHECKS=${ENABLE_SPARKLE_AUTOMATIC_CHECKS:-false}

if [[ -f "$ROOT_DIR/version.env" ]]; then
  source "$ROOT_DIR/version.env"
else
  MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}
  BUILD_NUMBER=${BUILD_NUMBER:-1}
fi

APP_BUNDLE="$ROOT_DIR/${APP_NAME}.app"
EXECUTABLE_TARGET="$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
ARCH_LIST=( ${ARCHES:-} )

build_product_path() {
  local arch="${1:-}"
  if [[ -z "$arch" ]]; then
    echo "$ROOT_DIR/.build/$CONFIGURATION/$PRODUCT_NAME"
  else
    echo "$ROOT_DIR/.build/${arch}-apple-macosx/$CONFIGURATION/$PRODUCT_NAME"
  fi
}

build_dir_for_frameworks() {
  local arch="${1:-}"
  if [[ -z "$arch" ]]; then
    echo "$ROOT_DIR/.build/$CONFIGURATION"
  else
    echo "$ROOT_DIR/.build/${arch}-apple-macosx/$CONFIGURATION"
  fi
}

if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  swift build --disable-sandbox -c "$CONFIGURATION" -q
else
  for arch in "${ARCH_LIST[@]}"; do
    swift build --disable-sandbox -c "$CONFIGURATION" --arch "$arch" -q
  done
fi

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources" "$APP_BUNDLE/Contents/Frameworks"

if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  EXECUTABLE_SOURCE="$(build_product_path)"
  if [[ ! -f "$EXECUTABLE_SOURCE" ]]; then
    echo "ERROR: Missing built product at $EXECUTABLE_SOURCE" >&2
    exit 1
  fi
  cp "$EXECUTABLE_SOURCE" "$EXECUTABLE_TARGET"
else
  EXECUTABLES=()
  for arch in "${ARCH_LIST[@]}"; do
    EXECUTABLE_SOURCE="$(build_product_path "$arch")"
    if [[ ! -f "$EXECUTABLE_SOURCE" ]]; then
      echo "ERROR: Missing $arch built product at $EXECUTABLE_SOURCE" >&2
      exit 1
    fi
    EXECUTABLES+=("$EXECUTABLE_SOURCE")
  done
  /usr/bin/lipo -create "${EXECUTABLES[@]}" -output "$EXECUTABLE_TARGET"
fi
chmod +x "$EXECUTABLE_TARGET"

FRAMEWORK_ARCH="${ARCH_LIST[0]:-}"
BUILD_DIR="$(build_dir_for_frameworks "$FRAMEWORK_ARCH")"
if compgen -G "$BUILD_DIR/*.framework" >/dev/null; then
  cp -R "$BUILD_DIR/"*.framework "$APP_BUNDLE/Contents/Frameworks/"
  chmod -R a+rX "$APP_BUNDLE/Contents/Frameworks"
  /usr/bin/install_name_tool -add_rpath "@executable_path/../Frameworks" "$EXECUTABLE_TARGET" || true
fi

BUILD_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>${PRODUCT_NAME}</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Prof18.</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
    <key>SUFeedURL</key><string>${SPARKLE_FEED_URL}</string>
    <key>SUPublicEDKey</key><string>${SPARKLE_PUBLIC_ED_KEY}</string>
    <key>SUEnableAutomaticChecks</key><${ENABLE_SPARKLE_AUTOMATIC_CHECKS}/>
</dict>
</plist>
PLIST

xattr -cr "$APP_BUNDLE"

if [[ "$SIGNING_MODE" == "adhoc" || -z "$APP_IDENTITY" ]]; then
  CODESIGN_ARGS=(--force --sign -)
else
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
fi

if compgen -G "$APP_BUNDLE/Contents/Frameworks/*.framework" >/dev/null; then
  while IFS= read -r -d '' executable; do
    /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$executable"
  done < <(find "$APP_BUNDLE/Contents/Frameworks" -type f -perm -111 -print0)

  while IFS= read -r -d '' nested_bundle; do
    /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$nested_bundle"
  done < <(find "$APP_BUNDLE/Contents/Frameworks" \( -name "*.xpc" -o -name "*.app" \) -type d -print0)

  while IFS= read -r -d '' framework; do
    /usr/bin/codesign "${CODESIGN_ARGS[@]}" "$framework"
  done < <(find "$APP_BUNDLE/Contents/Frameworks" -name "*.framework" -type d -print0)
fi

/usr/bin/codesign "${CODESIGN_ARGS[@]}" "$APP_BUNDLE"

/usr/bin/codesign --verify --verbose=2 "$APP_BUNDLE" >/dev/null
echo "Created $APP_BUNDLE"
