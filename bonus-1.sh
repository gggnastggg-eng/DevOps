#!/usr/bin/env bash
set -u

LOG="bonus-1-deploy-all.log"

echo "===== Bonus 1: End-to-End Orchestration ====="

if dagger call --docker-socket /var/run/docker.sock deploy-all 2>&1 | tee "$LOG"; then
    echo
    echo "SUCCESS: deploy-all завершился без ошибки."
else
    echo
    echo "ERROR: deploy-all завершился с ошибкой."
    echo "Лог сохранён в $LOG"
    exit 1
fi
