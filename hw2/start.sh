#!/usr/bin/env bash
set -euo pipefail

role=${1:-}
hadoop_home="$HOME/hadoop-3.4.1"
if [[ ! -f "$hadoop_home/.teachbase-managed" ]]; then
  echo "Сначала выполните ДЗ №1 на этой VM." >&2
  exit 1
fi

case "$role" in
  master)
    "$hadoop_home/bin/yarn" --daemon start resourcemanager
    "$hadoop_home/bin/yarn" --daemon start proxyserver
    "$hadoop_home/bin/mapred" --daemon start historyserver
    ;;
  worker)
    "$hadoop_home/bin/yarn" --daemon start nodemanager
    ;;
  *)
    echo "Использование: bash hw2/start.sh master|worker" >&2
    exit 2
    ;;
esac

if command -v jps >/dev/null 2>&1; then
  jps
else
  echo "Команда запуска выполнена. Проверьте процесс: ps -ef | grep '[o]rg.apache.hadoop'"
fi
