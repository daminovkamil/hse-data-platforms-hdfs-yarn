#!/usr/bin/env bash
set -euo pipefail

hadoop_home="$HOME/hadoop-3.4.1"
test_dir="/user/$(id -un)/teachbase-smoke/$(date +%Y%m%d-%H%M%S)-$$"

"$hadoop_home/bin/hdfs" dfs -mkdir -p "$test_dir/input"
printf 'hadoop yarn\nhadoop hdfs\n' | \
  "$hadoop_home/bin/hdfs" dfs -put - "$test_dir/input/words.txt"

"$hadoop_home/bin/hadoop" jar \
  "$hadoop_home/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.1.jar" \
  wordcount "$test_dir/input" "$test_dir/output"

result=$("$hadoop_home/bin/hdfs" dfs -cat "$test_dir/output/part-r-00000")
printf '%s\n' "$result"
expected=$'hadoop\t2\nhdfs\t1\nyarn\t1'
if [[ "$result" != "$expected" ]]; then
  echo "WordCount вернул результат, отличный от ожидаемого." >&2
  exit 1
fi
echo "Тестовые данные оставлены в HDFS: $test_dir"
