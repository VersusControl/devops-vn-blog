#!/usr/bin/env bash
# Render a PNG copy of every SVG used as a post or series cover.
#
# Facebook, LinkedIn, X, and Zalo do not show SVG files in link previews. When
# og:image is an SVG, Facebook falls back to another image on the page (the
# author avatar). _plugins/social_image.rb points og:image at the PNG that this
# script writes next to each SVG, for example cover.svg -> cover.png.
#
# Run it after adding or changing a cover, and commit the PNGs:
#
#   ./scripts/build-social-images.sh          # only missing or outdated PNGs
#   ./scripts/build-social-images.sh --force  # re-render every PNG
#
# Needs rsvg-convert (macOS: brew install librsvg; Debian/Ubuntu: apt install librsvg2-bin).
set -euo pipefail
cd "$(dirname "$0")/.."

WIDTH=1200
force=false
[[ "${1:-}" == "--force" ]] && force=true

command -v rsvg-convert >/dev/null || { echo "rsvg-convert not found" >&2; exit 1; }

# SVG paths from front matter: `image:` in articles and pages, `cover:` in series pages.
svgs=$(grep -hE '^(image|cover):[[:space:]]*"?/assets/[^"]+\.svg"?[[:space:]]*$' \
         _articles/*.md series/*.md ./*.md 2>/dev/null \
       | sed -E 's/^(image|cover):[[:space:]]*"?\/?//; s/"?[[:space:]]*$//' | sort -u)

rendered=0
missing=0
for svg in $svgs; do
  if [[ ! -f "$svg" ]]; then
    echo "missing: $svg" >&2
    missing=$((missing + 1))
    continue
  fi
  png="${svg%.svg}.png"
  if $force || [[ ! -f "$png" || "$svg" -nt "$png" ]]; then
    rsvg-convert -w "$WIDTH" -b white "$svg" -o "$png"
    echo "rendered: $png"
    rendered=$((rendered + 1))
  fi
done

echo "$rendered PNG(s) rendered, $(echo "$svgs" | grep -c .) cover SVG(s) checked."
[[ $missing -eq 0 ]]
