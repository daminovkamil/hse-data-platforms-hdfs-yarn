#!/usr/bin/env bash
set -euo pipefail

hadoop_home="$HOME/hadoop-3.4.1"
spark_home="$HOME/spark-3.5.8-bin-hadoop3"
if [[ ! -f "$hadoop_home/.teachbase-managed" ]]; then
  echo "Run hw1/setup.sh and hw2/setup.sh on the master VM first." >&2
  exit 1
fi
if [[ -e "$spark_home" && ! -f "$spark_home/.hse-homework-managed" ]]; then
  echo "Existing Spark directory is not managed by this homework: $spark_home" >&2
  exit 1
fi
if [[ ! -x /usr/lib/jvm/java-11-openjdk-amd64/bin/java ]]; then
  echo "Java 11 is required for Spark 3.5.8." >&2
  exit 1
fi

if [[ ! -d "$spark_home" ]]; then
  temp_dir=$(mktemp -d)
  trap 'rm -rf -- "$temp_dir"' EXIT
  archive=spark-3.5.8-bin-hadoop3.tgz
  base_url=https://archive.apache.org/dist/spark/spark-3.5.8
  curl -fsSL "$base_url/$archive" -o "$temp_dir/$archive"
  curl -fsSL "$base_url/$archive.sha512" -o "$temp_dir/$archive.sha512"
  expected=$(grep -Eo '[[:xdigit:]]{128}' "$temp_dir/$archive.sha512" | head -n 1)
  actual=$(sha512sum "$temp_dir/$archive" | awk '{print $1}')
  if [[ -z "$expected" || "${expected,,}" != "$actual" ]]; then
    echo "Spark archive SHA-512 verification failed." >&2
    exit 1
  fi
  tar -xzf "$temp_dir/$archive" -C "$temp_dir"
  mv "$temp_dir/spark-3.5.8-bin-hadoop3" "$spark_home"
  touch "$spark_home/.hse-homework-managed"
fi

if [[ ! -x "$spark_home/bin/spark-submit" ]]; then
  echo "Spark installation is incomplete: $spark_home" >&2
  exit 1
fi
echo "Spark 3.5.8 is installed. Run bash hw4/run.sh on the master VM."
