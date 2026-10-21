#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
bash build.sh
run_id="$(date +%Y%m%d-%H%M%S)-$$"
base="/user/$(id -un)/inverted-index/$run_id"
mkdir -p results
hdfs dfs -mkdir -p "$base/input"
hdfs dfs -put corpus/document*.txt "$base/input/"
hdfs dfs -put stopwords.txt "$base/stopwords.txt"
hadoop jar inverted-index.jar InvertedIndex "$base/input" "$base/output" "$base/stopwords.txt" 2>&1 | tee "results/job-$run_id.log"
hdfs dfs -getmerge "$base/output/part-r-*" "results/index-$run_id.txt"
python3 verify.py corpus stopwords.txt "results/index-$run_id.txt" | tee "results/verification-$run_id.json"
printf 'HDFS result: %s/output\n' "$base"
printf 'Local result: results/index-%s.txt\n' "$run_id"
