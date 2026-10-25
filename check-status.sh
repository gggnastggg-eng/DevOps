#!/usr/bin/env bash
set -euo pipefail

echo "=== Docker version ==="
docker version --format 'Client: {{.Client.Version}} / Server: {{.Server.Version}}'

echo
echo "=== Running containers ==="
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo
echo "=== Project files ==="
for f in compose.app.yml compose.monitoring.yml; do
    if [[ -f "$f" ]]; then
        echo "OK: $f"
    else
        echo "MISSING: $f"
    fi
done

echo
echo "=== Compose configuration validation ==="
for f in compose.app.yml compose.monitoring.yml; do
    if [[ -f "$f" ]]; then
        docker compose -f "$f" config --quiet
        echo "OK: $f"
    fi
done
