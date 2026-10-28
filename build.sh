#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$repo_dir/target/classes"
javac --release 11 -encoding UTF-8 -classpath "$(hadoop classpath --glob)" -d "$repo_dir/target/classes" "$repo_dir/3构建倒排索引/InvertedIndex.java"
jar --create --file "$repo_dir/inverted-index.jar" -C "$repo_dir/target/classes" .
