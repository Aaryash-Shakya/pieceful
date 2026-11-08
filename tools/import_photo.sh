#!/bin/bash
# Turns downloaded photos into collection pictures: a 2048 px long-edge WebP and a 256 px thumbnail each,
# at the same quality as tools/make_collection.gd, with metadata stripped. Prints "slug width height".
# Usage (from the project root): bash tools/import_photo.sh <source dir> <collection dir> <slug>...
# Each <slug> is read from <source dir>/<slug>.jpg.
set -e
src=$1
dir=$2
shift 2
mkdir -p "$dir/thumbs"
for slug in "$@"; do
	magick "$src/$slug.jpg" -auto-orient -strip -resize '2048x2048>' -quality 80 "$dir/$slug.webp"
	magick "$dir/$slug.webp" -resize 256x256 -quality 80 "$dir/thumbs/$slug.webp"
	echo "$slug $(magick identify -format '%w %h' "$dir/$slug.webp")"
done
