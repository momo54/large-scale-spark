#!/usr/bin/env bash
set -euo pipefail

# Simple helper to start the local Spark "cluster" with docker compose
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# docker compose (v2) if available, else the old docker-compose
if docker compose version >/dev/null 2>&1; then COMPOSE="docker compose"; else COMPOSE="docker-compose"; fi

# output/ is mounted as /shared. Create it before Docker does (Docker would create it as
# root): on Linux, the containers run as spark (uid 185) and jovyan (uid 1000) and must
# both be able to write into it.
mkdir -p output
chmod a+rwx output 2>/dev/null || sudo chmod a+rwx output || echo "WARNING: could not make output/ writable (chmod a+rwx output)"

# GitHub Codespaces: rules left in iptables-legacy by an earlier Docker start (policy
# FORWARD DROP, only docker0 allowed) drop the traffic between the containers of the
# compose network: workers and drivers never reach the master
# ("All masters are unresponsive! Giving up.").
if [ "${CODESPACES:-}" = "true" ] && [ -e /proc/net/ip_tables_names ] && command -v iptables-legacy >/dev/null 2>&1 \
	&& sudo iptables-legacy -S FORWARD 2>/dev/null | grep -q -- '-P FORWARD DROP'; then
	echo "Codespaces: iptables-legacy FORWARD policy DROP -> ACCEPT (traffic between containers)"
	sudo iptables-legacy -P FORWARD ACCEPT
fi

echo "Starting docker compose Spark cluster (master + 3 workers + jupyter)..."
# Rebuild Jupyter image to ensure base SPARK_IMAGE is applied
$COMPOSE build --pull jupyter
$COMPOSE up -d --remove-orphans --force-recreate

echo "Waiting for Spark master UI to be ready on http://localhost:8080 ..."
# Wait up to ~45s probing the UI
for i in {1..30}; do
	if curl -fsS http://localhost:8080 >/dev/null 2>&1; then
		break
	fi
	sleep 1.5
done

echo "Containers:"
$COMPOSE ps

echo
echo "Jupyter will be available at: http://localhost:8888 (no token)"
echo "Spark master at: spark://spark-master:7077 (web UI http://localhost:8080)"

echo "To stop the cluster: ./docker/stop_cluster.sh"
