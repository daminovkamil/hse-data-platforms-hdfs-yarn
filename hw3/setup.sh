#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
if [[ ! -f "$root_dir/cluster.env" ]]; then
  echo "Create cluster.env from cluster.env.example first." >&2
  exit 1
fi
source "$root_dir/cluster.env"

if [[ ! "$MASTER_HOST" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]]; then
  echo "Invalid MASTER_HOST: $MASTER_HOST" >&2
  exit 1
fi

hadoop_home="$HOME/hadoop-3.4.1"
hive_home="$HOME/apache-hive-4.2.1-bin"
if [[ ! -f "$hadoop_home/.teachbase-managed" ]]; then
  echo "Run hw1/setup.sh on the master VM first." >&2
  exit 1
fi
if [[ -e "$hive_home" && ! -f "$hive_home/.hse-homework-managed" ]]; then
  echo "Existing Hive directory is not managed by this homework: $hive_home" >&2
  exit 1
fi

sudo apt-get update
sudo apt-get install -y openjdk-21-jdk-headless postgresql libpostgresql-jdbc-java curl
sudo systemctl enable --now postgresql

if [[ ! -d "$hive_home" ]]; then
  temp_dir=$(mktemp -d)
  trap 'rm -rf -- "$temp_dir"' EXIT
  archive=apache-hive-4.2.1-bin.tar.gz
  base_url=https://archive.apache.org/dist/hive/hive-4.2.1
  curl -fsSL "$base_url/$archive" -o "$temp_dir/$archive"
  curl -fsSL "$base_url/$archive.sha256" -o "$temp_dir/$archive.sha256"
  expected=$(grep -Eo '[[:xdigit:]]{64}' "$temp_dir/$archive.sha256" | head -n 1)
  actual=$(sha256sum "$temp_dir/$archive" | awk '{print $1}')
  if [[ -z "$expected" || "${expected,,}" != "$actual" ]]; then
    echo "Hive archive SHA-256 verification failed." >&2
    exit 1
  fi
  tar -xzf "$temp_dir/$archive" -C "$temp_dir"
  mv "$temp_dir/apache-hive-4.2.1-bin" "$hive_home"
  touch "$hive_home/.hse-homework-managed"
fi

if [[ ! -x "$hive_home/bin/schematool" ]]; then
  echo "Hive installation is incomplete: $hive_home" >&2
  exit 1
fi

ln -sfn /usr/share/java/postgresql.jar "$hive_home/lib/postgresql.jar"
password_file="$root_dir/hw3/metastore.password"
if [[ ! -f "$password_file" ]]; then
  umask 077
  openssl rand -hex 24 > "$password_file"
fi
chmod 600 "$password_file"
db_password=$(<"$password_file")
if [[ ! "$db_password" =~ ^[[:xdigit:]]{48}$ ]]; then
  echo "Invalid password file: $password_file" >&2
  exit 1
fi

sudo -u postgres psql -v ON_ERROR_STOP=1 -v "db_password=$db_password" -d postgres <<'SQL'
SELECT format('CREATE ROLE hse_hive LOGIN PASSWORD %L', :'db_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hse_hive') \gexec
ALTER ROLE hse_hive PASSWORD :'db_password';
SELECT 'CREATE DATABASE hse_hive_metastore OWNER hse_hive'
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'hse_hive_metastore') \gexec
SQL
db_owner=$(sudo -u postgres psql -d postgres -tAc "SELECT pg_get_userbyid(datdba) FROM pg_database WHERE datname = 'hse_hive_metastore'")
if [[ "$db_owner" != hse_hive ]]; then
  echo "Metastore database has unexpected owner: $db_owner" >&2
  exit 1
fi

export HADOOP_HOME="$hadoop_home"
export HADOOP_CONF_DIR="$hadoop_home/etc/hadoop"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export HIVE_HOME="$hive_home"
export HIVE_CONF_DIR="$hive_home/conf"

"$hadoop_home/bin/hdfs" dfs -mkdir -p /tmp/hive /user/hive/warehouse /data/hse/events_raw
"$hadoop_home/bin/hdfs" dfs -chmod 1777 /tmp/hive

hive_hadoop_conf="$HIVE_CONF_DIR/hadoop"
mkdir -p "$hive_hadoop_conf"
for config in core-site.xml hdfs-site.xml yarn-site.xml mapred-site.xml; do
  cp "$hadoop_home/etc/hadoop/$config" "$hive_hadoop_conf/$config"
done
cat > "$hive_hadoop_conf/hadoop-env.sh" <<EOF
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export HADOOP_HOME="$hadoop_home"
export HADOOP_LOG_DIR="$HOME/teachbase-hive-logs"
EOF
export HADOOP_CONF_DIR="$hive_hadoop_conf"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

cat > "$HIVE_CONF_DIR/hive-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>hive.metastore.uris</name><value>thrift://$MASTER_HOST:9083</value></property>
  <property><name>hive.metastore.warehouse.dir</name><value>hdfs://$MASTER_HOST:8020/user/hive/warehouse</value></property>
  <property><name>hive.execution.engine</name><value>mr</value></property>
  <property><name>yarn.app.mapreduce.am.env</name><value>JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64</value></property>
  <property><name>mapreduce.map.env</name><value>JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64</value></property>
  <property><name>mapreduce.reduce.env</name><value>JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64</value></property>
  <property><name>hive.server2.thrift.bind.host</name><value>$MASTER_HOST</value></property>
  <property><name>hive.server2.thrift.port</name><value>10000</value></property>
  <property><name>hive.server2.authentication</name><value>NONE</value></property>
  <property><name>hive.server2.enable.doAs</name><value>false</value></property>
</configuration>
EOF

cat > "$HIVE_CONF_DIR/hivemetastore-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
  <property><name>javax.jdo.option.ConnectionURL</name><value>jdbc:postgresql://127.0.0.1:5432/hse_hive_metastore</value></property>
  <property><name>javax.jdo.option.ConnectionDriverName</name><value>org.postgresql.Driver</value></property>
  <property><name>javax.jdo.option.ConnectionUserName</name><value>hse_hive</value></property>
  <property><name>javax.jdo.option.ConnectionPassword</name><value>$db_password</value></property>
  <property><name>metastore.thrift.bind.host</name><value>$MASTER_HOST</value></property>
  <property><name>metastore.thrift.port</name><value>9083</value></property>
  <property><name>metastore.event.db.notification.api.auth</name><value>false</value></property>
</configuration>
EOF
chmod 600 "$HIVE_CONF_DIR/hivemetastore-site.xml"

if [[ $(sudo -u postgres psql -d hse_hive_metastore -tAc 'SELECT to_regclass('\''public."VERSION"'\'') IS NOT NULL') != t ]]; then
  table_count=$(sudo -u postgres psql -d hse_hive_metastore -tAc "SELECT COUNT(*) FROM pg_tables WHERE schemaname = 'public'")
  if ((table_count != 0)); then
    echo "Metastore database is not empty but has no VERSION table; inspect it manually." >&2
    exit 1
  fi
  "$hive_home/bin/schematool" -dbType postgres -initSchema
fi
"$hive_home/bin/schematool" -dbType postgres -info
echo "Hive is configured. Start it with bash hw3/start.sh."
