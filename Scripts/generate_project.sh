#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "ERROR: XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 1
fi

VERSION_FILE="$ROOT_DIR/version.env"
if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: Missing version source: $VERSION_FILE" >&2
  exit 1
fi

source "$VERSION_FILE"
if [[ -z "${MARKETING_VERSION:-}" || -z "${BUILD_NUMBER:-}" ]]; then
  echo "ERROR: version.env must define MARKETING_VERSION and BUILD_NUMBER." >&2
  exit 1
fi
export MARKETING_VERSION BUILD_NUMBER

xcodegen generate --spec "$ROOT_DIR/project.yml" --project "$ROOT_DIR"
