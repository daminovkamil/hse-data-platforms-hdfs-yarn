#!/usr/bin/env bash
set -euo pipefail

role=${1:-}
hadoop_home="$HOME/hadoop-3.4.1"
if [[ ! -f "$hadoop_home/.teachbase-managed" ]]; then
  echo "Сначала запустите hw1/setup.sh на этой VM." >&2
  exit 1
fi

case "$role" in
  master)
    if [[ ! -f "$HOME/teachbase-hadoop-data/nn/current/VERSION" ]]; then
      echo "NameNode ещё не отформатирован. См. hw1/format-once.sh." >&2
      exit 1
    fi
    "$hadoop_home/bin/hdfs" --daemon start namenode
    ;;
  worker-secondary)
    "$hadoop_home/bin/hdfs" --daemon start datanode
    "$hadoop_home/bin/hdfs" --daemon start secondarynamenode
    ;;
  worker)
    "$hadoop_home/bin/hdfs" --daemon start datanode
    ;;
  *)
    echo "Использование: bash hw1/start.sh master|worker-secondary|worker" >&2
    exit 2
    ;;
esac

if command -v jps >/dev/null 2>&1; then
  jps
else
  echo "Команда запуска выполнена. Проверьте процесс: ps -ef | grep '[o]rg.apache.hadoop'"
fi
