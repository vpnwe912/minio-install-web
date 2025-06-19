#!/bin/bash
set -e

# --- Проверка наличия dialog ---
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
    dialog --ascii-lines --yesno "Exit installation?" 8 50
    case $? in
        0) clear; echo "Installation canceled."; exit 1;;
        1) return 1;;
    esac
}

# === 1. Basic installation wizard ===

## 1.1. Step 1. Database settings
db_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "Database settings:" 15 70 3 \
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

## 1.2. Step 2. Project settings
project_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "Project settings:" 15 70 3 \
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

## 1.3. Step 3. GitHub settings
github_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "GitHub settings:" 15 70 4 \
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

## 1.4. Step 4. MinIO Server settings
minio_server_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "MinIO Server settings:" 20 70 5 \
            "INSTALL_TYPE (1=official/2=local):" 1 1 "${INSTALL_TYPE:-2}"        1 40 20 100 \
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

## 1.5. Step 5. MinIO Client settings
minio_client_settings() {
    while true; do
        result=$(dialog --ascii-lines --form "MinIO Client settings:" 20 70 5 \
            "MC_INSTALL_TYPE (1=official/2=local):" 1 1 "${MC_INSTALL_TYPE:-1}" 1 40 20 100 \
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

# === 2. All master steps ===

db_settings
project_settings
github_settings
minio_server_settings
minio_client_settings

# === 3. Full installation of software and environment ===

dialog --ascii-lines --title "MinIO S3 Storage Installation" --infobox \
"Installing all dependencies and system configuration. Please wait, the process is in progress..." 7 60
sleep 2

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
if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
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

echo "==== Creating database $DB_NAME ===="
sudo mysql -e "CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"
echo "==== MariaDB and database ${DB_NAME} successfully created! ===="

echo "==== All dependencies installed! ===="
echo "PHP version: $(php -v | head -n 1)"
echo "MariaDB version: $(mariadb --version)"
echo "Nginx version: $(nginx -v 2>&1)"
echo "Composer version: $(composer --version)"
echo "============================="

echo "==== Creating directory for project ===="
mkdir -p /var/www/web-minio
chown -R www-data:www-data /var/www/web-minio
chmod -R 775 /var/www/web-minio

if [ ! -d "/var/www/web-minio/.git" ]; then
    sudo -u www-data git clone "https://github.com/${GITHUB_USER}/${GITHUB_REPO}.git" /var/www/web-minio
fi

sudo -u www-data cp /var/www/web-minio/.env.example /var/www/web-minio/.env

# --- composer install, migrations, download binaries ---
sudo -u www-data composer install --working-dir=/var/www/web-minio -vvv
sudo -u www-data php /var/www/web-minio/yii migrate --interactive=0
sudo -u www-data php /var/www/web-minio/yii binaries/download-all

# === MinIO Server installation ===
if [ "$INSTALL_TYPE" = "1" ]; then
    wget -O /tmp/minio https://dl.min.io/server/minio/release/linux-amd64/minio
    sudo cp /tmp/minio /usr/local/bin/minio
elif [ "$INSTALL_TYPE" = "2" ]; then
    sudo cp /var/www/web-minio/downloads/minio-server-debian/minio /usr/local/bin/minio
else
    echo "Invalid selection, installation aborted."
    exit 1
fi
sudo chmod +x /usr/local/bin/minio

# === MinIO user and directory creation ===
sudo useradd -r $MINIO_USER -s /sbin/nologin || true
sudo mkdir -p /home/$MINIO_USER
sudo chown $MINIO_USER:$MINIO_USER /home/$MINIO_USER
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

DEFAULT_MINIO_SERVICE="/etc/default/minio"
sudo tee $DEFAULT_MINIO_SERVICE > /dev/null <<EOF
MINIO_ROOT_USER=$MINIO_ADMIN_USER
MINIO_ROOT_PASSWORD=$MINIO_ADMIN_PASSWORD
EOF

sudo systemctl daemon-reload
sudo systemctl start minio
sudo systemctl enable --now minio

# === MinIO Client (mc) installation ===
if [ "$MC_INSTALL_TYPE" = "1" ]; then
    wget -O /tmp/mc https://dl.min.io/client/mc/release/linux-amd64/mc
    sudo cp /tmp/mc /usr/local/bin/mc
elif [ "$MC_INSTALL_TYPE" = "2" ]; then
    sudo cp /var/www/web-minio/downloads/minio-client-debian/mc /usr/local/bin/mc
else
    echo "Invalid selection, installation aborted."
    exit 1
fi
sudo chmod +x /usr/local/bin/mc

ALIAS_NAME="${MINIO_ALIAS:-local}"
mc alias set $ALIAS_NAME $MINIO_HOST $MINIO_KEY $MINIO_SECRET

# === Domain input and nginx configuration ===
DOMAIN=$(dialog --ascii-lines --inputbox "Enter domain name for site (e.g., site.com):" 8 50 "web-minio.gepur.org" 3>&1 1>&2 2>&3)
PROJECT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
sudo ln -sf $NGINX_CONF /etc/nginx/sites-enabled/$DOMAIN
sudo nginx -t && sudo systemctl reload nginx

sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos -m admin@$DOMAIN

echo "Let's Encrypt certificate installed for $DOMAIN"

# === .env writing only at the end ===

ENV_FILE="/var/www/web-minio/.env"
set_env_var() {
    VAR_NAME="$1"
    VAR_VALUE="$2"
    if [[ "$VAR_VALUE" =~ [[:space:]] ]]; then
        VAR_VALUE="\"$VAR_VALUE\""
    fi
    if grep -q "^${VAR_NAME}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${VAR_NAME}=.*|${VAR_NAME}=${VAR_VALUE}|" "$ENV_FILE"
    else
        echo "${VAR_NAME}=${VAR_VALUE}" >> "$ENV_FILE"
    fi
}

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

echo
echo "Data successfully written to .env:"
grep -E "^(DB_|APP_|ADMIN_EMAIL|GITHUB_|MINIO_)" "$ENV_FILE"

clear
echo -e "\e[32mInstallation completed!\e[0m"
