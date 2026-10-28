#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bash 编译.sh
repo_dir=$(cd .. && pwd)
run_id="$(date +%Y%m%d-%H%M%S)-$$"
base="/user/$(id -un)/inverted-index/$run_id"
mkdir -p 输出
hdfs dfs -mkdir -p "$base/input"
hdfs dfs -put "$repo_dir/1下载英文文档/英文文档/"document*.txt "$base/input/"
hdfs dfs -put "$repo_dir/2建立停词表/stopwords.txt" "$base/stopwords.txt"
hadoop jar "$repo_dir/target/lab2.jar" InvertedIndex "$base/input" "$base/output" "$base/stopwords.txt" 2>&1 | tee "输出/job-$run_id.log"
hdfs dfs -getmerge "$base/output/part-r-*" "输出/index-$run_id.txt"
python3 校验结果.py "$repo_dir/1下载英文文档/英文文档" "$repo_dir/2建立停词表/stopwords.txt" "输出/index-$run_id.txt" | tee "输出/verification-$run_id.json"
