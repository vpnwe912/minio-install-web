#!/bin/bash
set -e

echo "==== Update system ===="
sudo apt update && sudo apt upgrade -y

echo "==== Install utils ===="
sudo apt install -y curl sudo git wget unzip software-properties-common lsb-release ca-certificates apt-transport-https

echo "==== Add PHP 8.3 repository ===="
sudo apt install -y lsb-release ca-certificates apt-transport-https wget
sudo wget -O /etc/apt/trusted.gpg.d/sury.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/sury-php.list
sudo apt update

echo "==== Install PHP 8.3 and extensions ===="
sudo apt install -y php8.3 php8.3-cli php8.3-fpm php8.3-mysql php8.3-curl php8.3-xml php8.3-mbstring php8.3-zip php8.3-gd php8.3-intl php8.3-bcmath php8.3-soap php8.3-redis php8.3-ldap

echo "==== Install MariaDB ===="
sudo apt install -y mariadb-server

echo "==== Start and enable MariaDB ===="
sudo systemctl enable mariadb
sudo systemctl start mariadb

echo "==== Install nginx ===="
sudo apt install -y nginx

echo "==== Install Certbot ===="
sudo apt install -y certbot python3-certbot-nginx

echo "==== Install Composer ===="
EXPECTED_SIGNATURE="$(wget -q -O - https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384', 'composer-setup.php');")"
if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]
then
    echo 'Error: Invalid Composer signature'
    rm composer-setup.php
    exit 1
fi
php composer-setup.php --install-dir=/usr/local/bin --filename=composer
rm composer-setup.php

echo "==== Check Composer ===="
export COMPOSER_ALLOW_SUPERUSER=1
echo "Composer version: $(composer --version)"

echo "==== Add nginx and php-fpm to autostart and start ===="
sudo systemctl enable nginx
sudo systemctl start nginx
sudo systemctl enable php8.3-fpm
sudo systemctl start php8.3-fpm



echo "==== Создание базы данных minio_manager с кодировкой utf8mb4 ===="
read -p "Введите название базы данных [minio_manager]: " DATABASE_NAME
DATABASE_NAME=${DATABASE_NAME:-minio_manager}
read -p "Введите имя пользователя базы данных [minio_user]: " DATABASE_USER
DATABASE_USER=${DATABASE_USER:-minio_user}
read -s -p "Введите пароль пользователя базы данных [minio_pass]: " DATABASE_PASSWORD
echo
DATABASE_PASSWORD=${DATABASE_PASSWORD:-minio_pass}

sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DATABASE_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DATABASE_USER}'@'localhost' IDENTIFIED BY '${DATABASE_PASSWORD}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DATABASE_NAME}\`.* TO '${DATABASE_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
echo "==== MariaDB и база данных ${DATABASE_NAME} успешно созданы! ===="



echo "==== All dependencies installed! ===="
echo "PHP version: $(php -v | head -n 1)"
echo "MariaDB version: $(mariadb --version)"
echo "Nginx version: $(nginx -v 2>&1)"
echo "Composer version: $(composer --version)"
echo "============================="


echo "==== Создание директории для проекта ===="
mkdir -p /var/www/web-minio
chown -R www-data:www-data /var/www/web-minio
chmod -R 775 /var/www/web-minio

sudo -u www-data git clone git@github.com:vpnwe912/nas_minio_s3_storage.git /var/www/web-minio

sudo -u www-data cp /var/www/web-minio/.env.example /var/www/web-minio/.env

# --- Запись переменных в .env ---
ENV_FILE="/var/www/web-minio/.env"

echo "==== Название проекта ===="
read -p "Введите название проекта [MinIO S3 Storage]: " APP_NAME
APP_NAME=${APP_NAME:-MinIO S3 Storage}
read -p "Введите короткое название проекта [MinIO S3]: " APP_SHORT
APP_SHORT=${APP_SHORT:-MinIO S3}
read -p "Введите email администратора [admin@example.com]: " ADMIN_EMAIL
ADMIN_EMAIL=${ADMIN_EMAIL:-admin@example.com}


echo "==== Подключение к GitHub для загрузки бинарных файлов ===="
read -p "Введите GITHUB_USER: " GITHUB_USER
GITHUB_USER=${GITHUB_USER:-vpnwe912}
read -p "Введите GITHUB_REPO: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-nas_minio_s3_storage}
read -p "Введите GITHUB_TAG: " GITHUB_TAG
GITHUB_TAG=${GITHUB_TAG:-v1.0.0}
read -p "Введите GITHUB_TOKEN (можно оставить пустым): " GITHUB_TOKEN

set_env_var() {
    VAR_NAME="$1"
    VAR_VALUE="$2"
    if grep -q "^${VAR_NAME}=" "$ENV_FILE"; then
        sed -i "s|^${VAR_NAME}=.*|${VAR_NAME}=${VAR_VALUE}|" "$ENV_FILE"
    else
        echo "${VAR_NAME}=${VAR_VALUE}" >> "$ENV_FILE"
    fi
}

set_env_var "DB_NAME" "$DATABASE_NAME"
set_env_var "DB_USER" "$DATABASE_USER"
set_env_var "DB_PASS" "$DATABASE_PASSWORD"
set_env_var "APP_NAME" "$APP_NAME"
set_env_var "APP_SHORT" "$APP_SHORT"
set_env_var "ADMIN_EMAIL" "$ADMIN_EMAIL"
set_env_var "GITHUB_TOKEN" "$GITHUB_TOKEN"
set_env_var "GITHUB_USER" "$GITHUB_USER"
set_env_var "GITHUB_REPO" "$GITHUB_REPO"
set_env_var "GITHUB_TAG" "$GITHUB_TAG"


echo "Данные успешно записаны в .env:"
grep "^DB_" "$ENV_FILE"
grep "^APP_NAME" "$ENV_FILE"
grep "^APP_SHORT" "$ENV_FILE"
grep "^ADMIN_EMAIL" "$ENV_FILE"
grep "^GITHUB_TOKEN" "$ENV_FILE"
grep "^GITHUB_USER" "$ENV_FILE"
grep "^GITHUB_REPO" "$ENV_FILE"
grep "^GITHUB_TAG" "$ENV_FILE"




sudo -u www-data composer install --working-dir=/var/www/web-minio -vvv
sudo -u www-data php /var/www/web-minio/yii migrate --interactive=0
sudo -u www-data php /var/www/web-minio/yii binaries/download-all



sudo apt update && sudo apt upgrade -y


echo "==== Install MinIO Server ===="
echo "1) Download MinIO from official site"
echo "2) Copy MinIO from project (locally)"
read -p "Select installation method [1/2, default 2]: " INSTALL_TYPE
INSTALL_TYPE=${INSTALL_TYPE:-2}

if [ "$INSTALL_TYPE" = "1" ]; then
    echo "Downloading MinIO from official site..."
    wget -O /tmp/minio https://dl.min.io/server/minio/release/linux-amd64/minio
    sudo cp /tmp/minio /usr/local/bin/minio
elif [ "$INSTALL_TYPE" = "2" ]; then
    echo "Copying MinIO from project..."
    sudo cp /var/www/web-minio/download/minio-server-debian/minio /usr/local/bin/minio
else
    echo "Invalid selection, installation aborted."
    exit 1
fi


sudo chmod +x /usr/local/bin/minio

echo "==== Create a MinIO user ===="
read -p "Введите имя пользователя для MinIO [minio-user]: " MINIO_USER
MINIO_USER=${MINIO_USER:-minio-user}

sudo useradd -r $MINIO_USER -s /sbin/nologin
sudo mkdir -p /home/$MINIO_USER
sudo chown $MINIO_USER:$MINIO_USER /home/$MINIO_USER

echo "==== Set up directories for MinIO ===="
read -p "Введите директорию для MinIO [/data]: " MINIO_DIR
MINIO_DIR=${MINIO_DIR:-/data}

sudo mkdir -p $MINIO_DIR
sudo chown $MINIO_USER:$MINIO_USER $MINIO_DIR

MINIO_SERVICE="/etc/systemd/system/minio.service"
sudo tee $MINIO_SERVICE > /dev/null <<EOF
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
EOF


read -p "Введите имя пользователя для MinIO [minioadmin]: " MINIO_ADMIN_USER
MINIO_ADMIN_USER=${MINIO_ADMIN_USER:-minioadmin}

read -p "Введите пароль для MinIO [minioadminpassword]: " MINIO_ADMIN_PASSWORD
MINIO_ADMIN_PASSWORD=${MINIO_ADMIN_PASSWORD:-minioadminpassword}

DEFAULT_MINIO_SERVICE="/etc/default/minio"
sudo tee $DEFAULT_MINIO_SERVICE > /dev/null <<EOF
MINIO_ROOT_USER=$MINIO_ADMIN_USER
MINIO_ROOT_PASSWORD=$MINIO_ADMIN_PASSWORD
EOF

sudo systemctl daemon-reload
sudo systemctl start minio
sudo systemctl enable --now minio



echo
echo "==== Установка MinIO Client (mc) ===="
echo "1) Скачать MinIO Client с официального сайта"
echo "2) Копировать MinIO Client из проекта (локально)"
read -p "Выберите способ установки MinIO Client [1/2, по умолчанию 1]: " MC_INSTALL_TYPE
MC_INSTALL_TYPE=${MC_INSTALL_TYPE:-1}

if [ "$MC_INSTALL_TYPE" = "1" ]; then
    echo "Скачивание MinIO Client с официального сайта..."
    wget -O /tmp/mc https://dl.min.io/client/mc/release/linux-amd64/mc
    sudo cp /tmp/mc /usr/local/bin/mc
elif [ "$MC_INSTALL_TYPE" = "2" ]; then
    echo "Копирование MinIO Client из проекта..."
    sudo cp /var/www/web-minio/download/minio-client-debian/mc /usr/local/bin/mc
else
    echo "Неверный выбор, установка прервана."
    exit 1
fi
sudo chmod +x /usr/local/bin/mc

ALIAS_NAME="local"
mc alias set $ALIAS_NAME http://127.0.0.1:9000 $MINIO_ADMIN_USER $MINIO_ADMIN_PASSWORD


# --- Запись переменных в .env ---
ENV_FILE="/var/www/web-minio/.env"

read -p "Введите MINIO_HOST: " MINIO_HOST
MINIO_HOST=${MINIO_HOST:-http://127.0.0.1:9000}

read -p "Введите MINIO_KEY: " MINIO_KEY
MINIO_KEY=${MINIO_KEY:-minioadmin}

read -p "Введите MINIO_SECRET: " MINIO_SECRET
MINIO_SECRET=${MINIO_SECRET:-minioadminpassword}

read -p "Введите MINIO_ALIAS: " MINIO_ALIAS
MINIO_ALIAS=${MINIO_ALIAS:-local}



set_env_var() {
    VAR_NAME="$1"
    VAR_VALUE="$2"
    if grep -q "^${VAR_NAME}=" "$ENV_FILE"; then
        sed -i "s|^${VAR_NAME}=.*|${VAR_NAME}=${VAR_VALUE}|" "$ENV_FILE"
    else
        echo "${VAR_NAME}=${VAR_VALUE}" >> "$ENV_FILE"
    fi
}

set_env_var "MINIO_HOST" "$MINIO_HOST"
set_env_var "MINIO_KEY" "$MINIO_KEY"
set_env_var "MINIO_SECRET" "$MINIO_SECRET"
set_env_var "MINIO_ALIAS" "$MINIO_ALIAS"


echo "Данные успешно записаны в .env:"
grep "^MINIO_" "$ENV_FILE"


# === Ввод домена и настройка nginx ===
read -p "Введите доменное имя для сайта (например, site.com): " DOMAIN
DOMAIN=${DOMAIN:-web-minio.gepur.org}

# Определяем путь к проекту (где лежит install.sh)
PROJECT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Создаём конфиг nginx для $DOMAIN"

NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"
sudo tee $NGINX_CONF > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $PROJECT_PATH/web;
    index index.php index.html;

    access_log /var/log/nginx/${DOMAIN}_access.log;
    error_log  /var/log/nginx/${DOMAIN}_error.log;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)\$ {
        expires max;
        log_not_found off;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

# Активируем сайт
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/$DOMAIN

# Проверяем конфиг и перезапускаем nginx
sudo nginx -t && sudo systemctl reload nginx

echo "Nginx сайт для $DOMAIN создан и активирован."

# === Установка SSL сертификата через certbot ===
echo "Запускаем Certbot для $DOMAIN"
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "Let's Encrypt сертификат установлен для $DOMAIN"

echo "=== Всё готово! Nginx + SSL для $DOMAIN ==="



