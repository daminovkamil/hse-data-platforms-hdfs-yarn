#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root_dir/cluster.env"
export HADOOP_HOME="$HOME/hadoop-3.4.1"
export HADOOP_CONF_DIR="$HOME/apache-hive-4.2.1-bin/conf/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
beeline="$HOME/apache-hive-4.2.1-bin/bin/beeline"
url="jdbc:hive2://$MASTER_HOST:10000/default"

first_result=$(mktemp)
second_result=$(mktemp)
trap 'rm -f -- "$first_result" "$second_result"' EXIT
"$beeline" -u "$url" -n "$(id -un)" --silent=true --showHeader=false \
  --outputformat=tsv2 -e 'SELECT COUNT(*) FROM hse_hw.events' > "$first_result" &
first_pid=$!
"$beeline" -u "$url" -n "$(id -un)" --silent=true --showHeader=false \
  --outputformat=tsv2 -e 'SELECT COUNT(*) FROM hse_hw.events' > "$second_result" &
second_pid=$!
wait "$first_pid"
wait "$second_pid"
first_count=$(tr -d '[:space:]' < "$first_result")
second_count=$(tr -d '[:space:]' < "$second_result")
if [[ "$first_count" != 5 || "$second_count" != 5 ]]; then
  echo "Expected 5 rows from each client, got: $first_count and $second_count" >&2
  exit 1
fi
partitions=$("$beeline" -u "$url" -n "$(id -un)" --silent=true \
  --showHeader=false --outputformat=tsv2 -e 'SHOW PARTITIONS hse_hw.events')
for date in 2026-10-20 2026-10-21; do
  if ! printf '%s\n' "$partitions" | grep -Fxq "event_date=$date"; then
    echo "Missing Hive partition: event_date=$date" >&2
    exit 1
  fi
done
echo "Two concurrent Hive clients read 5 rows; both expected partitions exist."

export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
"$HADOOP_HOME/bin/hdfs" dfs -ls /user/hive/warehouse/hse_hw.db/events
echo "Connect from another VM with: beeline -u '$url'"
