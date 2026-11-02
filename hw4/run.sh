#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root_dir/cluster.env"
if [[ ! "$MASTER_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Invalid MASTER_HOST: $MASTER_HOST" >&2
  exit 1
fi

export HADOOP_HOME="$HOME/hadoop-3.4.1"
export HADOOP_CONF_DIR="$HADOOP_HOME/etc/hadoop"
export YARN_CONF_DIR="$HADOOP_CONF_DIR"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export PYSPARK_PYTHON=python3
spark_home="$HOME/spark-3.5.8-bin-hadoop3"
hive_home="$HOME/apache-hive-4.2.1-bin"
if [[ ! -x "$spark_home/bin/spark-submit" || ! -x "$hive_home/bin/beeline" ]]; then
  echo "Run hw3/setup.sh and hw4/setup.sh first." >&2
  exit 1
fi

"$HADOOP_HOME/bin/hdfs" dfs -test -e /data/hse/events_raw/events.csv || {
  echo "Input is missing; run bash hw3/load.sh first." >&2
  exit 1
}
"$HADOOP_HOME/bin/hdfs" dfs -mkdir -p "/user/$(id -un)"

"$spark_home/bin/spark-submit" \
  --master yarn --deploy-mode client \
  --conf "spark.driver.host=$MASTER_HOST" \
  --conf spark.driver.bindAddress=0.0.0.0 \
  --conf spark.driver.port=7078 \
  --conf spark.driver.blockManager.port=7079 \
  --conf spark.dynamicAllocation.enabled=false \
  --conf spark.yarn.appMasterEnv.JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
  --conf spark.executorEnv.JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
  --conf spark.executor.instances=2 \
  --conf spark.executor.cores=1 \
  --conf spark.executor.memory=512m \
  --conf spark.yarn.am.memory=512m \
  --conf spark.sql.shuffle.partitions=4 \
  "$root_dir/hw4/transform.py" \
  --input "hdfs://$MASTER_HOST:8020/data/hse/events_raw/events.csv" \
  --output "hdfs://$MASTER_HOST:8020/data/hse/events_daily_spark"

export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export HADOOP_CONF_DIR="$hive_home/conf/hadoop"
"$hive_home/bin/beeline" -u "jdbc:hive2://$MASTER_HOST:10000/default" \
  -n "$(id -un)" --showHeader=false -f "$root_dir/hw4/register.sql"
echo "Spark output is registered as hse_hw.events_daily_spark."
