#!/bin/bash

CONFIG_FILE="/root/pulsar_security/config.yml"
LOG_DIRECTORY="/root/pulsar_security/log"
LOG_FILE="$LOG_DIRECTORY/pulsar_security_script.log"

# Функция для автоматического определения доступного места на диске
auto_set_storage_limit() {
  local free_space_percentage=90 # Задаем процент от свободного места, который желаем оставить свободным
  local total_space
  total_space=$(df / | tail -n 1 | awk '{print $4}')
  total_space=$((total_space * 1024)) # Конвертируем в байты
  total_space=$((total_space * free_space_percentage / 100))
  STORAGE_LIMIT=${total_space}G
}

# Функция для тестирования скорости интернет-соединения
speed_test_and_set_network_limit() {
  echo "Выполняется тест скорости интернета..."
  local speedtest_result
  speedtest_result=$(speedtest-cli --simple)
  echo "Результаты теста скорости интернета:"
  echo "$speedtest_result"
  
  local download_speed=$(echo "$speedtest_result" | grep Download | awk '{print $2}')
  local upload_speed=$(echo "$speedtest_result" | grep Upload | awk '{print $2}')
  echo "Введите скорость соединения, на которую хотите ограничить каждый сервер, в mbps (например, введите $upload_speed, если хотите установить предел на уровне текущей скорости загрузки)."
  # Получение предела скорости сети от пользователя
  read -p "Скорость соединения в mbps: " NETWORK_LIMIT
}

# Функция для создания конфигурационного файла
create_config_file() {
  mkdir -p "$LOG_DIRECTORY" # Создаем каталог для логов, если он не существует
  echo "Создание конфигурационного файла..."
  cat <<EOF >"$CONFIG_FILE"
DISCORD_WEBHOOK_URL="$DISCORD_WEBHOOK_URL"
HOST_NAME="$HOST_NAME"
STORAGE_LIMIT="$STORAGE_LIMIT"
NETWORK_LIMIT="$NETWORK_LIMIT"
PTERODACTYL_WINGS_PORTS="$PTERODACTYL_WINGS_PORTS"
PTERODACTYL_WINGS_INSTALL="$PTERODACTYL_WINGS_INSTALL"
EOF
  echo "Конфигурация сохранена в файл $CONFIG_FILE."
}

# Запуск конфигурации подсистемы безопасности
setup_security_configuration() {
  auto_set_storage_limit
  speed_test_and_set_network_limit

  # Запрос у пользователя данных для конфигурации
  read -p "Введите URL вебхука Discord: " DISCORD_WEBHOOK_URL
  read -p "Введите имя вашего хоста: " HOST_NAME
  read -p "Введите диапазон портов, который вы хотите выделить для Pterodactyl Wings (например, 5000-6000): " PTERODACTYL_WINGS_PORTS
  read -p "Вы хотите сейчас установить Pterodactyl Wings? (Y/N): " PTERODACTYL_WINGS_INSTALL

  create_config_file # Создание и сохранение конфигурационного файла
}

# Функция для разрешения портов Pterodactyl Wings 
allow_pterodactyl_wings_ports() {
  if [ -n "$PTERODACTYL_WINGS_PORTS" ]; then
    if [[ "$PTERODACTYL_WINGS_PORTS" =~ ^[0-9]+-[0-9]+$ ]]; 
    then
      IFS='-' read -ra PORT_RANGE <<< "$PTERODACTYL_WINGS_PORTS"
      sudo ufw allow "${PORT_RANGE[0]}:${PORT_RANGE[1]}/tcp"
      sudo ufw allow "${PORT_RANGE[0]}:${PORT_RANGE[1]}/udp"
      echo "Порты с ${PORT_RANGE[0]} до ${PORT_RANGE[1]} разрешены для Pterodactyl Wings (TCP и UDP)."
    else
      echo "Неправильно задан диапазон портов для Pterodactyl Wings. Пожалуйста, введите допустимый диапазон в формате 'начало-конец' (например, 5000-5999)."
    fi
  else
    echo "Порты для Pterodactyl Wings не были указаны."
  fi
}

# Функция установки Pterodactyl Wings
install_pterodactyl_wings() {
  if [[ "$PTERODACTYL_WINGS_INSTALL" =~ ^[Yy]$ ]]; then
    echo "Установка Pterodactyl Wings начата..." | tee -a "$LOG_FILE"
    bash <(curl -s https://pterodactyl-installer.se/) | tee -a "$LOG_FILE"
    echo "Установка Pterodactyl Wings завершена." | tee -a "$LOG_FILE"
  else
    echo "Установка Pterodactyl Wings пропущена. Вы можете запустить её вручную, когда будете готовы." | tee -a "$LOG_FILE"
  fi
}

# Главная программа

# Установить пакет bc, если он не установлен
if ! command -v bc &> /dev/null; then
    sudo apt update && sudo apt install bc -y
fi

# Настройка конфигураций
setup_security_configuration
allow_pterodactyl_wings_ports
install_pterodactyl_wings
