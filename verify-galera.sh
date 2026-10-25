#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

PASS=1
echo "=== GALERA FINAL CHECK ==="

echo
echo "1. Waiting for cluster synchronization (up to 120 sec)..."
DEADLINE=$((SECONDS + 120))
SIZE=0
STATE="unknown"
READY="OFF"

while (( SECONDS < DEADLINE )); do
  OUT=$(docker exec galera1 mariadb -uroot -p'change-me-galera-root' \
    -Nse "SHOW STATUS WHERE Variable_name IN ('wsrep_cluster_size','wsrep_local_state_comment','wsrep_ready');" 2>/dev/null || true)

  SIZE=$(printf '%s\n' "$OUT" | awk '$1=="wsrep_cluster_size"{print $2}')
  STATE=$(printf '%s\n' "$OUT" | awk '$1=="wsrep_local_state_comment"{print $2}')
  READY=$(printf '%s\n' "$OUT" | awk '$1=="wsrep_ready"{print $2}')

  if [[ "$SIZE" == "3" && "$STATE" == "Synced" && "$READY" == "ON" ]]; then
    break
  fi
  sleep 5
done

echo "Cluster size: ${SIZE:-unknown}"
echo "Node state: ${STATE:-unknown}"
echo "Ready: ${READY:-unknown}"

if [[ "$SIZE" != "3" || "$STATE" != "Synced" || "$READY" != "ON" ]]; then
  echo "FAIL: cluster is not fully synchronized."
  PASS=0
fi

echo
echo "2. Checking all three nodes..."
for NODE in galera1 galera2 galera3; do
  if docker exec "$NODE" mariadb-admin ping --silent >/dev/null 2>&1; then
    echo "PASS: $NODE responds"
  else
    echo "FAIL: $NODE is not responding"
    PASS=0
  fi
done

echo
echo "3. Checking HAProxy container..."
if docker inspect -f '{{.State.Running}}' galera-haproxy 2>/dev/null | grep -qx true; then
  echo "PASS: HAProxy container is running"
else
  echo "FAIL: HAProxy container is not running"
  docker logs --tail 20 galera-haproxy 2>&1 || true
  PASS=0
fi

echo
echo "4. Checking HAProxy statistics page..."
if curl -fsS --max-time 5 http://localhost:8404/ >/dev/null; then
  echo "PASS: http://localhost:8404/"
else
  echo "FAIL: HAProxy statistics page unavailable"
  PASS=0
fi

echo
echo "5. Checking TCP connection through HAProxy..."
if timeout 5 bash -c '</dev/tcp/127.0.0.1/3307' 2>/dev/null; then
  echo "PASS: TCP port 3307 accepts connections"
else
  echo "FAIL: TCP port 3307 unavailable"
  PASS=0
fi

echo
echo "=== FINAL RESULT ==="
if [[ "$PASS" == "1" ]]; then
  echo "PASS: all checks passed"
  exit 0
else
  echo "FAIL: see failed checks above; no data was deleted"
  exit 1
fi
