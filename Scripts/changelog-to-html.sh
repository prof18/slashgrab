#!/usr/bin/env bash
set -euo pipefail

VERSION=${1:-}
CHANGELOG_FILE=${2:-CHANGELOG.md}

if [[ -z "$VERSION" ]]; then
  echo "Usage: Scripts/changelog-to-html.sh <version> [CHANGELOG.md]" >&2
  exit 1
fi

if [[ ! -f "$CHANGELOG_FILE" ]]; then
  echo "Missing changelog: $CHANGELOG_FILE" >&2
  exit 1
fi

section="$(awk -v version="$VERSION" '
  BEGIN { found=0 }
  /^## / {
    if ($0 ~ "^##[[:space:]]+" version "([[:space:]]|$)") { found=1; next }
    if (found) { exit }
  }
  found { print }
' "$CHANGELOG_FILE")"

if [[ -z "$section" ]]; then
  cat <<HTML
<h2>Slashgrab $VERSION</h2>
<p>Latest Slashgrab update.</p>
<p><a href="https://github.com/prof18/slashgrab/blob/main/CHANGELOG.md">View full changelog</a></p>
HTML
  exit 0
fi

echo "<h2>Slashgrab $VERSION</h2>"
in_list=false
while IFS= read -r line; do
  if [[ "$line" =~ ^-\  ]]; then
    if [[ "$in_list" == false ]]; then
      echo "<ul>"
      in_list=true
    fi
    item="${line#- }"
    item="${item//&/&amp;}"
    item="${item//</&lt;}"
    item="${item//>/&gt;}"
    echo "<li>$item</li>"
  else
    if [[ "$in_list" == true ]]; then
      echo "</ul>"
      in_list=false
    fi
    if [[ -n "$line" ]]; then
      line="${line//&/&amp;}"
      line="${line//</&lt;}"
      line="${line//>/&gt;}"
      echo "<p>$line</p>"
    fi
  fi
done <<< "$section"

if [[ "$in_list" == true ]]; then
  echo "</ul>"
fi

echo '<p><a href="https://github.com/prof18/slashgrab/blob/main/CHANGELOG.md">View full changelog</a></p>'
