#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
config_file="$root_dir/cluster.env"
if [[ ! -f "$config_file" ]]; then
  echo "Создайте cluster.env из cluster.env.example." >&2
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

hadoop_home="$HOME/hadoop-3.4.1"
if [[ ! -f "$hadoop_home/.teachbase-managed" ]]; then
  echo "Сначала выполните ДЗ №1 на этой VM." >&2
  exit 1
fi

total_mb=$(awk '/MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
container_mb=$((total_mb / 2))
if ((container_mb > 4096)); then container_mb=4096; fi
if ((container_mb < 512)); then
  echo "На VM недостаточно памяти для NodeManager: ${total_mb} МБ." >&2
  exit 1
fi
cpu_cores=$(nproc)

conf_dir="$hadoop_home/etc/hadoop"
cat > "$conf_dir/yarn-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>yarn.resourcemanager.hostname</name><value>$MASTER_HOST</value></property>
  <property><name>yarn.resourcemanager.webapp.address</name><value>$MASTER_HOST:8088</value></property>
  <property><name>yarn.resourcemanager.bind-host</name><value>0.0.0.0</value></property>
  <property><name>yarn.nodemanager.webapp.address</name><value>0.0.0.0:8042</value></property>
  <property><name>yarn.web-proxy.address</name><value>$MASTER_HOST:9099</value></property>
  <property><name>yarn.web-proxy.bind-host</name><value>0.0.0.0</value></property>
  <property><name>yarn.nodemanager.aux-services</name><value>mapreduce_shuffle</value></property>
  <property><name>yarn.nodemanager.resource.memory-mb</name><value>$container_mb</value></property>
  <property><name>yarn.nodemanager.resource.cpu-vcores</name><value>$cpu_cores</value></property>
  <property><name>yarn.scheduler.minimum-allocation-mb</name><value>256</value></property>
  <property><name>yarn.scheduler.maximum-allocation-mb</name><value>$container_mb</value></property>
  <property><name>yarn.log-aggregation-enable</name><value>true</value></property>
  <property><name>yarn.log.server.url</name><value>http://$MASTER_HOST:19888/jobhistory/logs</value></property>
  <property><name>yarn.nodemanager.env-whitelist</name><value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value></property>
</configuration>
EOF

cat > "$conf_dir/mapred-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>mapreduce.framework.name</name><value>yarn</value></property>
  <property><name>mapreduce.application.classpath</name><value>\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/*:\$HADOOP_MAPRED_HOME/share/hadoop/mapreduce/lib/*</value></property>
  <property><name>mapreduce.jobhistory.address</name><value>$MASTER_HOST:10020</value></property>
  <property><name>mapreduce.jobhistory.webapp.address</name><value>$MASTER_HOST:19888</value></property>
  <property><name>mapreduce.jobhistory.bind-host</name><value>0.0.0.0</value></property>
  <property><name>yarn.app.mapreduce.am.resource.memory-mb</name><value>512</value></property>
  <property><name>mapreduce.map.memory.mb</name><value>512</value></property>
  <property><name>mapreduce.reduce.memory.mb</name><value>512</value></property>
  <property><name>mapreduce.map.java.opts</name><value>-Xmx384m</value></property>
  <property><name>mapreduce.reduce.java.opts</name><value>-Xmx384m</value></property>
</configuration>
EOF

echo "YARN настроен на $(hostname). Следующий шаг: hw2/README.md"
