# PteroShield - защита крыльев птеродактиля.

Installer:
```
curl -o pteroshield_setup.sh https://raw.githubusercontent.com/IkdanYT/pteroshield/main/setup.sh
chmod +x pteroshield_setup.sh
./pteroshield_setup.sh
```
Remover:
```
curl -o pteroshield_remover.sh https://raw.githubusercontent.com/IkdanYT/pteroshield/main/remover.sh
chmod +x pteroshield_remover.sh
./pteroshield_remover.sh
```

Вы предоставляете услуги бесплатного хостинга Minecraft? Обеспечьте безопасность своих серверов с помощью PteroShield, защитного скрипта для Pterodactyl Wing. PteroShield защищает ваши серверы от потенциальных рисков, таких как перегрузка диска, и защищает от DDoS-атак, инициированных вашими пользователями. Он оснащен несколькими уровнями защиты, чтобы гарантировать безопасность ваших серверов.

## Этот скрипт защищает ваш хост от:

- **DDoS-атак**: (включая узлы, используемые для DDoS-атаки).
- **Заполнение диска**: (ограничено 100 ГБ).
- **Предотвращение майнинга биткоинов**: Этот скрипт включает меры по предотвращению майнинга биткоинов. Вы можете вручную настроить триггер CPU для приостановки в файле `/root/pulsar_security/config.yml`.

## Особенности

- **Конфигурация**: Все параметры можно удобно настроить в файле `/root/pulsar_security/config.yml`.
- **Автообновление**: PteroShield автоматически обновляется ежедневно, защищая все узлы от уязвимостей, эксплойтов и обеспечивая дополнительные уровни безопасности.
 - **Установка крыльев птеродактиля**: После завершения установки скрипта [PteroShield предложит вам установить крылья птеродактиля](https://github.com/pterodactyl-installer/pterodactyl-installer).
