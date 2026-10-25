#!/usr/bin/env bash
set -Eeuo pipefail
LOG="finish-devops-final.log"
exec > >(tee "$LOG") 2>&1

trap 'echo; echo "ОШИБКА на строке $LINENO. Полный вывод: $LOG"' ERR

echo "===== 1. Проверка Docker ====="
docker info >/dev/null
test -S /var/run/docker.sock || {
  echo "Docker socket недоступен: /var/run/docker.sock"
  exit 1
}

echo "===== 2. Проверка Compose ====="
docker compose -f compose.app.yml config -q
docker compose -f compose.monitoring.yml config -q

echo "===== 3. Запуск приложения и мониторинга ====="
docker compose -f compose.app.yml up -d
docker compose -f compose.monitoring.yml up -d

echo "===== 4. Подготовка Dagger ====="
dagger develop

echo "===== 5. Настройка Grafana через Dagger ====="
dagger call --docker-socket /var/run/docker.sock configure-grafana

echo "===== 6. Развёртывание всего стенда через Dagger ====="
dagger call --docker-socket /var/run/docker.sock deploy-all

echo "===== 7. Статус Dagger ====="
dagger call --docker-socket /var/run/docker.sock status

echo "===== 8. Проверка веб-интерфейсов ====="
for url in \
  http://localhost:3001 \
  http://localhost:3000/api/health \
  http://localhost:9090/-/ready; do
  if curl -fsS --max-time 10 "$url" >/dev/null; then
    echo "OK: $url"
  else
    echo "ПРЕДУПРЕЖДЕНИЕ: $url не ответил"
  fi
done

echo "===== 9. Итоговые контейнеры ====="
docker ps --format 'table {{.Names}}\t{{.Status}}'

echo
echo "ОСНОВНЫЕ ПРОВЕРКИ ЗАВЕРШЕНЫ"
echo "Grafana: http://localhost:3000"
echo "Prometheus: http://localhost:9090"
echo "Uptime Kuma: http://localhost:3001"
echo "Лог: $LOG"
