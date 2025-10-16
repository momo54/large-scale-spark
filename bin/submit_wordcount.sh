#!/usr/bin/env bash
set -euo pipefail

# Submit the wordcount job (src/wordcount.py) to the local Spark master via Docker

ROOT="$(pwd)"
NETWORK_DEFAULT="$(basename "$ROOT")_default"
NETWORK="${NETWORK:-$NETWORK_DEFAULT}"
IMAGE="${SPARK_IMAGE:-spark:4.0.0-java21-python3}"
MASTER="${SPARK_MASTER:-spark://spark-master:7077}"

# Defaults: input in container-visible /data (repo mounted as /data:ro), output to /shared
INPUT="${1:-/data/data/mobydick.txt}"
OUTPUT="${2:-/shared/mobydick_wc}"

mkdir -p "$ROOT/output"

DOCKER_PUBLISH=""
if [ -n "${PUBLISH_4040:-}" ]; then
  # allow PUBLISH_4040 to be just a port number (host:container mapping will be host:4040->4040)
  DOCKER_PUBLISH="-p ${PUBLISH_4040}:4040"
fi

exec docker run --rm \
  --network "$NETWORK" \
  $DOCKER_PUBLISH \
  -v "$ROOT":/work \
  -v "$ROOT"/output:/shared \
  -v "$ROOT":/data:ro \
  -w /work \
  "$IMAGE" \
  /opt/spark/bin/spark-submit --master "$MASTER" /work/src/wordcount.py "$INPUT" "$OUTPUT"
