#!/usr/bin/env bash

echo "===== Восстановление Uptime Kuma ====="
docker start uptime-kuma >/dev/null 2>&1 || true

for i in $(seq 1 30); do
    state=$(docker inspect -f '{{.State.Status}}' uptime-kuma 2>/dev/null || echo missing)
    health=$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' uptime-kuma 2>/dev/null || echo unknown)

    if [ "$state" = "running" ] && curl -sS --max-time 2 http://localhost:3001/ >/dev/null 2>&1; then
        echo "OK: веб-интерфейс отвечает"
        break
    fi

    echo "Попытка $i/30: состояние=$state, health=$health"
    sleep 2
done

echo
echo "===== Итоговое состояние ====="
docker inspect -f 'Состояние: {{.State.Status}} | Health: {{if .State.Health}}{{.State.Health.Status}}{{else}}нет healthcheck{{end}}' uptime-kuma

echo
echo "===== Проверка веб-интерфейса ====="
if curl -fsS --max-time 5 http://localhost:3001/ >/dev/null; then
    echo "OK: http://localhost:3001 доступен"
else
    echo "ERROR: интерфейс не отвечает"
    docker logs --tail 50 uptime-kuma
fi

echo
echo "===== Контейнеры ====="
docker ps --format 'table {{.Names}}\t{{.Status}}'
