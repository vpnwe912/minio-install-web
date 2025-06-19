#!/bin/bash
set -e

if ! command -v dialog &>/dev/null; then
    echo "Dialog not found. Installing..."
    if [ -f /etc/debian_version ]; then
        sudo apt update && sudo apt install -y dialog
    elif [ -f /etc/redhat-release ]; then
        sudo yum install -y dialog
    else
        echo "Unable to determine system type. Please install 'dialog' manually!"
        exit 1
    fi
fi

HEIGHT=15
WIDTH=70

confirm_exit() {
    dialog --ascii-lines --yesno "Выйти из установки?" 8 50
    case $? in
        0) clear; echo "Установка отменена."; exit 1;;
        1) return 1;;
    esac
}

db_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "Параметры базы данных:" 15 70 3 \
            "DB_NAME:"     1 1 "${DB_NAME:-minio_manager}"   1 30 30 100 \
            "DB_USER:"     2 1 "${DB_USER:-minio_user}"      2 30 30 100 \
            "DB_PASS:"     3 1 "${DB_PASS:-minio_pass}"      3 30 30 100 \
            3>&1 1>&2 2>&3)
        ret=$?
        clear
        if [ $ret -eq 1 ]; then confirm_exit || continue; fi
        DB_NAME=$(echo "$result" | sed -n 1p)
        DB_USER=$(echo "$result" | sed -n 2p)
        DB_PASS=$(echo "$result" | sed -n 3p)
        [ -n "$DB_NAME" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASS" ] && break
    done
}

project_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "Параметры проекта:" 15 70 3 \
            "APP_NAME:"    1 1 "${APP_NAME:-MinIO S3 Storage}"     1 30 30 100 \
            "APP_SHORT:"   2 1 "${APP_SHORT:-MinIO S3}"            2 30 30 100 \
            "ADMIN_EMAIL:" 3 1 "${ADMIN_EMAIL:-admin@example.com}" 3 30 30 100 \
            3>&1 1>&2 2>&3)
        ret=$?
        clear
        if [ $ret -eq 1 ]; then confirm_exit || continue; fi
        APP_NAME=$(echo "$result" | sed -n 1p)
        APP_SHORT=$(echo "$result" | sed -n 2p)
        ADMIN_EMAIL=$(echo "$result" | sed -n 3p)
        [ -n "$APP_NAME" ] && [ -n "$APP_SHORT" ] && [ -n "$ADMIN_EMAIL" ] && break
    done
}

github_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "Данные GitHub:" 15 70 4 \
            "GITHUB_USER:" 1 1 "${GITHUB_USER:-vpnwe912}"           1 30 30 100 \
            "GITHUB_REPO:" 2 1 "${GITHUB_REPO:-nas_minio_s3_storage}" 2 30 30 100 \
            "GITHUB_TAG:"  3 1 "${GITHUB_TAG:-v1.0.0}"               3 30 30 100 \
            "GITHUB_TOKEN:" 4 1 "${GITHUB_TOKEN:-}"                  4 30 30 100 \
            3>&1 1>&2 2>&3)
        ret=$?
        clear
        if [ $ret -eq 1 ]; then confirm_exit || continue; fi
        GITHUB_USER=$(echo "$result" | sed -n 1p)
        GITHUB_REPO=$(echo "$result" | sed -n 2p)
        GITHUB_TAG=$(echo "$result" | sed -n 3p)
        GITHUB_TOKEN=$(echo "$result" | sed -n 4p)
        [ -n "$GITHUB_USER" ] && [ -n "$GITHUB_REPO" ] && [ -n "$GITHUB_TAG" ] && break
    done
}

minio_server_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "Параметры MinIO Server:" 20 70 5 \
            "INSTALL_TYPE (1=официально/2=локально):" 1 1 "${INSTALL_TYPE:-2}"        1 40 20 100 \
            "MINIO_USER:"       2 1 "${MINIO_USER:-minio-user}"            2 40 20 100 \
            "MINIO_DIR:"        3 1 "${MINIO_DIR:-/data}"                  3 40 20 100 \
            "MINIO_ADMIN_USER:" 4 1 "${MINIO_ADMIN_USER:-minioadmin}"      4 40 20 100 \
            "MINIO_ADMIN_PASSWORD:" 5 1 "${MINIO_ADMIN_PASSWORD:-minioadminpassword}" 5 40 20 100 \
            3>&1 1>&2 2>&3)
        ret=$?
        clear
        if [ $ret -eq 1 ]; then confirm_exit || continue; fi
        INSTALL_TYPE=$(echo "$result" | sed -n 1p)
        MINIO_USER=$(echo "$result" | sed -n 2p)
        MINIO_DIR=$(echo "$result" | sed -n 3p)
        MINIO_ADMIN_USER=$(echo "$result" | sed -n 4p)
        MINIO_ADMIN_PASSWORD=$(echo "$result" | sed -n 5p)
        break
    done
}

minio_client_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "Параметры MinIO Client:" 20 70 5 \
            "MC_INSTALL_TYPE (1=официально/2=локально):" 1 1 "${MC_INSTALL_TYPE:-1}" 1 40 20 100 \
            "MINIO_HOST:"        2 1 "${MINIO_HOST:-http://127.0.0.1:9000}"   2 40 30 100 \
            "MINIO_KEY:"         3 1 "${MINIO_KEY:-minioadmin}"               3 40 20 100 \
            "MINIO_SECRET:"      4 1 "${MINIO_SECRET:-minioadminpassword}"    4 40 20 100 \
            "MINIO_ALIAS:"       5 1 "${MINIO_ALIAS:-local}"                  5 40 20 100 \
            3>&1 1>&2 2>&3)
        ret=$?
        clear
        if [ $ret -eq 1 ]; then confirm_exit || continue; fi
        MC_INSTALL_TYPE=$(echo "$result" | sed -n 1p)
        MINIO_HOST=$(echo "$result" | sed -n 2p)
        MINIO_KEY=$(echo "$result" | sed -n 3p)
        MINIO_SECRET=$(echo "$result" | sed -n 4p)
        MINIO_ALIAS=$(echo "$result" | sed -n 5p)
        break
    done
}

# === Диалоговые мастеры ===
db_settings
project_settings
github_settings
minio_server_settings
minio_client_settings

# === Прогресс-бар установки ===
{
    echo "5"; echo "# Обновление системы..."; sudo apt update -y &>/dev/null && sudo apt upgrade -y &>/dev/null
    echo "10"; echo "# Установка утилит..."; sudo apt install -y curl sudo git wget unzip software-properties-common lsb-release ca-certificates apt-transport-https &>/dev/null
    echo "15"; echo "# Добавление PHP 8.3 репозитория..."; sudo apt install -y lsb-release ca-certificates apt-transport-https wget &>/dev/null; sudo wget -O /etc/apt/trusted.gpg.d/sury.gpg https://packages.sury.org/php/apt.gpg &>/dev/null
    echo "20"; echo "# Установка PHP и расширений..."; sudo apt update &>/dev/null; sudo apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-curl php8.3-xml php8.3-mbstring php8.3-zip php8.3-gd php8.3-intl php8.3-bcmath php8.3-soap php8.3-redis php8.3-ldap &>/dev/null
    echo "25"; echo "# Установка MariaDB..."; sudo apt install -y mariadb-server &>/dev/null
    echo "30"; echo "# Запуск MariaDB..."; sudo systemctl enable mariadb &>/dev/null && sudo systemctl start mariadb &>/dev/null
    echo "35"; echo "# Установка nginx..."; sudo apt install -y nginx &>/dev/null
    echo "40"; echo "# Установка Certbot..."; sudo apt install -y certbot python3-certbot-nginx &>/dev/null
    echo "45"; echo "# Установка Composer..."; EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"; php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"; ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"; if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then echo 'Composer signature invalid'; rm composer-setup.php; exit 1; fi; php composer-setup.php --install-dir=/usr/local/bin --filename=composer &>/dev/null; rm composer-setup.php
    echo "50"; echo "# Включение nginx и php-fpm..."; sudo systemctl enable nginx &>/dev/null; sudo systemctl start nginx &>/dev/null; sudo systemctl enable php8.3-fpm &>/dev/null; sudo systemctl start php8.3-fpm &>/dev/null
    echo "55"; echo "# Создание базы данных..."; sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"; sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"; sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"; sudo mysql -e "FLUSH PRIVILEGES;"
    echo "60"; echo "# Клонирование проекта..."; mkdir -p /var/www/web-minio; chown -R www-data:www-data /var/www/web-minio; chmod -R 775 /var/www/web-minio; if [ ! -d "/var/www/web-minio/.git" ]; then sudo -u www-data git clone "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" /var/www/web-minio; fi; sudo -u www-data cp /var/www/web-minio/.env.example /var/www/web-minio/.env
    echo "65"; echo "# Composer install, миграции..."; sudo -u www-data composer install --working-dir=/var/www/web-minio -vvv &>/dev/null; sudo -u www-data php /var/www/web-minio/yii migrate --interactive=0 &>/dev/null; sudo -u www-data php /var/www/web-minio/yii binaries/download-all &>/dev/null
    echo "70"; echo "# Установка MinIO Server..."; if [ "$INSTALL_TYPE" = "1" ]; then wget -O /tmp/minio https://dl.min.io/server/minio/release/linux-amd64/minio &>/dev/null; sudo cp /tmp/minio /usr/local/bin/minio; else sudo cp /var/www/web-minio/downloads/minio-server-debian/minio /usr/local/bin/minio; fi; sudo chmod +x /usr/local/bin/minio
    echo "75"; echo "# Создание пользователя/директории MinIO..."; sudo useradd -r $MINIO_USER -s /sbin/nologin || true; sudo mkdir -p /home/$MINIO_USER; sudo chown $MINIO_USER:$MINIO_USER /home/$MINIO_USER; sudo mkdir -p $MINIO_DIR; sudo chown $MINIO_USER:$MINIO_USER $MINIO_DIR
    echo "80"; echo "# Конфигурирование systemd MinIO..."; MINIO_SERVICE="/etc/systemd/system/minio.service"; sudo tee $MINIO_SERVICE > /dev/null <<EOF2
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target
[Service]
User=$MINIO_USER
Group=$MINIO_USER
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server $MINIO_DIR
Restart=on-failure
RestartSec=5
LimitNOFILE=262144
[Install]
WantedBy=multi-user.target
EOF2
    DEFAULT_MINIO_SERVICE="/etc/default/minio"; sudo tee $DEFAULT_MINIO_SERVICE > /dev/null <<EOF2
MINIO_ROOT_USER=$MINIO_ADMIN_USER
MINIO_ROOT_PASSWORD=$MINIO_ADMIN_PASSWORD
EOF2
    sudo systemctl daemon-reload; sudo systemctl start minio; sudo systemctl enable --now minio
    echo "85"; echo "# Установка MinIO Client..."; if [ "$MC_INSTALL_TYPE" = "1" ]; then wget -O /tmp/mc https://dl.min.io/client/mc/release/linux-amd64/mc &>/dev/null; sudo cp /tmp/mc /usr/local/bin/mc; else sudo cp /var/www/web-minio/downloads/minio-client-debian/mc /usr/local/bin/mc; fi; sudo chmod +x /usr/local/bin/mc
    echo "90"; echo "# Конфигурирование mc..."; mc alias set $MINIO_ALIAS $MINIO_HOST $MINIO_KEY $MINIO_SECRET &>/dev/null
    echo "92"; echo "# Настройка nginx..."; DOMAIN="web-minio.gepur.org"; PROJECT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"; NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"; sudo tee $NGINX_CONF > /dev/null <<EOF2
server {
    listen 80;
    server_name $DOMAIN;
    root $PROJECT_PATH/web;
    index index.php index.html;
    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log  /var/log/nginx/${DOMAIN}_error.log;
    location / { try_files \$uri \$uri/ /index.php?\$args; }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ { expires max; log_not_found off; }
    location ~ /\.ht { deny all; }
}
EOF2
    sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/$DOMAIN; sudo nginx -t && sudo systemctl reload nginx
    echo "95"; echo "# Сертификат Let's Encrypt..."; sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN &>/dev/null
    echo "98"; echo "# Запись .env..."; ENV_FILE="/var/www/web-minio/.env"; set_env_var() { VAR_NAME="$1"; VAR_VALUE="$2"; if [[ "$VAR_VALUE" =~ [[:space:]] ]]; then VAR_VALUE="\"$VAR_VALUE\""; fi; if grep -q "^${VAR_NAME}=" "$ENV_FILE" 2>/dev/null; then sed -i "s|^${VAR_NAME}=.*|${VAR_NAME}=${VAR_VALUE}|" "$ENV_FILE"; else echo "${VAR_NAME}=${VAR_VALUE}" >> "$ENV_FILE"; fi; }
    set_env_var "DB_NAME" "$DB_NAME"
    set_env_var "DB_USER" "$DB_USER"
    set_env_var "DB_PASS" "$DB_PASS"
    set_env_var "APP_NAME" "$APP_NAME"
    set_env_var "APP_SHORT" "$APP_SHORT"
    set_env_var "ADMIN_EMAIL" "$ADMIN_EMAIL"
    set_env_var "GITHUB_USER" "$GITHUB_USER"
    set_env_var "GITHUB_REPO" "$GITHUB_REPO"
    set_env_var "GITHUB_TAG" "$GITHUB_TAG"
    set_env_var "GITHUB_TOKEN" "$GITHUB_TOKEN"
    set_env_var "MINIO_HOST" "$MINIO_HOST"
    set_env_var "MINIO_KEY" "$MINIO_KEY"
    set_env_var "MINIO_SECRET" "$MINIO_SECRET"
    set_env_var "MINIO_ALIAS" "$MINIO_ALIAS"
    echo "100"; echo "# Готово!"; sleep 1
} | dialog --ascii-lines --title "MinIO S3 Storage Installation" --gauge "Выполняется установка..." 15 70 0

clear
echo -e "\e[32mУстановка завершена!\e[0m"
