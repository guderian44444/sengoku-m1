#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
# Layout only: preserve all generated pixels and alpha; no matte removal or painting.
for source in sources/*.png; do
  magick "$source" -filter Lanczos -resize 896x896 -background none -gravity center -extent 1024x1024 "$(basename "$source")"
done
