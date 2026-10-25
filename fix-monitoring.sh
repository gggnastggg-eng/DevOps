#!/usr/bin/env bash

cd /tmp/devops-check/DevOps_Testovoe || exit 1
LOG="$PWD/monitoring-deploy.log"
exec > >(tee "$LOG") 2>&1

pause() {
    echo
    read -r -p "Нажми Enter, чтобы закрыть этот запуск..."
}

trap 'rc=$?; echo; echo "ОШИБКА: команда завершилась с кодом $rc"; echo "Журнал: '"$PWD"'/monitoring-deploy.log"; pause; exit "$rc"' ERR

echo "================================================"
echo " РАЗВЁРТЫВАНИЕ И ПРОВЕРКА МОНИТОРИНГА"
echo "================================================"
echo

echo "[1/7] Проверка Docker"
docker info >/dev/null
echo "OK: Docker доступен."

echo
echo "[2/7] Проверка файлов проекта"
for f in compose.app.yml compose.monitoring.yml monitoring/prometheus.yml monitoring/blackbox.yml; do
    if [ ! -e "$f" ]; then
        echo "Не найден файл: $f"
        exit 1
    fi
done
echo "OK: основные файлы найдены."

echo
echo "[3/7] Проверка конфигурации Compose"
docker compose -f compose.app.yml config -q
docker compose -f compose.monitoring.yml config -q
echo "OK: обе конфигурации корректны."

echo
echo "[4/7] Проверка сети приложения"
if ! docker network inspect kuma-app >/dev/null 2>&1; then
    echo "Сеть kuma-app отсутствует. Запускаю приложение..."
    docker compose -f compose.app.yml up -d
fi

docker network inspect kuma-app >/dev/null
echo "OK: сеть kuma-app существует."

echo
echo "[5/7] Развёртывание мониторинга"
docker compose -f compose.monitoring.yml up -d

echo
echo "[6/7] Ожидание запуска сервисов"
for i in $(seq 1 18); do
    if curl -fsS --connect-timeout 2 http://localhost:9090/-/ready >/dev/null 2>&1 \
       && curl -fsS --connect-timeout 2 http://localhost:3000/api/health >/dev/null 2>&1; then
        break
    fi
    sleep 5
done

echo
echo "[7/7] Итоговое состояние"
docker compose -f compose.app.yml ps -a
docker compose -f compose.monitoring.yml ps -a

echo
echo "Проверка Prometheus:"
if curl -fsS --connect-timeout 5 --max-time 10 http://localhost:9090/-/ready; then
    echo
    echo "ЗЕЛЁНЫЙ: Prometheus отвечает."
else
    echo "НЕ ГОТОВ: Prometheus не ответил на HTTP-проверку."
fi

echo
echo "Проверка Grafana:"
if curl -fsS --connect-timeout 5 --max-time 10 http://localhost:3000/api/health; then
    echo
    echo "ЗЕЛЁНЫЙ: Grafana отвечает."
else
    echo "НЕ ГОТОВА: Grafana не ответила на HTTP-проверку."
fi

echo
echo "Проверка состояния контейнеров:"
docker ps --format 'table {{.Names}}\t{{.Status}}'

echo
echo "Готово. Журнал сохранён в monitoring-deploy.log."
echo "Если какой-то сервис не готов, причина должна быть выше в выводе."
pause
