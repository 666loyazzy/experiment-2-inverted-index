#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
javac --release 11 -encoding UTF-8 -classpath "$(hadoop classpath --glob)" -d build src/InvertedIndex.java
jar --create --file inverted-index.jar -C build .
printf 'Built inverted-index.jar\n'
