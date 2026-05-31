#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f "$ROOT_DIR/.env" ]]; then
  set -a
  source "$ROOT_DIR/.env"
  set +a
fi

ZIP=${1:?"Usage: Scripts/make_appcast.sh Slashgrab-<version>.zip"}
FEED_URL=${2:-${SPARKLE_FEED_URL:-"https://raw.githubusercontent.com/prof18/slashgrab/main/appcast.xml"}}
PRIVATE_KEY_FILE=${SPARKLE_PRIVATE_KEY_FILE:-}

if [[ ! -f "$ZIP" ]]; then
  echo "Zip not found: $ZIP" >&2
  exit 1
fi

ZIP_DIR="$(cd "$(dirname "$ZIP")" && pwd)"
ZIP_NAME="$(basename "$ZIP")"
ZIP_BASE="${ZIP_NAME%.zip}"
VERSION=${SPARKLE_RELEASE_VERSION:-}
if [[ -z "$VERSION" ]]; then
  if [[ "$ZIP_NAME" =~ ^Slashgrab-([0-9]+(\.[0-9]+){1,2}([-.][^.]*)?)\.zip$ ]]; then
    VERSION="${BASH_REMATCH[1]}"
  else
    echo "Could not infer version from $ZIP_NAME; set SPARKLE_RELEASE_VERSION." >&2
    exit 1
  fi
fi

if ! command -v generate_appcast >/dev/null; then
  echo "generate_appcast not found. Install Sparkle tools first." >&2
  exit 1
fi

NOTES_HTML="$ZIP_DIR/$ZIP_BASE.html"
WORK_DIR="$(mktemp -d /tmp/slashgrab-appcast.XXXXXX)"
KEEP_NOTES=${KEEP_SPARKLE_NOTES:-0}

cleanup() {
  rm -rf "$WORK_DIR"
  if [[ "$KEEP_NOTES" != "1" ]]; then
    rm -f "$NOTES_HTML"
  fi
}
trap cleanup EXIT

"$ROOT_DIR/Scripts/changelog-to-html.sh" "$VERSION" >"$NOTES_HTML"

cp "$ROOT_DIR/appcast.xml" "$WORK_DIR/appcast.xml"
cp "$ZIP" "$WORK_DIR/$ZIP_NAME"
cp "$NOTES_HTML" "$WORK_DIR/$ZIP_BASE.html"

DOWNLOAD_URL_PREFIX=${SPARKLE_DOWNLOAD_URL_PREFIX:-"https://github.com/prof18/slashgrab/releases/download/v${VERSION}/"}
APPCAST_CMD=(generate_appcast)
if [[ -n "$PRIVATE_KEY_FILE" ]]; then
  APPCAST_CMD+=(--ed-key-file "$PRIVATE_KEY_FILE")
fi

pushd "$WORK_DIR" >/dev/null
"${APPCAST_CMD[@]}" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --embed-release-notes \
  --link "$FEED_URL" \
  "$WORK_DIR"
popd >/dev/null

cp "$WORK_DIR/appcast.xml" "$ROOT_DIR/appcast.xml"
echo "Updated appcast.xml for $ZIP_NAME"
