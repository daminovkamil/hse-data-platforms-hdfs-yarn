#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root_dir/cluster.env"
export HADOOP_HOME="$HOME/hadoop-3.4.1"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
beeline="$HOME/apache-hive-4.2.1-bin/bin/beeline"
url="jdbc:hive2://$MASTER_HOST:10000/default"

"$HADOOP_HOME/bin/hdfs" dfs -ls /data/hse/events_daily_spark
export HADOOP_CONF_DIR="$HOME/apache-hive-4.2.1-bin/conf/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
partitions=$("$beeline" -u "$url" -n "$(id -un)" --silent=true \
  --showHeader=false --outputformat=tsv2 -e 'SHOW PARTITIONS hse_hw.events_daily_spark')
for date in 2026-10-20 2026-10-21; do
  if ! printf '%s\n' "$partitions" | grep -Fxq "event_date=$date"; then
    echo "Missing Spark partition in Hive: event_date=$date" >&2
    exit 1
  fi
done
totals=$("$beeline" -u "$url" -n "$(id -un)" --silent=true --showHeader=false \
  --outputformat=tsv2 -e 'SELECT COUNT(*), SUM(event_count) FROM hse_hw.events_daily_spark')
IFS=$'\t' read -r groups events <<< "$totals"
if [[ "$groups" != 3 || "$events" != 5 ]]; then
  echo "Expected 3 groups and 5 source events, got: $totals" >&2
  exit 1
fi
matching_rows=$("$beeline" -u "$url" -n "$(id -un)" --silent=true \
  --showHeader=false --outputformat=tsv2 -e "
  SELECT COUNT(*) FROM hse_hw.events_daily_spark
  WHERE (event_date = '2026-10-20' AND event_type = 'purchase' AND event_count = 1 AND total_amount = 120.5)
     OR (event_date = '2026-10-20' AND event_type = 'view'     AND event_count = 2 AND total_amount = 0.0)
     OR (event_date = '2026-10-21' AND event_type = 'purchase' AND event_count = 2 AND total_amount = 120.25)")
if [[ "$matching_rows" != 3 ]]; then
  echo "Expected all 3 Hive rows to match the sample data, got: $matching_rows" >&2
  exit 1
fi
"$beeline" -u "$url" -n "$(id -un)" --showHeader=false --outputformat=tsv2 \
  -e 'SELECT event_date, event_type, event_count, total_amount FROM hse_hw.events_daily_spark ORDER BY event_date, event_type'
echo "Hive read 3 Spark groups and 5 source events."
