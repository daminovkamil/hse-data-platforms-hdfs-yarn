#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config_file="$root_dir/cluster.env"
if [[ ! -f "$config_file" ]]; then
  echo "Создайте cluster.env из cluster.env.example и впишите адреса VM." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$config_file"

for name in MASTER_HOST WORKER1_HOST WORKER2_HOST WORKER3_HOST; do
  host=${!name:-}
  if [[ ! "$host" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
    echo "Некорректный адрес в $name: $host" >&2
    exit 1
  fi
done

if [[ $(printf '%s\n' "$MASTER_HOST" "$WORKER1_HOST" "$WORKER2_HOST" "$WORKER3_HOST" | sort -u | wc -l) -ne 4 ]]; then
  echo "Все четыре адреса VM должны быть разными." >&2
  exit 1
fi

java_bin=$(command -v java || true)
if [[ -z "$java_bin" ]] || ! java -version 2>&1 | head -n 1 | grep -q 'version "11\.'; then
  echo "Нужна Java 11, установленная на этой VM." >&2
  exit 1
fi
java_home=$(dirname "$(dirname "$(readlink -f "$java_bin")")")

hadoop_home="$HOME/hadoop-3.4.1"
if [[ -e "$hadoop_home" && ! -f "$hadoop_home/.teachbase-managed" ]]; then
  echo "Папка $hadoop_home уже занята; её конфигурация не будет изменена." >&2
  exit 1
fi

if [[ ! -e "$hadoop_home" ]]; then
  temp_dir=$(mktemp -d)
  trap 'rm -rf -- "$temp_dir"' EXIT
  base_url=https://downloads.apache.org/hadoop/common/hadoop-3.4.1
  curl -fsSL "$base_url/hadoop-3.4.1-lean.tar.gz" -o "$temp_dir/hadoop.tar.gz"
  curl -fsSL "$base_url/hadoop-3.4.1-lean.tar.gz.sha512" -o "$temp_dir/hadoop.sha512"

  expected=$(grep -Eo '[[:xdigit:]]{128}' "$temp_dir/hadoop.sha512" | head -n 1)
  actual=$(sha512sum "$temp_dir/hadoop.tar.gz" | awk '{print $1}')
  if [[ -z "$expected" || "${expected,,}" != "$actual" ]]; then
    echo "Ошибка проверки SHA-512 архива Hadoop." >&2
    exit 1
  fi

  tar -xzf "$temp_dir/hadoop.tar.gz" -C "$HOME"
  touch "$hadoop_home/.teachbase-managed"
fi

if [[ ! -x "$hadoop_home/bin/hadoop" ]]; then
  echo "Установка Hadoop в $hadoop_home неполная." >&2
  exit 1
fi

data_dir="$HOME/teachbase-hadoop-data"
mkdir -p "$data_dir/nn" "$data_dir/snn" "$data_dir/dn" "$data_dir/tmp" \
  "$HOME/teachbase-hadoop-logs" "$HOME/teachbase-hadoop-pids"
chmod 700 "$data_dir" "$data_dir/nn" "$data_dir/snn" "$data_dir/dn" \
  "$data_dir/tmp" "$HOME/teachbase-hadoop-logs" "$HOME/teachbase-hadoop-pids"
conf_dir="$hadoop_home/etc/hadoop"

cat > "$conf_dir/hadoop-env.sh" <<EOF
export JAVA_HOME="$java_home"
export HADOOP_HOME="$hadoop_home"
export HADOOP_LOG_DIR="$HOME/teachbase-hadoop-logs"
export HADOOP_PID_DIR="$HOME/teachbase-hadoop-pids"
export HADOOP_HEAPSIZE_MAX=256m
EOF

cat > "$conf_dir/core-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>fs.defaultFS</name><value>hdfs://$MASTER_HOST:8020</value></property>
  <property><name>hadoop.tmp.dir</name><value>$data_dir/tmp</value></property>
</configuration>
EOF

cat > "$conf_dir/hdfs-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>dfs.replication</name><value>3</value></property>
  <property><name>dfs.namenode.name.dir</name><value>file://$data_dir/nn</value></property>
  <property><name>dfs.namenode.checkpoint.dir</name><value>file://$data_dir/snn</value></property>
  <property><name>dfs.datanode.data.dir</name><value>file://$data_dir/dn</value></property>
  <property><name>dfs.namenode.rpc-address</name><value>$MASTER_HOST:8020</value></property>
  <property><name>dfs.namenode.http-address</name><value>$MASTER_HOST:9870</value></property>
  <property><name>dfs.namenode.http-bind-host</name><value>0.0.0.0</value></property>
  <property><name>dfs.namenode.secondary.http-address</name><value>0.0.0.0:9868</value></property>
  <property><name>dfs.datanode.http.address</name><value>0.0.0.0:9864</value></property>
</configuration>
EOF

printf '%s\n' "$WORKER1_HOST" "$WORKER2_HOST" "$WORKER3_HOST" > "$conf_dir/workers"
echo "HDFS настроен на $(hostname). Следующий шаг: hw1/README.md"
