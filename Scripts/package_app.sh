#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

EXPLICIT_APP_NAME=${APP_NAME:-}
EXPLICIT_PRODUCT_NAME=${PRODUCT_NAME:-}
EXPLICIT_BUNDLE_ID=${BUNDLE_ID:-}
EXPLICIT_SIGNING_MODE=${SIGNING_MODE:-}
EXPLICIT_APP_IDENTITY=${APP_IDENTITY:-}
EXPLICIT_ARCHES=${ARCHES:-}
EXPLICIT_SPARKLE_FEED_URL=${SPARKLE_FEED_URL:-}
EXPLICIT_SPARKLE_PRIVATE_KEY_FILE=${SPARKLE_PRIVATE_KEY_FILE:-}
EXPLICIT_SPARKLE_PUBLIC_ED_KEY=${SPARKLE_PUBLIC_ED_KEY:-}
EXPLICIT_ENABLE_SPARKLE_AUTOMATIC_CHECKS=${ENABLE_SPARKLE_AUTOMATIC_CHECKS:-}
EXPLICIT_ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN=${ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN:-}

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

CONFIGURATION=${CONFIGURATION:-release}
APP_VARIANT=${APP_VARIANT:-dev}

usage() {
  cat <<'USAGE'
Usage: Scripts/package_app.sh [debug|release] [--dev|--production]

Options:
  debug          Build a debug app bundle.
  release        Build a release app bundle. Default.
  --dev          Package Slashgrab Dev.app with com.prof18.slashgrab.dev. Default.
  --production   Package Slashgrab.app with com.prof18.slashgrab.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    debug|release) CONFIGURATION="$arg" ;;
    --dev) APP_VARIANT=dev ;;
    --production|--prod) APP_VARIANT=production ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown argument: $arg" >&2; usage; exit 2 ;;
  esac
done

PRODUCT_NAME=${EXPLICIT_PRODUCT_NAME:-${PRODUCT_NAME:-Slashgrab}}
case "$APP_VARIANT" in
  dev)
    DEFAULT_APP_NAME="Slashgrab Dev"
    DEFAULT_BUNDLE_ID="com.prof18.slashgrab.dev"
    DEFAULT_ENABLE_SPARKLE_AUTOMATIC_CHECKS=false
    ;;
  production)
    DEFAULT_APP_NAME="Slashgrab"
    DEFAULT_BUNDLE_ID="com.prof18.slashgrab"
    DEFAULT_ENABLE_SPARKLE_AUTOMATIC_CHECKS=true
    ;;
  *)
    echo "Unknown APP_VARIANT: $APP_VARIANT" >&2
    usage
    exit 2
    ;;
esac

APP_NAME=${EXPLICIT_APP_NAME:-$DEFAULT_APP_NAME}
BUNDLE_ID=${EXPLICIT_BUNDLE_ID:-$DEFAULT_BUNDLE_ID}
MACOS_MIN_VERSION=${MACOS_MIN_VERSION:-13.0}
SIGNING_MODE=${SIGNING_MODE:-adhoc}
APP_IDENTITY=${APP_IDENTITY:-}
SIGNING_MODE=${EXPLICIT_SIGNING_MODE:-${SIGNING_MODE:-adhoc}}
APP_IDENTITY=${EXPLICIT_APP_IDENTITY:-${APP_IDENTITY:-}}
SPARKLE_FEED_URL=${EXPLICIT_SPARKLE_FEED_URL:-${SPARKLE_FEED_URL:-"https://raw.githubusercontent.com/prof18/slashgrab/main/appcast.xml"}}
SPARKLE_PRIVATE_KEY_FILE=${EXPLICIT_SPARKLE_PRIVATE_KEY_FILE:-${SPARKLE_PRIVATE_KEY_FILE:-}}
SPARKLE_PUBLIC_ED_KEY=${EXPLICIT_SPARKLE_PUBLIC_ED_KEY:-${SPARKLE_PUBLIC_ED_KEY:-}}
ENABLE_SPARKLE_AUTOMATIC_CHECKS=${EXPLICIT_ENABLE_SPARKLE_AUTOMATIC_CHECKS:-${ENABLE_SPARKLE_AUTOMATIC_CHECKS:-$DEFAULT_ENABLE_SPARKLE_AUTOMATIC_CHECKS}}
ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN=${EXPLICIT_ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN:-${ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN:-0}}

derive_sparkle_public_key() {
  SPARKLE_PRIVATE_KEY_FILE="$SPARKLE_PRIVATE_KEY_FILE" swift -e 'import Foundation; import CryptoKit; let path = ProcessInfo.processInfo.environment["SPARKLE_PRIVATE_KEY_FILE"]!; let text = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines); let seed = Data(base64Encoded: text)!; let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed); print(privateKey.publicKey.rawRepresentation.base64EncodedString())'
}

if [[ "$APP_VARIANT" == "production" ]]; then
  if [[ -z "$SPARKLE_FEED_URL" ]]; then
    echo "ERROR: SPARKLE_FEED_URL is required for production packaging." >&2
    exit 1
  fi
  if [[ -z "$SPARKLE_PUBLIC_ED_KEY" && -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    SPARKLE_PUBLIC_ED_KEY="$(derive_sparkle_public_key)"
  fi
  if [[ -z "$SPARKLE_PUBLIC_ED_KEY" ]]; then
    if [[ "$ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN" == "1" && "$SIGNING_MODE" == "adhoc" ]]; then
      ENABLE_SPARKLE_AUTOMATIC_CHECKS=false
      echo "WARN: SPARKLE_PUBLIC_ED_KEY is missing; building local ad-hoc production app with Sparkle disabled." >&2
    else
      echo "ERROR: SPARKLE_PUBLIC_ED_KEY is required for production packaging." >&2
      exit 1
    fi
  fi
fi

if [[ -f "$ROOT_DIR/version.env" ]]; then
  source "$ROOT_DIR/version.env"
else
  MARKETING_VERSION=${MARKETING_VERSION:-0.1.0}
  BUILD_NUMBER=${BUILD_NUMBER:-1}
fi

APP_BUNDLE="$ROOT_DIR/${APP_NAME}.app"
EXECUTABLE_TARGET="$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
ARCH_LIST=( ${EXPLICIT_ARCHES:-${ARCHES:-}} )
if [[ "$APP_VARIANT" == "dev" && -d "$ROOT_DIR/Scripts/Assets/AppIconDev.icon" ]]; then
  APP_ICON_SOURCE_DIR="$ROOT_DIR/Scripts/Assets/AppIconDev.icon"
else
  APP_ICON_SOURCE_DIR="$ROOT_DIR/Sources/$PRODUCT_NAME/Resources/AppIcon.icon"
fi

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

  if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
    while IFS= read -r -d '' copied_executable; do
      copied_archs="$(/usr/bin/lipo -archs "$copied_executable" 2>/dev/null || true)"
      if [[ -z "$copied_archs" ]]; then
        continue
      fi

      has_all_requested_arches=1
      for arch in "${ARCH_LIST[@]}"; do
        if [[ " $copied_archs " != *" $arch "* ]]; then
          has_all_requested_arches=0
          break
        fi
      done

      if [[ "$has_all_requested_arches" == "1" ]]; then
        continue
      fi

      relative_path="${copied_executable#"$APP_BUNDLE/Contents/Frameworks/"}"
      framework_executables=()
      missing_arch_binary=0
      LIPO_SLICE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/slashgrab-framework-lipo.XXXXXX")"

      for arch in "${ARCH_LIST[@]}"; do
        arch_executable="$(build_dir_for_frameworks "$arch")/$relative_path"
        if [[ ! -f "$arch_executable" ]]; then
          missing_arch_binary=1
          break
        fi

        source_archs="$(/usr/bin/lipo -archs "$arch_executable" 2>/dev/null || true)"
        if [[ " $source_archs " != *" $arch "* ]]; then
          missing_arch_binary=1
          break
        fi

        if [[ "$source_archs" == "$arch" ]]; then
          framework_executables+=("$arch_executable")
        else
          slice_path="$LIPO_SLICE_DIR/${arch}-${relative_path//\//_}"
          /usr/bin/lipo "$arch_executable" -thin "$arch" -output "$slice_path"
          framework_executables+=("$slice_path")
        fi
      done

      if [[ "$missing_arch_binary" == "0" ]]; then
        /usr/bin/lipo -create "${framework_executables[@]}" -output "$copied_executable"
        chmod +x "$copied_executable"
      fi

      rm -rf "$LIPO_SLICE_DIR"
    done < <(find "$APP_BUNDLE/Contents/Frameworks" -type f -perm -111 -print0)
  fi
fi

if compgen -G "$BUILD_DIR/${PRODUCT_NAME}_${PRODUCT_NAME}.*" >/dev/null; then
  cp -R "$BUILD_DIR/${PRODUCT_NAME}_${PRODUCT_NAME}."* "$APP_BUNDLE/Contents/Resources/"
fi

if [[ -d "$APP_ICON_SOURCE_DIR" ]]; then
  ICON_BUILD_DIR="$ROOT_DIR/.build/app-icon-$CONFIGURATION"
  ICON_INPUT_DIR="$ROOT_DIR/.build/app-icon-input-$CONFIGURATION/AppIcon.icon"

  if ! xcrun --find actool >/dev/null 2>&1; then
    echo "ERROR: AppIcon.icon requires Xcode actool to generate app bundle icon resources." >&2
    exit 1
  fi

  rm -rf "$ICON_BUILD_DIR"
  rm -rf "$(dirname "$ICON_INPUT_DIR")"
  mkdir -p "$ICON_BUILD_DIR" "$(dirname "$ICON_INPUT_DIR")"
  cp -R "$APP_ICON_SOURCE_DIR" "$ICON_INPUT_DIR"

  xcrun actool "$ICON_INPUT_DIR" \
    --compile "$ICON_BUILD_DIR" \
    --platform macosx \
    --minimum-deployment-target "$MACOS_MIN_VERSION" \
    --target-device mac \
    --app-icon AppIcon \
    --include-all-app-icons \
    --output-partial-info-plist "$ICON_BUILD_DIR/AppIcon-partial.plist" \
    >/dev/null

  cp -R "$ICON_INPUT_DIR" "$APP_BUNDLE/Contents/Resources/AppIcon.icon"

  if [[ ! -f "$ICON_BUILD_DIR/Assets.car" || ! -f "$ICON_BUILD_DIR/AppIcon.icns" ]]; then
    echo "ERROR: actool did not generate expected AppIcon resources." >&2
    exit 1
  fi

  cp "$ICON_BUILD_DIR/Assets.car" "$APP_BUNDLE/Contents/Resources/Assets.car"
  cp "$ICON_BUILD_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

if [[ -f "$ROOT_DIR/Sources/$PRODUCT_NAME/Resources/AppIcon.icns" ]]; then
  cp "$ROOT_DIR/Sources/$PRODUCT_NAME/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

if [[ -f "$ROOT_DIR/Sources/$PRODUCT_NAME/Resources/Assets.car" ]]; then
  cp "$ROOT_DIR/Sources/$PRODUCT_NAME/Resources/Assets.car" "$APP_BUNDLE/Contents/Resources/Assets.car"
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
    <key>CFBundleIconName</key><string>AppIcon</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>${MACOS_MIN_VERSION}</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>Copyright © 2026 Marco Gomiero.</string>
    <key>BuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>GitCommit</key><string>${GIT_COMMIT}</string>
    <key>SlashgrabBuildVariant</key><string>${APP_VARIANT}</string>
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
