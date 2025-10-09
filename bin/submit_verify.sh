#!/usr/bin/env bash
set -euo pipefail

# Submit the verification job (src/verify_cluster.py) to the local Spark master

ROOT="$(pwd)"
NETWORK_DEFAULT="$(basename "$ROOT")_default"
NETWORK="${NETWORK:-$NETWORK_DEFAULT}"
IMAGE="${SPARK_IMAGE:-spark:4.0.0-java21-python3}"
MASTER="${SPARK_MASTER:-spark://spark-master:7077}"

mkdir -p "$ROOT/output"

exec docker run --rm \
  --network "$NETWORK" \
  -v "$ROOT":/work \
  -v "$ROOT"/output:/shared \
  -v "$ROOT":/data:ro \
  -w /work \
  "$IMAGE" \
  /opt/spark/bin/spark-submit --master "$MASTER" /work/src/verify_cluster.py
