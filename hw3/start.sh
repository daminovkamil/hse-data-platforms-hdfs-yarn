#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$root_dir/cluster.env"
if [[ ! "$MASTER_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Invalid MASTER_HOST: $MASTER_HOST" >&2
  exit 1
fi
hive_home="$HOME/apache-hive-4.2.1-bin"
if [[ ! -x "$hive_home/bin/hive" ]]; then
  echo "Run hw3/setup.sh first." >&2
  exit 1
fi

export HADOOP_HOME="$HOME/hadoop-3.4.1"
export HADOOP_CONF_DIR="$hive_home/conf/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export HIVE_HOME="$hive_home"
export HIVE_CONF_DIR="$hive_home/conf"
log_dir="$HOME/teachbase-hive-logs"
mkdir -p "$log_dir"
chmod 700 "$log_dir"

if ! timeout 1 bash -c 'echo > /dev/tcp/127.0.0.1/5432' 2>/dev/null; then
  echo "PostgreSQL is not listening on 127.0.0.1:5432." >&2
  exit 1
fi

if ! timeout 1 bash -c 'echo > /dev/tcp/$1/9083' _ "$MASTER_HOST" 2>/dev/null; then
  nohup "$hive_home/bin/hive" --service metastore > "$log_dir/metastore.log" 2>&1 &
  echo $! > "$log_dir/metastore.pid"
fi
for attempt in {1..60}; do
  if timeout 1 bash -c 'echo > /dev/tcp/$1/9083' _ "$MASTER_HOST" 2>/dev/null; then break; fi
  if ((attempt == 60)); then
    echo "Metastore failed to start. See $log_dir/metastore.log" >&2
    exit 1
  fi
  sleep 2
done

if ! timeout 1 bash -c 'echo > /dev/tcp/$1/10000' _ "$MASTER_HOST" 2>/dev/null; then
  nohup "$hive_home/bin/hiveserver2" > "$log_dir/hiveserver2.log" 2>&1 &
  echo $! > "$log_dir/hiveserver2.pid"
fi
for attempt in {1..90}; do
  if timeout 1 bash -c 'echo > /dev/tcp/$1/10000' _ "$MASTER_HOST" 2>/dev/null; then break; fi
  if ((attempt == 90)); then
    echo "HiveServer2 failed to start. See $log_dir/hiveserver2.log" >&2
    exit 1
  fi
  sleep 2
done
echo "Metastore: $MASTER_HOST:9083; HiveServer2: $MASTER_HOST:10000"
