#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT_DIR/.build/module-cache"

source "$ROOT_DIR/version.env"
"$ROOT_DIR/Scripts/generate_project.sh"

CHANGELOG_HTML="$("$ROOT_DIR/Scripts/changelog-to-html.sh" "$MARKETING_VERSION")"
if [[ "$CHANGELOG_HTML" == *'**'* ]]; then
  echo "ERROR: Generated changelog HTML contains unrendered bold Markdown." >&2
  exit 1
fi

swift test -q

xcodebuild \
  -project "$ROOT_DIR/Slashgrab.xcodeproj" \
  -scheme Slashgrab \
  -configuration Debug \
  -derivedDataPath "$ROOT_DIR/.build/xcode-derived-tests" \
  -clonedSourcePackagesDirPath "$ROOT_DIR/.build/xcode-packages" \
  -destination "platform=macOS,arch=$(uname -m)" \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_DEBUG_DYLIB=NO \
  APP_DISPLAY_NAME="Slashgrab Dev" \
  APP_BUNDLE_ID=com.prof18.slashgrab.dev \
  APP_ICON_NAME=AppIconDev \
  FINDER_EXTENSION_BUNDLE_ID=com.prof18.slashgrab.dev.findersync \
  FINDER_EXTENSION_DISPLAY_NAME="Slashgrab Dev Finder Extension" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  test \
  -quiet
