#!/bin/bash

CONFIG_FILE="/root/pulsar_security/config.yml"
LOG_DIRECTORY="/root/pulsar_security/log"
LOG_FILE="$LOG_DIRECTORY/pulsar_security_script.log"

# Функция для запроса конфигурации
prompt_for_configuration() {
  echo "Введите данные для конфигурации:"
  read -rp "Введите URL Discord вебхука: " DISCORD_WEBHOOK_URL
  read -rp "Введите имя хоста: " HOST_NAME
  echo "Автоматическое определение доступного дискового пространства..."
  STORAGE_LIMIT=$(df / | awk 'END{print int($4/1024/1024*0.9)"G"}')
  echo "Установлено ограничение на использование диска: $STORAGE_LIMIT"
  echo "Тестирование скорости интернета..."
  NETWORK_LIMIT=$(speedtest --simple | grep 'Download:' | grep -oP '\d+\.\d+')
  echo "Обнаружена скорость интернета: $NETWORK_LIMIT Mbps"
  BLOCK_PORTS="N"
  
  read -rp "Какие порты вы будете выделять для игровых портов Pterodactyl Wings (например, 5000-6000)? " PTERODACTYL_WINGS_PORTS
  read -rp "Хотите ли вы сейчас запустить установку Pterodactyl Wings? (Y/N): " PTERODACTYL_WINGS_INSTALL

  echo "DISCORD_WEBHOOK_URL=\"$DISCORD_WEBHOOK_URL\"" > "$CONFIG_FILE"
  echo "HOST_NAME=\"$HOST_NAME\"" >> "$CONFIG_FILE"
  echo "STORAGE_LIMIT=\"$STORAGE_LIMIT\"" >> "$CONFIG_FILE"
  echo "NETWORK_LIMIT=\"$NETWORK_LIMIT\"" >> "$CONFIG_FILE"
  echo "BLOCK_PORTS=\"$BLOCK_PORTS\"" >> "$CONFIG_FILE"
  echo "PTERODACTYL_WINGS_PORTS=\"$PTERODACTYL_WINGS_PORTS\"" >> "$CONFIG_FILE"
  echo "PTERODACTYL_WINGS_INSTALL=\"$PTERODACTYL_WINGS_INSTALL\"" >> "$CONFIG_FILE"
  echo "Конфигурация завершена и сохранена в $CONFIG_FILE."
}

# Функция для создания файла конфигурации по умолчанию
create_default_config() {
  mkdir -p /root/pulsar_security

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "Создается файл конфигурации по умолчанию..."
    cat <<EOF >"$CONFIG_FILE"
DISCORD_WEBHOOK_URL=""
HOST_NAME=""
STORAGE_LIMIT=""
NETWORK_LIMIT=""
BLOCK_PORTS=""
PTERODACTYL_WINGS_PORTS=""
PTERODACTYL_WINGS_INSTALL=""
EOF
    echo "Файл конфигурации по умолчанию создан в $CONFIG_FILE"
  fi
}

# Функция для загрузки конфигурации из файла
load_configuration() {
  [ -f "$CONFIG_FILE" ] && . "$CONFIG_FILE"
}

# Функция настройки логов
setup_log_directory() {
  mkdir -p "$LOG_DIRECTORY"
}

# Функция обновления настроек Docker
update_docker_settings() {
  load_configuration
  SL="$STORAGE_LIMIT"
  NL=${NETWORK_LIMIT%.*}
  NL=$(echo "$NL" | awk '{print $1 "Mbit"}')
  echo "Устанавливаются ограничения для Docker-контейнеров..."
  for CU in $(docker ps -q); do
    docker update --storage-opt size="$SL" $CU
    docker exec $CU tc qdisc add dev eth0 root tbf rate "$NL" burst 10kbit latency 50ms
  done
  echo "Настройки Docker обновлены."
}

# Функция для разрешения портов Pterodactyl Wings
allow_pterodactyl_wings_ports() {
  load_configuration
  if [[ "$PTERODACTYL_WINGS_PORTS" =~ ^[0-9]+-[0-9]+$ ]]; then
    IFS='-' read -ra PR <<< "$PTERODACTYL_WINGS_PORTS"
    SP="${PR[0]}"
    EP="${PR[1]}"
    sudo ufw allow "$SP:$EP/tcp"
    sudo ufw allow "$SP:$EP/udp"
    echo "Разрешены порты $SP до $EP для Pterodactyl Wings (TCP и UDP)."
  else
    echo "Некорректный ввод портов Pterodactyl Wings. Укажите допустимый диапазон в формате 'начало-конец' (например, 5000-5999)."
  fi
}

# Функция для установки Pterodactyl Wings
install_pterodactyl_wings() {
  load_configuration
  if [[ "$PTERODACTYL_WINGS_INSTALL" =~ ^[Yy]$ ]]; then
    echo "Установка Pterodactyl Wings..." | tee -a "$LOG_FILE"
    bash <(curl -s https://pterodactyl-installer.se/) 2>&1 | tee -a "$LOG_FILE"
    echo "Установка Pterodactyl Wings завершена." | tee -a "$LOG_FILE"
  else
    echo "Установка Pterodactyl Wings пропущена. Вы можете выполнить ее вручную, когда будете готовы." | tee -a "$LOG_FILE"
  fi
}

# Функция для постоянного мониторинга загрузки CPU контейнеров
monitor_container_cpu_usage() {
  load_configuration
  while :; do
    stats=$(docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}")

    while read -r line; do
      container_name=$(echo "$line" | awk '{print $1}')
      cpu_usage=$(echo "$line" | awk '{gsub(/%/, "", $2); print $2}')

      if (( $(echo "$cpu_usage > 100" | bc -l) )); then
        echo "Обнаружена высокая загрузка CPU в контейнере: $container_name"
        message=":warning: Обнаружена высокая загрузка CPU в контейнере *$container_name* на хосте *$HOST_NAME*. Использование CPU: *$cpu_usage%*"
        curl -H "Content-Type: application/json" -d "{\"content\":\"$message\"}" "$DISCORD_WEBHOOK_URL"
      fi
    done <<< "$(echo "$stats" | tail -n +2)"

    sleep 60
  done
}

# Основной скрипт

# Устанавливаем конфигурацию
prompt_for_configuration
create_default_config
setup_log_directory
update_docker_settings
allow_pterodactyl_wings_ports
install_pterodactyl_wings

# Постоянный мониторинг нагрузки CPU в фоне
monitor_container_cpu_usage &
