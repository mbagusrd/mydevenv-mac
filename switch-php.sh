#!/usr/bin/env bash
# switch-php.sh — mengganti versi PHP default untuk http://localhost:8080.
set -u
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
load_env

echo "======================================================="
echo "          Switch Default PHP Version (Port 8080)"
echo "======================================================="
echo "Pilih versi PHP default untuk http://localhost:8080:"
echo "[1] PHP 5.6 (Port 8056)"
echo "[2] PHP 7.4 (Port 8074)"
echo "[3] PHP 8.2 (Port 8082)"
echo "[4] PHP 8.3 (Port 8083)"
echo "[5] PHP 8.4 (Port 8084)"
printf "Masukkan pilihan (1-5): "
read -r choice

case "$choice" in
    1) TARGET="5.6" ;; 2) TARGET="7.4" ;; 3) TARGET="8.2" ;;
    4) TARGET="8.3" ;; 5) TARGET="8.4" ;;
    *) echo "[ERROR] Pilihan tidak valid!"; exit 1 ;;
esac

echo "fastcgi_pass 127.0.0.1:${FPM_PORT[$TARGET]};" > "$ROOT/conf/nginx/default_php.conf"

# update DEFAULT_PHP_VERSION di .env
sed -i '' "s|^DEFAULT_PHP_VERSION=.*|DEFAULT_PHP_VERSION=$TARGET|" "$ROOT/.env"

# reload nginx jika berjalan
NGX="$(brew_prefix)/opt/nginx/bin/nginx"
if port_in_use 8080; then
    "$NGX" -p "$ROOT/" -c "$ROOT/conf/nginx/nginx.conf" -s reload
    echo "[OK] Nginx reloaded."
fi

echo "======================================================="
echo "  Default PHP diubah ke PHP $TARGET!"
echo "  http://localhost:8080 sekarang mengarah ke PHP $TARGET"
echo "======================================================="
