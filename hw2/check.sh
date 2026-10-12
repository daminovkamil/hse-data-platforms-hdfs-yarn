#!/usr/bin/env bash
set -euo pipefail

root_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=/dev/null
source "$root_dir/cluster.env"
hadoop_home="$HOME/hadoop-3.4.1"

nodes=$("$hadoop_home/bin/yarn" node -list -all)
printf '%s\n' "$nodes"
running=$(printf '%s\n' "$nodes" | awk '$2 == "RUNNING" { count++ } END { print count + 0 }')
if [[ "$running" != 3 ]]; then
  echo "Ожидались 3 работающих NodeManager, найдено: $running." >&2
  exit 1
fi

for endpoint in \
  "http://$MASTER_HOST:8088/" \
  "http://$MASTER_HOST:19888/" \
  "http://$WORKER1_HOST:8042/" \
  "http://$WORKER2_HOST:8042/" \
  "http://$WORKER3_HOST:8042/"; do
  curl -fsS -o /dev/null "$endpoint"
  echo "Доступен: $endpoint"
done

status=$(curl -sS -o /dev/null -w '%{http_code}' "http://$MASTER_HOST:9099/") || {
  echo "WebAppProxy на порту 9099 не отвечает." >&2
  exit 1
}
case "$status" in
  2??|3??|404) ;;
  *)
    echo "WebAppProxy ответил HTTP $status." >&2
    exit 1
    ;;
esac
echo "WebAppProxy отвечает (HTTP $status)."
