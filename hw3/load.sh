#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root_dir/cluster.env"
export HADOOP_HOME="$HOME/hadoop-3.4.1"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
hive_home="$HOME/apache-hive-4.2.1-bin"

"$HADOOP_HOME/bin/hdfs" dfs -mkdir -p /data/hse/events_raw
"$HADOOP_HOME/bin/hdfs" dfs -put -f "$root_dir/hw3/events.csv" /data/hse/events_raw/events.csv
export HADOOP_CONF_DIR="$hive_home/conf/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
"$hive_home/bin/beeline" -u "jdbc:hive2://$MASTER_HOST:10000/default" -n "$(id -un)" \
  --showHeader=false -f "$root_dir/hw3/load.sql"
