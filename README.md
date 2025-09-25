# monitor_test

Скрипт и systemd unit для мониторинга процесса `test`.

# Состав репозитория
- `monitor_test.sh` — основной bash-скрипт, выполняет проверку процесса и отправку запроса.
- `monitor_test.service` — unit-файл для systemd, чтобы запускать скрипт.
- `monitor_test.timer` — таймер systemd, запускает скрипт раз в минуту.

# Как работает
- Раз в минуту проверяет, запущен ли процесс `test`.
- Если процесс есть, делает HTTPS-запрос на `https://test.com/monitoring/test/api`.
- Если процесс перезапустился — пишет запись в `/var/log/monitoring.log`.
- Если сервер недоступен — пишет ошибку в лог.

# Установка
Скопируйте файлы:
```bash
sudo cp monitor_test.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/monitor_test.sh
sudo cp monitor_test.service /etc/systemd/system/
sudo cp monitor_test.timer /etc/systemd/system/
