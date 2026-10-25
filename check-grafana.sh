#!/usr/bin/env bash
set -u

echo "===== 1. Grafana ====="
curl -sS --max-time 5 http://localhost:3000/api/health
echo -e "\n"

echo "===== 2. Проверка целей Prometheus ====="
curl -fsS --max-time 10 \
  'http://localhost:9090/api/v1/targets' |
python3 -c '
import json, sys
d=json.load(sys.stdin)
targets=d.get("data",{}).get("activeTargets",[])
if not targets:
    print("Цели не найдены")
for t in targets:
    print(f"{t.get('\"'\"'labels'\"'\"',{}).get('\"'\"'job'\"'\"','\"'\"'?'\"'\"')}: "
          f"{t.get('\"'\"'health'\"'\"','\"'\"'?'\"'\"')} — "
          f"{t.get('\"'\"'lastError'\"'\"') or '\"'\"'ошибок нет'\"'\"'}")
'

echo
echo "===== 3. Есть ли метрики в Prometheus ====="
curl -fsS --max-time 10 \
  'http://localhost:9090/api/v1/query?query=up' |
python3 -c '
import json, sys
d=json.load(sys.stdin)
for r in d.get("data",{}).get("result",[]):
    print(f"{r['\"'\"'metric'\"'\"'].get('\"'\"'job'\"'\"','\"'\"'?'\"'\"')} / "
          f"{r['\"'\"'metric'\"'\"'].get('\"'\"'instance'\"'\"','\"'\"'?'\"'\"')}: "
          f"up={r['\"'\"'value'\"'\"'][1]}")
'

echo
echo "===== 4. Дашборды Grafana ====="
echo "Открой: http://localhost:3000"
echo "Проверь Dashboards → Browse → Infrastructure"
echo
echo "Проверка завершена."
