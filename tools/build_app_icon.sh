#!/bin/bash
# Renders the Android launcher icons from the SVGs in assets/app_icon. Needs ImageMagick 7 with SVG support.
# Run from the project root: bash tools/build_app_icon.sh
set -e
dir=assets/app_icon
for layer in foreground background monochrome; do
  magick -background none "$dir/$layer.svg" -resize 432x432 "$dir/$layer.png"
done
# The legacy icon is the middle 72 of the 108 dp layers, the part a launcher mask shows.
magick "$dir/background.png" "$dir/foreground.png" -composite -gravity center -crop 288x288+0+0 +repage \
  -resize 192x192 "$dir/main_192.png"
