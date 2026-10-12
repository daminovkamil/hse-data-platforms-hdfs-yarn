#!/usr/bin/env bash
set -euo pipefail

hadoop_home="$HOME/hadoop-3.4.1"
name_dir="$HOME/teachbase-hadoop-data/nn"
if [[ ! -f "$hadoop_home/.teachbase-managed" ]]; then
  echo "Сначала запустите hw1/setup.sh на этой VM." >&2
  exit 1
fi
if [[ -n "$(find "$name_dir" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo "Каталог NameNode уже содержит данные. Форматирование остановлено." >&2
  exit 1
fi

printf 'Это создаст новую файловую систему HDFS. Для продолжения введите FORMAT: '
read -r answer
if [[ "$answer" != FORMAT ]]; then
  echo "Отменено."
  exit 1
fi

"$hadoop_home/bin/hdfs" namenode -format
