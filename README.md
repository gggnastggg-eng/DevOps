# Intern DevOps SafeBoard 2026 — тестовое задание

## О проекте

Локальный контур мониторинга доступности сервисов и состояния контейнеров. Docker Compose запускает компоненты, Dagger автоматизирует операции, Prometheus с экспортёрами собирает метрики, Grafana их показывает.

Стенд разделён на два независимых Compose-слоя: приложение (`compose.app.yml`) и мониторинг (`compose.monitoring.yml`). Их можно запускать и проверять отдельно.

## Требования и ограничения (прочитайте перед запуском)

1. **Окружение.** Проект проверялся на Windows 10/11 с WSL2 и Docker Desktop. Команда `configure-grafana` обращается к Grafana по адресу `host.docker.internal:3000`; он доступен в Docker Desktop, а на Linux с обычным Docker Engine может не резолвиться. В этом случае проверьте Grafana вручную: http://localhost:3000/api/health.
2. **Расположение проекта.** Путь `/tmp/devops-check/DevOps_Testovoe` указан в Dagger-модуле (константа `projectPath` в `dagger.go`). Относительные монтирования (`./monitoring`, `./galera`) Docker Compose передаёт демону хоста по этому абсолютному пути, поэтому проект нужно распаковать именно сюда и запускать команды оттуда:

```bash
mkdir -p /tmp/devops-check/DevOps_Testovoe
unzip Глебова_Анастасия_DevOps_Тестовое.zip -d /tmp/devops-check/DevOps_Testovoe
cd /tmp/devops-check/DevOps_Testovoe
```

   (Если нет `unzip`: `python3 -m zipfile -e Глебова_Анастасия_DevOps_Тестовое.zip /tmp/devops-check/DevOps_Testovoe`.)
3. **Сеть kuma-app.** В `compose.app.yml` она объявлена как внешняя (`external: true`), поэтому перед первым запуском её нужно создать:

```bash
docker network create kuma-app
```

   Если сеть уже существует, Docker сообщит об этом, ошибки в этом нет.
4. **Galera.** Узел `galera1` запускается с флагом `--wsrep-new-cluster`, поэтому перезапуск одного этого узла отдельно может не присоединить его к работающему кластеру. Перезапускайте кластер целиком; при ошибке `safe_to_bootstrap` смотрите описание ниже, в разделе про Galera.

## 1. Основные задачи

### 1.1. Развёртывание приложения

В слой приложения входят:

- **Uptime Kuma** — мониторинг доступности сервисов;
- **MariaDB** — отдельный экземпляр базы данных, развёрнутый в рамках стенда.

Uptime Kuma 1.x хранит собственные данные в SQLite. MariaDB развёрнута рядом и не используется Uptime Kuma как основная база.

Запуск:

```bash
dagger call --docker-socket /var/run/docker.sock deploy-app
```

Проверка контейнеров:

```bash
docker compose -f compose.app.yml ps
```

Uptime Kuma открывается по адресу http://localhost:3001. При первом входе нужно создать локальную учётную запись.

### 1.2. Развёртывание мониторинга

В слой мониторинга входят:

- **Prometheus** — сбор и хранение метрик;
- **Grafana** — визуализация;
- **Blackbox Exporter** — доступность сервисов и время ответа;
- **Node Exporter** — метрики хоста;
- **cAdvisor** — метрики контейнеров.

Запуск:

```bash
dagger call --docker-socket /var/run/docker.sock deploy-monitoring
```

Проверка контейнеров:

```bash
docker compose -f compose.monitoring.yml ps
```

| Компонент | Адрес |
|---|---|
| Grafana | http://localhost:3000 |
| Prometheus | http://localhost:9090 |
| cAdvisor | http://localhost:8088 |
| Node Exporter | http://localhost:9100/metrics |
| Blackbox Exporter | http://localhost:9115 |

### 1.3. Настройка Grafana

```bash
dagger call --docker-socket /var/run/docker.sock configure-grafana
```

Команда перезапускает контейнер `kuma-grafana` и проверяет ответ `/api/health`. Источник данных Prometheus и дашборд подключаются автоматически из файлов provisioning (`monitoring/grafana/provisioning` и `monitoring/grafana/dashboards`); через Grafana API они не загружаются. Проверить результат:

- в Grafana: **Connections → Data sources** (источник Prometheus) и затем дашборд с данными;
- в Prometheus: **Status → Targets** (состояние целей сбора);
- по метрикам `probe_success` (результат проверки доступности) и `probe_duration_seconds` (время проверки).

Логин и пароль Grafana задаются переменными окружения. Значения по умолчанию смотрите в `.env.example`.

### 1.4. Автоматизация через Dagger

Dagger запускает основные операции проекта. В используемом окружении Docker socket нужно передавать явно: `--docker-socket /var/run/docker.sock`.

```bash
dagger call --docker-socket /var/run/docker.sock deploy-app
dagger call --docker-socket /var/run/docker.sock deploy-monitoring
dagger call --docker-socket /var/run/docker.sock configure-grafana
dagger call --docker-socket /var/run/docker.sock status
```

## 2. Бонусные задачи

### 2.1. Общий запуск и проверка состояния

```bash
dagger call --docker-socket /var/run/docker.sock deploy-all
dagger call --docker-socket /var/run/docker.sock status
```

Состояние контейнеров можно проверить и напрямую:

```bash
docker compose -f compose.app.yml ps
docker compose -f compose.monitoring.yml ps
```

### 2.2. Chaos Testing

```bash
dagger call --docker-socket /var/run/docker.sock chaos-test
```

Команда выполняет упрощённую проверку: принудительно останавливает контейнер `uptime-kuma` (`docker kill`), через 2 секунды запускает его снова и ждёт, пока контейнер перейдёт в состояние running (до 90 секунд). Реакцию мониторинга она сама не проверяет. Чтобы увидеть её, остановите сервис вручную примерно на минуту (`docker stop uptime-kuma`), убедитесь, что метрика `probe_success` в Prometheus стала `0`, а на дашборде Grafana виден сбой, затем запустите сервис (`docker start uptime-kuma`) и дождитесь возврата метрики к `1`.

### 2.3. Кластер MariaDB Galera из трёх узлов с HAProxy

Кластер состоит из узлов `galera1`, `galera2`, `galera3` и HAProxy (точка входа — порт `3307`). Он описан в `compose.galera.yml`; файл `compose.galera-health.yml` заменяет проверку здоровья узлов (см. ниже).

Запуск:

```bash
docker compose -f compose.galera.yml -f compose.galera-health.yml up -d
```

Оба файла нужны вместе: второй только переопределяет healthcheck.

#### Проверка узлов

Команда выводит ключевые показатели каждого узла (пароль root берётся из переменных самого контейнера):

```bash
for n in galera1 galera2 galera3; do
  echo "--- $n ---"
  docker exec $n sh -c 'MYSQL_PWD="${MARIADB_ROOT_PASSWORD:-$MYSQL_ROOT_PASSWORD}" mariadb -uroot -N -e "SHOW GLOBAL STATUS WHERE Variable_name IN (\"wsrep_cluster_status\",\"wsrep_cluster_size\",\"wsrep_ready\",\"wsrep_local_state_comment\")"'
done
```

Для исправного кластера на каждом узле:

| Параметр | Значение |
|---|---|
| `wsrep_cluster_status` | `Primary` |
| `wsrep_cluster_size` | `3` |
| `wsrep_ready` | `ON` |
| `wsrep_local_state_comment` | `Synced` |

Размер кластера `3` сам по себе не доказывает готовность: нужно смотреть и на `wsrep_ready`, и на `Synced`.

#### Проверка HAProxy

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E "NAMES|galera"
timeout 3 bash -c '</dev/tcp/127.0.0.1/3307' && echo "порт 3307 доступен"
```

Все три узла должны быть `healthy`, а порт `3307` — доступен.

#### Известные особенности

- **Healthcheck.** Стандартная проверка образа MariaDB (`healthcheck.sh`) заходила в базу под root без пароля и получала `Access denied`, из-за чего узлы показывали `unhealthy`, хотя кластер работал. В `compose.galera-health.yml` проверка заменена на запрос `wsrep_ready` с паролем.
- **Запуск после аварийной остановки.** Если кластер остановлен аварийно, `galera1` может не стартовать с ошибкой `safe_to_bootstrap`. Нужно сравнить `seqno` в `grastate.dat` на всех узлах, запустить первым узел с наибольшим значением и разрешить ему bootstrap (`safe_to_bootstrap: 1`).
- **Пароль SST.** Пароль по умолчанию (`change-me-sst-password`) прописан и в `galera/galera.cnf`. При смене `GALERA_SST_PASSWORD` его нужно поменять и там.

## 3. Подготовка и запуск

Нужны Docker Engine, Docker Compose v2 и Dagger CLI (использовалась версия `v0.18.19`).

Создайте локальный файл с настройками и замените демонстрационные пароли:

```bash
cp .env.example .env
```

Инициализация Dagger-модуля:

```bash
dagger develop
```

Дальше запускайте компоненты отдельными командами из раздела 1 или общей командой `deploy-all`. Команды Dagger выполняются из каталога проекта.

## 4. Завершение работы

```bash
docker compose -f compose.monitoring.yml down
docker compose -f compose.app.yml down
docker compose -f compose.galera.yml -f compose.galera-health.yml down
```

`down` без параметра `-v` не удаляет именованные тома. Не добавляйте `-v`, если данные нужно сохранить.

## 5. Важные замечания

- Файл `.env` с паролями не должен попадать в репозиторий; в репозитории остаётся шаблон `.env.example`.
- В папке `history/` лежат резервные копии и логи моих попыток починки (в основном по Galera). Для запуска проекта они не нужны.
- Перед сдачей проверены конфигурации Compose, состояние контейнеров, цели Prometheus и поступление данных в Grafana.
