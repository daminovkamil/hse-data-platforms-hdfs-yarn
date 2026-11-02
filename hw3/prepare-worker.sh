#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y openjdk-21-jdk-headless
if [[ ! -x /usr/lib/jvm/java-21-openjdk-amd64/bin/java ]]; then
  echo "Java 21 installation failed on this worker." >&2
  exit 1
fi
echo "Java 21 is available for Hive MapReduce tasks on this worker."
