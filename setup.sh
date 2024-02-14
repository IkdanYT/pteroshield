#!/bin/bash

CONFIG_FILE="/root/pulsar_security/config.yml"
LOG_DIRECTORY="/root/pulsar_security/log"
LOG_FILE="$LOG_DIRECTORY/pulsar_security_script.log"

# Функция для запроса настройки
prompt_for_configuration() {
  read -p "Введите URL Discord вебхука: " DISCORD_WEBHOOK_URL
  read -p "Введите имя хоста: " HOST_NAME
  read -p "Введите лимит хранилища в ГБ (например, 100G), чтобы предотвратить заполнение диска: " STORAGE_LIMIT
  read -p "Хотите ли вы выделить swap файл? (Y/N): " SWAP_FILE

  DISK_USAGE=$(df --output=pcent / | awk 'END{gsub(/%/,""); print}')
  STORAGE_LIMIT="${STORAGE_LIMIT%G}"
  STORAGE_LIMIT=$(((STORAGE_LIMIT * 90) / 100)) # Уменьшаем на 10%
  if [ $DISK_USAGE -ge $STORAGE_LIMIT ]; then
    echo "Предупреждение: Использование диска (${DISK_USAGE}%) превышает заданный предел (${STORAGE_LIMIT}%). Проверьте настройки STORAGE_LIMIT."
    STORAGE_LIMIT="${STORAGE_LIMIT}G" # Восстанавливаем G для использования в конфигурации
  fi

  echo "DISCORD_WEBHOOK_URL=\"$DISCORD_WEBHOOK_URL\"" > "$CONFIG_FILE"
  echo "HOST_NAME=\"$HOST_NAME\"" >> "$CONFIG_FILE"
  echo "STORAGE_LIMIT=\"${STORAGE_LIMIT}G\"" >> "$CONFIG_FILE"
  echo "SWAP_FILE=\"$SWAP_FILE\"" >> "$CONFIG_FILE"
  echo "Конфигурация завершена и сохранена в файле $CONFIG_FILE."
}

# Функция для создания конфигурационного файла по умолчанию
create_default_config() {
  mkdir -p /root/pulsar_security

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Создание файла конфигурации по умолчанию..."
    cat <<EOF >"$CONFIG_FILE"
DISCORD_WEBHOOK_URL=""
HOST_NAME=""
STORAGE_LIMIT=""
SWAP_FILE=""
EOF
    echo "Файл конфигурации по умолчанию создан в $CONFIG_FILE"
  fi
}

# Функция для загрузки конфигурации из файла
load_configuration() {
  [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
}

# Функция для создания директории журнала
setup_log_directory() {
  mkdir -p "$LOG_DIRECTORY"
}

# Функция для создания swap файла исходя из пользовательского ввода
create_swap_file() {
  load_configuration
  if [[ "$SWAP_FILE" =~ ^[Yy]$ ]]; then
    read -p "Сколько ГБ необходимо для swap файла? " SSG
    if [[ "$SSG" =~ ^[0-9]+$ ]]; then
      SSGB=$((SSG * 1024 * 1024 * 1024))
      sudo fallocate -l "$SSGB" /swapfile
      sudo chmod 600 /swapfile
      sudo mkswap /swapfile
      sudo swapon /swapfile
      echo "Swap файл $SSG ГБ создан."
    else
      echo "Неверный ввод. Укажите корректное число ГБ для swap файла."
    fi
  else
    echo "Swap файл не создан."
  fi
}

# Функция для автоматического теста скорости интернета
test_internet_speed() {
  if ! hash speedtest-cli 2>/dev/null; then
    echo "Установка speedtest-cli для тестирования скорости интернета..."
    sudo apt-get install -y speedtest-cli
  fi
  echo "Тестирование скорости интернета..."
  speedtest-cli --simple | tee -a "$LOG_FILE"
}

# Функция для установки bc если нет
ensure_bc_installed() {
  if ! hash bc 2>/dev/null; then
    sudo apt-get install -y bc
  fi
}

# Функция для мониторинга использования CPU контейнерами
monitor_container_cpu_usage() {
  load_configuration
  ensure_bc_installed
  while true; do
    stats=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}")

    while IFS= read -r line; do
      container_name=$(echo "$line" | awk '{print $1}')
      cpu_usage=$(echo "$line" | awk '{gsub(/%/, "", $NF); print $NF}')
      
      if (( $(echo "$cpu_usage > 100" | bc -l) )); then
        echo "Высокое использование CPU для контейнера: $container_name" | tee -a "$LOG_FILE"
        message="⚠️ Высокая загрузка CPU в контейнере *$container_name* на *$HOST_NAME*. CPU: *$cpu_usage%*"
        curl -H "Content-Type: application/json" -d "{\"content\":\"$message\"}" "$DISCORD_WEBHOOK_URL"
      fi
    done <<< "$(echo "$stats" | sed 1d)"

    sleep 60
  done
}

# Основной скрипт

# Настройка конфигурации
prompt_for_configuration
create_default_config
setup_log_directory
create_swap_file

# Тест скорости интернета
test_internet_speed

# Непрерывный мониторинг использования CPU в фоновом режиме
monitor_container_cpu_usage &
