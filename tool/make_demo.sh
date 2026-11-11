#!/usr/bin/env bash
# Draws docs/images/demo.gif, the README's animated demo, from the real app
# with scripted model replies. Needs ffmpeg. The template only: setup removes
# it with docs/.
set -euo pipefail
cd "$(dirname "$0")/.."
frames="$(mktemp -d)"
trap 'rm -rf "$frames"' EXIT
DEMO_FRAMES="$frames" flutter test tool/docs_screenshots_test.dart \
  --plain-name 'demo:'
ffmpeg -loglevel error -y -f concat -safe 0 -i "$frames/frames.txt" \
  -vf 'scale=960:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5' \
  -loop 0 docs/images/demo.gif
echo "Wrote docs/images/demo.gif ($(du -h docs/images/demo.gif | cut -f1))"
