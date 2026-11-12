#!/usr/bin/env bash
# start.sh — menjalankan MariaDB, 5 PHP-FPM, dan Nginx di background.
set -u
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
load_env

echo "[Starting MyDevEnv-mac]"

# --- Nginx webroot & default PHP dari .env ---
WEBROOT="$(webroot_abs)"
echo "root ${WEBROOT};" > "$ROOT/conf/nginx/webroot.conf"

case "$DEFAULT_PHP_VERSION" in
    5.6|7.4|8.2|8.3|8.4) FPORT="${FPM_PORT[$DEFAULT_PHP_VERSION]}" ;;
    *) echo "[ERROR] DEFAULT_PHP_VERSION tidak valid: $DEFAULT_PHP_VERSION"; exit 1 ;;
esac
echo "fastcgi_pass 127.0.0.1:${FPORT};" > "$ROOT/conf/nginx/default_php.conf"
echo "Default PHP di Port 8080: $DEFAULT_PHP_VERSION (fastcgi 127.0.0.1:$FPORT)"
echo "Web root: $WEBROOT"

# --- 1. MariaDB ---
echo "1. MariaDB ..."
if pid_running "$ROOT/logs/mysqld.pid"; then
    echo "   sudah berjalan (pid $(cat "$ROOT/logs/mysqld.pid"))"
else
    nohup "$(mdb_bin_dir)/mariadbd" \
        --no-defaults \
        --basedir="$(mdb_prefix)" \
        --datadir="$(mdb_data_dir)" \
        --socket="$(mdb_socket)" \
        --pid-file="$ROOT/logs/mysqld.pid" \
        --port="${MARIADB_PORT}" \
        --log-error="$ROOT/logs/mariadb.error.log" \
        >> "$ROOT/logs/mariadb.stdout.log" 2>&1 &
    # tunggu sampai siap (maks ~15 detik)
    for i in $(seq 1 30); do
        if "$(mdb_bin_dir)/mariadb" --socket="$(mdb_socket)" -u root -e "SELECT 1" >/dev/null 2>&1; then break; fi
        sleep 0.5
    done
    # set password root bila root masih tanpa password (dinamis, sekali jalan)
    if "$(mdb_bin_dir)/mariadb" --socket="$(mdb_socket)" -u root -e "SELECT 1" >/dev/null 2>&1 \
        && [ -n "$MARIADB_ROOT_PASSWORD" ]; then
        "$(mdb_bin_dir)/mariadb" --socket="$(mdb_socket)" -u root \
            -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MARIADB_ROOT_PASSWORD}'); FLUSH PRIVILEGES;" \
            >/dev/null 2>&1 || true
    fi
fi

# --- 2. PHP-FPM per versi ---
echo "2. PHP-FPM FastCGI ..."
for ver in "${PHP_VERSIONS[@]}"; do
    fport="${FPM_PORT[$ver]}"
    conf="$ROOT/conf/php-fpm/php${ver//./}.conf"
    etc="$(php_etc_dir "$ver")"
    if pid_running "$ROOT/logs/php${ver//./}.pid"; then
        echo "   PHP $ver sudah berjalan"; continue
    fi
    cat > "$conf" <<EOF
[global]
pid = $ROOT/logs/php${ver//./}.pid
error_log = $ROOT/logs/php${ver//./}.error.log
[www]
user = $(whoami)
group = staff
listen = 127.0.0.1:$fport
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
php_admin_value[error_log] = $ROOT/logs/php${ver//./}-www.log
EOF
    nohup "$(fpm_bin "$ver")" -y "$conf" -c "$etc/php.ini" >> "$ROOT/logs/php${ver//./}.stdout.log" 2>&1 &
    echo "   PHP $ver -> fastcgi 127.0.0.1:$fport"
done

# --- 3. Nginx ---
echo "3. Nginx ..."
if port_in_use 8080; then
    echo "   Port 8080 sudah terpakai — Nginx kemungkinan sudah berjalan."
else
    "$(brew_prefix)/opt/nginx/bin/nginx" -p "$ROOT/" -c "$ROOT/conf/nginx/nginx.conf"
fi

echo
echo "Dev environment running!"
echo "- Default (Port 8080) : http://localhost:8080 (PHP $DEFAULT_PHP_VERSION)"
echo "- PHP 5.6 (Port 8056) : http://localhost:8056"
echo "- PHP 7.4 (Port 8074) : http://localhost:8074"
echo "- PHP 8.2 (Port 8082) : http://localhost:8082"
echo "- PHP 8.3 (Port 8083) : http://localhost:8083"
echo "- PHP 8.4 (Port 8084) : http://localhost:8084"
echo "- MariaDB             : 127.0.0.1:${MARIADB_PORT} (user: root, socket: bin/mariadb/mysqld.sock)"
