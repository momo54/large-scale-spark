#!/usr/bin/env bash
set -euo pipefail

# Simple helper to start the local Spark "cluster" with docker-compose
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

echo "Starting docker-compose Spark cluster (master + 3 workers + jupyter)..."
# Rebuild Jupyter image to ensure base SPARK_IMAGE is applied
docker-compose build --pull jupyter
docker-compose up -d --remove-orphans --force-recreate

echo "Waiting for Spark master UI to be ready on http://localhost:8080 ..."
# Wait up to ~45s probing the UI
for i in {1..30}; do
	if curl -fsS http://localhost:8080 >/dev/null 2>&1; then
		break
	fi
	sleep 1.5
done

echo "Containers:"
docker-compose ps

echo
echo "Jupyter will be available at: http://localhost:8888 (no token)"
echo "Spark master at: spark://spark-master:7077 (web UI http://localhost:8080)"

echo "To stop the cluster: ./docker/stop_cluster.sh"
