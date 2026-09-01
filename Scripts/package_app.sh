#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

EXPLICIT_APP_NAME=${APP_NAME:-}
EXPLICIT_BUNDLE_ID=${BUNDLE_ID:-}
EXPLICIT_SIGNING_MODE=${SIGNING_MODE:-}
EXPLICIT_APP_IDENTITY=${APP_IDENTITY:-}
EXPLICIT_APP_GROUP_ID=${APP_GROUP_ID:-}
EXPLICIT_DEV_APP_GROUP_ID=${DEV_APP_GROUP_ID:-}
EXPLICIT_TEAM_ID=${TEAM_ID:-}
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
  echo "Usage: Scripts/package_app.sh [debug|release] [--dev|--production]"
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

case "$CONFIGURATION" in
  debug) XCODE_CONFIGURATION=Debug ;;
  release) XCODE_CONFIGURATION=Release ;;
  *) echo "Unknown configuration: $CONFIGURATION" >&2; exit 2 ;;
esac

case "$APP_VARIANT" in
  dev)
    DEFAULT_APP_NAME="Slashgrab Dev"
    DEFAULT_BUNDLE_ID="com.prof18.slashgrab.dev"
    APP_ICON_NAME=AppIconDev
    DEFAULT_ENABLE_SPARKLE_AUTOMATIC_CHECKS=false
    ;;
  production)
    DEFAULT_APP_NAME="Slashgrab"
    DEFAULT_BUNDLE_ID="com.prof18.slashgrab"
    APP_ICON_NAME=AppIcon
    DEFAULT_ENABLE_SPARKLE_AUTOMATIC_CHECKS=true
    ;;
  *)
    echo "Unknown app variant: $APP_VARIANT" >&2
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

FINDER_EXTENSION_BUNDLE_ID="${BUNDLE_ID}.findersync"
FINDER_EXTENSION_DISPLAY_NAME="$APP_NAME Finder Extension"
MACOS_MIN_VERSION=${MACOS_MIN_VERSION:-13.0}
SIGNING_MODE=${EXPLICIT_SIGNING_MODE:-${SIGNING_MODE:-adhoc}}
APP_IDENTITY=${EXPLICIT_APP_IDENTITY:-${APP_IDENTITY:-}}
ARCHES_VALUE=${EXPLICIT_ARCHES:-${ARCHES:-}}
SPARKLE_FEED_URL=${EXPLICIT_SPARKLE_FEED_URL:-${SPARKLE_FEED_URL:-"https://raw.githubusercontent.com/prof18/slashgrab/main/appcast.xml"}}
SPARKLE_PRIVATE_KEY_FILE=${EXPLICIT_SPARKLE_PRIVATE_KEY_FILE:-${SPARKLE_PRIVATE_KEY_FILE:-}}
SPARKLE_PUBLIC_ED_KEY=${EXPLICIT_SPARKLE_PUBLIC_ED_KEY:-${SPARKLE_PUBLIC_ED_KEY:-}}
ENABLE_SPARKLE_AUTOMATIC_CHECKS=${EXPLICIT_ENABLE_SPARKLE_AUTOMATIC_CHECKS:-${ENABLE_SPARKLE_AUTOMATIC_CHECKS:-$DEFAULT_ENABLE_SPARKLE_AUTOMATIC_CHECKS}}
ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN=${EXPLICIT_ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN:-${ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN:-0}}

derive_signing_team_identifier() {
  (
    probe_dir=$(/usr/bin/mktemp -d "/tmp/slashgrab-signing-team.XXXXXX")
    trap '/bin/rm -rf "$probe_dir"' EXIT
    /bin/cp /usr/bin/true "$probe_dir/probe"
    /usr/bin/codesign --force --sign "$APP_IDENTITY" "$probe_dir/probe" >/dev/null 2>&1
    /usr/bin/codesign -d --verbose=4 "$probe_dir/probe" 2>&1 \
      | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}'
  )
}

if [[ "$SIGNING_MODE" == "adhoc" || -z "$APP_IDENTITY" ]]; then
  SIGNING_TEAM_ID=${EXPLICIT_TEAM_ID:-${TEAM_ID:-adhoc}}
else
  SIGNING_TEAM_ID=$(derive_signing_team_identifier)
  if [[ -z "$SIGNING_TEAM_ID" || "$SIGNING_TEAM_ID" == "not set" ]]; then
    echo "ERROR: Could not derive the team identifier from APP_IDENTITY." >&2
    exit 1
  fi
fi

if [[ "$APP_VARIANT" == "dev" ]]; then
  CONFIGURED_APP_GROUP_ID=${EXPLICIT_DEV_APP_GROUP_ID:-${DEV_APP_GROUP_ID:-}}
  APP_GROUP_VARIABLE=DEV_APP_GROUP_ID
else
  CONFIGURED_APP_GROUP_ID=${EXPLICIT_APP_GROUP_ID:-${APP_GROUP_ID:-}}
  APP_GROUP_VARIABLE=APP_GROUP_ID
fi
APP_GROUP_ID=${CONFIGURED_APP_GROUP_ID:-"$SIGNING_TEAM_ID.$BUNDLE_ID.shared"}

if [[ "$APP_GROUP_ID" == group.* ]]; then
  echo "ERROR: $APP_GROUP_VARIABLE cannot use a group.* identifier with profile-free manual signing." >&2
  echo "Use a team-prefixed identifier such as $SIGNING_TEAM_ID.$BUNDLE_ID.shared, or leave it unset to use that default." >&2
  exit 1
fi

if [[ "$SIGNING_MODE" != "adhoc" && -n "$APP_IDENTITY" &&
      "$APP_GROUP_ID" != "$SIGNING_TEAM_ID".* ]]; then
  echo "ERROR: $APP_GROUP_VARIABLE must start with the signing team identifier $SIGNING_TEAM_ID." >&2
  exit 1
fi

if [[ "$APP_VARIANT" == "dev" ]]; then
  ENABLE_SPARKLE_AUTOMATIC_CHECKS=false
  SPARKLE_FEED_URL=""
  SPARKLE_PRIVATE_KEY_FILE=""
  SPARKLE_PUBLIC_ED_KEY=""
fi

derive_sparkle_public_key() {
  SPARKLE_PRIVATE_KEY_FILE="$SPARKLE_PRIVATE_KEY_FILE" swift -e 'import Foundation; import CryptoKit; let path = ProcessInfo.processInfo.environment["SPARKLE_PRIVATE_KEY_FILE"]!; let text = try String(contentsOfFile: path, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines); let seed = Data(base64Encoded: text)!; let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed); print(privateKey.publicKey.rawRepresentation.base64EncodedString())'
}

if [[ "$APP_VARIANT" == "production" ]]; then
  if [[ -z "$SPARKLE_FEED_URL" ]]; then
    echo "ERROR: SPARKLE_FEED_URL is required for production packaging." >&2
    exit 1
  fi
  if [[ -z "$SPARKLE_PUBLIC_ED_KEY" && -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
    if [[ ! -f "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
      if [[ "$ALLOW_MISSING_SPARKLE_FOR_LOCAL_RUN" == "1" && "$SIGNING_MODE" == "adhoc" ]]; then
        echo "WARN: SPARKLE_PRIVATE_KEY_FILE does not exist; building local ad-hoc production app with Sparkle disabled: $SPARKLE_PRIVATE_KEY_FILE" >&2
        SPARKLE_PRIVATE_KEY_FILE=""
      else
        echo "ERROR: SPARKLE_PRIVATE_KEY_FILE does not exist: $SPARKLE_PRIVATE_KEY_FILE" >&2
        exit 1
      fi
    fi
    if [[ -n "$SPARKLE_PRIVATE_KEY_FILE" ]]; then
      SPARKLE_PUBLIC_ED_KEY="$(derive_sparkle_public_key)"
    fi
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

"$ROOT_DIR/Scripts/generate_project.sh"

DERIVED_DATA="$ROOT_DIR/.build/xcode-derived-${APP_VARIANT}-${CONFIGURATION}"
PACKAGE_CACHE="$ROOT_DIR/.build/xcode-packages"
CONFIGURATION_PRODUCTS="$DERIVED_DATA/Build/Products/$XCODE_CONFIGURATION"
BUILT_APP="$CONFIGURATION_PRODUCTS/$APP_NAME.app"
BUILD_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"

XCODEBUILD_ARGS=(
  -project "$ROOT_DIR/Slashgrab.xcodeproj"
  -scheme Slashgrab
  -configuration "$XCODE_CONFIGURATION"
  -derivedDataPath "$DERIVED_DATA"
  -clonedSourcePackagesDirPath "$PACKAGE_CACHE"
  -destination "generic/platform=macOS"
  CODE_SIGNING_ALLOWED=NO
  ENABLE_DEBUG_DYLIB=NO
  "APP_DISPLAY_NAME=$APP_NAME"
  "APP_BUNDLE_ID=$BUNDLE_ID"
  "APP_ICON_NAME=$APP_ICON_NAME"
  "APP_GROUP_ID=$APP_GROUP_ID"
  "FINDER_EXTENSION_BUNDLE_ID=$FINDER_EXTENSION_BUNDLE_ID"
  "FINDER_EXTENSION_DISPLAY_NAME=$FINDER_EXTENSION_DISPLAY_NAME"
  "MACOSX_DEPLOYMENT_TARGET=$MACOS_MIN_VERSION"
  "MARKETING_VERSION=$MARKETING_VERSION"
  "CURRENT_PROJECT_VERSION=$BUILD_NUMBER"
)

if [[ -n "$ARCHES_VALUE" ]]; then
  XCODEBUILD_ARGS+=("ARCHS=$ARCHES_VALUE" ONLY_ACTIVE_ARCH=NO)
fi

/bin/rm -rf "$CONFIGURATION_PRODUCTS"
xcodebuild "${XCODEBUILD_ARGS[@]}" build -quiet

APP_BUNDLE="$ROOT_DIR/$APP_NAME.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "ERROR: Missing built app at $BUILT_APP" >&2
  exit 1
fi

rm -rf "$APP_BUNDLE"
/usr/bin/ditto "$BUILT_APP" "$APP_BUNDLE"

if [[ "$CONFIGURATION" == "release" ]]; then
  UNEXPECTED_DEBUG_DYLIB="$(
    /usr/bin/find "$APP_BUNDLE" -type f \
      \( -name '__preview.dylib' -o -name '*.debug.dylib' \) \
      -print -quit
  )"
  if [[ -n "$UNEXPECTED_DEBUG_DYLIB" ]]; then
    echo "ERROR: Release package contains a preview/debug dylib: $UNEXPECTED_DEBUG_DYLIB" >&2
    exit 1
  fi
fi

APP_INFO="$APP_BUNDLE/Contents/Info.plist"
EXTENSION_BUNDLE="$APP_BUNDLE/Contents/PlugIns/SlashgrabFinderSync.appex"
EXTENSION_INFO="$EXTENSION_BUNDLE/Contents/Info.plist"
if [[ ! -f "$EXTENSION_INFO" ]]; then
  echo "ERROR: Finder Sync extension was not embedded at $EXTENSION_BUNDLE" >&2
  exit 1
fi

/usr/bin/plutil -insert BuildTimestamp -string "$BUILD_TIMESTAMP" "$APP_INFO"
/usr/bin/plutil -insert GitCommit -string "$GIT_COMMIT" "$APP_INFO"
/usr/bin/plutil -insert SlashgrabBuildVariant -string "$APP_VARIANT" "$APP_INFO"
/usr/bin/plutil -insert SUFeedURL -string "$SPARKLE_FEED_URL" "$APP_INFO"
/usr/bin/plutil -insert SUPublicEDKey -string "$SPARKLE_PUBLIC_ED_KEY" "$APP_INFO"
/usr/bin/plutil -insert SUEnableAutomaticChecks -bool "$ENABLE_SPARKLE_AUTOMATIC_CHECKS" "$APP_INFO"
/usr/bin/plutil -replace SlashgrabAppGroupIdentifier -string "$APP_GROUP_ID" "$APP_INFO"
/usr/bin/plutil -replace SlashgrabAppGroupIdentifier -string "$APP_GROUP_ID" "$EXTENSION_INFO"

/usr/bin/plutil -lint "$APP_INFO" "$EXTENSION_INFO" >/dev/null
/usr/bin/xattr -cr "$APP_BUNDLE"

ENTITLEMENTS_DIR="$ROOT_DIR/.build/entitlements/$APP_VARIANT-$CONFIGURATION"
APP_ENTITLEMENTS="$ENTITLEMENTS_DIR/Slashgrab.entitlements"
EXTENSION_ENTITLEMENTS="$ENTITLEMENTS_DIR/SlashgrabFinderSync.entitlements"
/bin/rm -rf "$ENTITLEMENTS_DIR"
/bin/mkdir -p "$ENTITLEMENTS_DIR"
/bin/cp "$ROOT_DIR/Config/Slashgrab.entitlements" "$APP_ENTITLEMENTS"
/bin/cp "$ROOT_DIR/Config/SlashgrabFinderSync.entitlements" "$EXTENSION_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP_ID" "$APP_ENTITLEMENTS"
/usr/libexec/PlistBuddy -c "Set :com.apple.security.application-groups:0 $APP_GROUP_ID" "$EXTENSION_ENTITLEMENTS"
/usr/bin/plutil -lint "$APP_ENTITLEMENTS" "$EXTENSION_ENTITLEMENTS" >/dev/null

if [[ "$SIGNING_MODE" == "adhoc" || -z "$APP_IDENTITY" ]]; then
  CODESIGN_ARGS=(--force --sign -)
else
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$APP_IDENTITY")
fi

if [[ -d "$APP_BUNDLE/Contents/Frameworks" ]]; then
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

/usr/bin/codesign "${CODESIGN_ARGS[@]}" \
  --entitlements "$EXTENSION_ENTITLEMENTS" \
  "$EXTENSION_BUNDLE"
/usr/bin/codesign "${CODESIGN_ARGS[@]}" \
  --entitlements "$APP_ENTITLEMENTS" \
  "$APP_BUNDLE"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE" >/dev/null
echo "Created $APP_BUNDLE"
echo "Shared settings App Group: $APP_GROUP_ID"
