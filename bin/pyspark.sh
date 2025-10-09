#!/usr/bin/env bash
set -euo pipefail

# Launch an interactive PySpark REPL connected to the local Spark master (docker-compose)
# - Reads from /data (RO) which maps to repo root (so CSVs under /data/data/...)
# - Writes to /shared (RW) which maps to ./output on host

ROOT="$(pwd)"
NETWORK_DEFAULT="$(basename "$ROOT")_default"
NETWORK="${NETWORK:-$NETWORK_DEFAULT}"
IMAGE="${SPARK_IMAGE:-spark:4.0.0-java21-python3}"
MASTER="${SPARK_MASTER:-spark://spark-master:7077}"

# Forward any extra args to pyspark safely
ARGS=""
if [ $# -gt 0 ]; then
  for a in "$@"; do ARGS+=" "$(printf %q "$a"); done
fi

mkdir -p "$ROOT/output"

exec docker run --rm -it \
  --network "$NETWORK" \
  -v "$ROOT":/data:ro \
  -v "$ROOT"/output:/shared \
  "$IMAGE" \
  bash -lc "/opt/spark/bin/pyspark --master $MASTER$ARGS"
