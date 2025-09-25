#!/usr/bin/env bash
set -uo pipefail

# Настройки
PROCESS_NAME="test"
MONITOR_URL="https://test.com/monitoring/test/api"
LOG_FILE="/var/log/monitoring.log"
STATE_DIR="/var/lib/monitoring"
STATE_FILE="${STATE_DIR}/monitor_test.pid"
LOCKFILE="/var/lock/monitor_test.lock"
CURL_TIMEOUT=10   # секунд ожидания curl

# Создаём рабочие каталоги
mkdir -p "$STATE_DIR"
touch "$LOG_FILE"
chmod 644 "$LOG_FILE"

# Функция логирования
log() {
    local ts
    ts="$(date +"%Y-%m-%dT%H:%M:%S%:z")"
    echo "$ts - $*" >> "$LOG_FILE"
}

# Блокировка, чтобы не запускалось параллельно
exec 200>"$LOCKFILE"
flock -n 200 || exit 0

# Поиск PID процесса
PID=""
if command -v pgrep >/dev/null 2>&1; then
    PID="$(pgrep -x -o "$PROCESS_NAME" 2>/dev/null || true)"
else
    PID="$(pidof -s "$PROCESS_NAME" 2>/dev/null || true)"
fi

# Если процесса нет — ничего не делаем
if [[ -z "$PID" ]]; then
    exit 0
fi

# Проверка на рестарт процесса
OLD_PID=""
if [[ -f "$STATE_FILE" ]]; then
    OLD_PID="$(cat "$STATE_FILE" 2>/dev/null || true)"
fi

echo "$PID" > "$STATE_FILE"

if [[ -n "$OLD_PID" && "$OLD_PID" != "$PID" ]]; then
    log "Process '${PROCESS_NAME}' was restarted: old_pid=${OLD_PID} new_pid=${PID}"
fi

# Проверка доступности монитор-сервера
HTTP_CODE="$(curl --silent --show-error --max-time "$CURL_TIMEOUT" -o /dev/null -w "%{http_code}" "$MONITOR_URL" 2>/dev/null || echo "")"

if [[ -z "$HTTP_CODE" ]]; then
    log "Monitoring server unreachable for '${PROCESS_NAME}' (pid=${PID}). curl failed or timed out."
    exit 0
fi

if [[ ! "$HTTP_CODE" =~ ^[0-9]{3}$ ]]; then
    log "Monitoring server returned unexpected response for '${PROCESS_NAME}' (pid=${PID}): resp='${HTTP_CODE}'"
    exit 0
fi

HTTP_INT=$((10#$HTTP_CODE))
if (( HTTP_INT < 200 || HTTP_INT >= 300 )); then
    log "Monitoring server returned HTTP ${HTTP_CODE} for '${PROCESS_NAME}' (pid=${PID}); url=${MONITOR_URL}"
fi

exit 0

