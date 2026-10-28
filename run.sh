#!/usr/bin/env bash
set -euo pipefail
repo_dir=$(cd "$(dirname "$0")" && pwd)
bash "$repo_dir/build.sh"
run_id="$(date +%Y%m%d-%H%M%S)-$$"
base="/user/$(id -un)/inverted-index/$run_id"
output_dir="$repo_dir/3构建倒排索引/输出"
mkdir -p "$output_dir"
hdfs dfs -mkdir -p "$base/input"
hdfs dfs -put "$repo_dir/corpus/"document*.txt "$base/input/"
hdfs dfs -put "$repo_dir/2建立停词表/stopwords.txt" "$base/stopwords.txt"
hadoop jar "$repo_dir/inverted-index.jar" InvertedIndex "$base/input" "$base/output" "$base/stopwords.txt" 2>&1 | tee "$output_dir/job-$run_id.log"
hdfs dfs -getmerge "$base/output/part-r-*" "$output_dir/index-$run_id.txt"
python3 "$repo_dir/3构建倒排索引/校验结果.py" "$repo_dir/corpus" "$repo_dir/2建立停词表/stopwords.txt" "$output_dir/index-$run_id.txt" | tee "$output_dir/verification-$run_id.json"
