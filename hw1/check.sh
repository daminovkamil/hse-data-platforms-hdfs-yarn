#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$root_dir/cluster.env"
hadoop_home="$HOME/hadoop-3.4.1"

report=$("$hadoop_home/bin/hdfs" dfsadmin -report)
printf '%s\n' "$report"
live_nodes=$(printf '%s\n' "$report" | sed -n 's/^Live datanodes (\([0-9][0-9]*\)):.*/\1/p')
if [[ "$live_nodes" != 3 ]]; then
  echo "Ожидались 3 работающих DataNode, найдено: ${live_nodes:-0}." >&2
  exit 1
fi

under_replicated=$(printf '%s\n' "$report" | awk '$1 == "Under" && $2 == "replicated" && $3 == "blocks:" { print $4; exit }')
if [[ "$under_replicated" != 0 ]]; then
  echo "Ожидалось 0 недореплицированных блоков, найдено: ${under_replicated:-неизвестно}." >&2
  exit 1
fi

"$hadoop_home/bin/hdfs" fsck /
for endpoint in \
  "http://$MASTER_HOST:9870/" \
  "http://$WORKER1_HOST:9868/" \
  "http://$WORKER1_HOST:9864/" \
  "http://$WORKER2_HOST:9864/" \
  "http://$WORKER3_HOST:9864/"; do
  curl -fsS -o /dev/null "$endpoint"
  echo "Доступен: $endpoint"
done
echo "HDFS отвечает; три DataNode и Secondary NameNode работают."
