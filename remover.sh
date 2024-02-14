#!/bin/bash

CONFIG_FILE="/root/pulsar_security/config.yml"
LOG_DIRECTORY="/root/pulsar_security/log"
SCRIPT_PATH="/path/to/your/script.sh"  # Replace with the actual path to the script

# Остановка фонового процесса мониторинга (если он запущен)
monitor_pid=$(pgrep -f 'monitor_container_cpu_usage')
if [ ! -z "$monitor_pid" ]; then
  echo "Остановка процесса мониторинга с PID $monitor_pid"
  kill "$monitor_pid"
fi

# Удаление конфигурационного файла и каталога логов
echo "Удаление конфигурационного файла и каталога логов..."
rm -f "$CONFIG_FILE"
rm -rf "$LOG_DIRECTORY"

# Удаление скрипта
echo "Удаление скрипта..."
rm -f "$SCRIPT_PATH"

echo "Скрипт и все связанные файлы были удалены."
