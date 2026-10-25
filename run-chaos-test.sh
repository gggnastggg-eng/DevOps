#!/usr/bin/env bash
set -u

echo "===== 1. Запуск Chaos Test через Dagger ====="
dagger call --docker-socket /var/run/docker.sock chaos-test
chaos_result=$?

echo
echo "===== 2. Восстановление Uptime Kuma ====="
docker start uptime-kuma || true

echo
echo "===== 3. Проверка восстановления ====="
for i in $(seq 1 30); do
    if curl -fsS --max-time 3 http://localhost:3001/ >/dev/null; then
        echo "OK: Uptime Kuma снова доступен: http://localhost:3001"
        break
    fi
    sleep 2
done

if ! curl -fsS --max-time 5 http://localhost:3001/ >/dev/null; then
    echo "ВНИМАНИЕ: интерфейс пока недоступен. Последние логи:"
    docker logs --tail 40 uptime-kuma
fi

echo
echo "===== 4. Статус контейнеров ====="
docker ps --format 'table {{.Names}}\t{{.Status}}'

if [ "$chaos_result" -ne 0 ]; then
    echo
    echo "Chaos Test завершился с ошибкой. Сервисы проверены отдельно."
fi
