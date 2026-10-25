#!/usr/bin/env bash
set -euo pipefail
docker compose -f compose.app.yml config -q
docker compose -f compose.monitoring.yml config -q
python3 -m json.tool monitoring/grafana/dashboards/uptime-kuma-overview.json >/dev/null
echo "Static configuration checks passed. This does not replace running the stack."
