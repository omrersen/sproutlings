#!/bin/bash
set -eu
cd "$(dirname "$0")"
app="$(find . -maxdepth 1 -type d -name '*.app' -print -quit)"
[ -n "$app" ] || { echo "Sproutlings.app not found"; exit 1; }
open "$app"
