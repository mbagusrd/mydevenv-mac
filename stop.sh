#!/usr/bin/env bash
# stop.sh — menghentikan semua service.
set -u
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

echo "[Stopping MyDevEnv-mac]"

# Nginx: graceful stop
NGX="$(brew_prefix)/opt/nginx/bin/nginx"
if [ -f "$ROOT/logs/nginx.pid" ]; then
    "$NGX" -p "$ROOT/" -c "$ROOT/conf/nginx/nginx.conf" -s quit 2>/dev/null || true
fi
pkill -f "nginx: master process" 2>/dev/null || true

# PHP-FPM & MariaDB via pidfile
for f in "$ROOT"/logs/php*.pid; do
    [ -f "$f" ] && { kill "$(cat "$f")" 2>/dev/null || true; rm -f "$f"; }
done
[ -f "$ROOT/logs/mysqld.pid" ] && {
    "$(mdb_bin_dir)/mariadb-admin" --socket="$(mdb_socket)" -u root -p"${MARIADB_ROOT_PASSWORD:-root}" shutdown >/dev/null 2>&1 \
        || kill "$(cat "$ROOT/logs/mysqld.pid")" 2>/dev/null || true
    rm -f "$ROOT/logs/mysqld.pid"
}

# Cadangan: kill sisa proses milik stack ini
pkill -f "php-fpm: master process.*$ROOT/conf/php-fpm" 2>/dev/null || true
pkill -f "mariadbd.*$(basename "$ROOT")/bin/mariadb/data" 2>/dev/null || true

echo "All services stopped."
