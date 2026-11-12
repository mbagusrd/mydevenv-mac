#!/usr/bin/env bash
# common.sh — shared helpers untuk semua script mydevenv-mac.
# Di-sourced oleh install.sh / start.sh / stop.sh / status.sh / switch-php.sh.

# Selalu berdiri di root project
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$ROOT"

# ---- Konstanta port (disamakan dengan varian Windows) ----
# Web: 8080 default (port 80 butuh root di macOS), 8056/8074/8082/8083/8084 per versi.
# FastCGI (php-fpm): 9056 / 9074 / 9082 / 9083 / 9084.
PHP_VERSIONS=("5.6" "7.4" "8.2" "8.3" "8.4")
declare -A FPM_PORT=( ["5.6"]=9056 ["7.4"]=9074 ["8.2"]=9082 ["8.3"]=9083 ["8.4"]=9084 )
declare -A WEB_PORT=( ["5.6"]=8056 ["7.4"]=8074 ["8.2"]=8082 ["8.3"]=8083 ["8.4"]=8084 )
DEFAULT_WEB_PORT=8080

# ---- .env ----
load_env() {
    if [ ! -f "$ROOT/.env" ]; then
        cp "$ROOT/.env.example" "$ROOT/.env"
        echo "[INFO] .env tidak ada, dibuat dari .env.example"
    fi
    set -a
    # shellcheck disable=SC1091
    source "$ROOT/.env"
    set +a
    NGINX_WEB_ROOT="${NGINX_WEB_ROOT:-./www}"
    DEFAULT_PHP_VERSION="${DEFAULT_PHP_VERSION:-8.4}"
    MARIADB_PORT="${MARIADB_PORT:-3306}"
    MARIADB_ROOT_PASSWORD="${MARIADB_ROOT_PASSWORD:-root}"
}

# ---- Homebrew ----
brew_prefix() {
    if [ -n "${BREW_PREFIX:-}" ]; then echo "$BREW_PREFIX"; return; fi
    if command -v brew >/dev/null 2>&1; then
        BREW_PREFIX="$(brew --prefix)"
    elif [ -x "/opt/homebrew/bin/brew" ]; then
        BREW_PREFIX="/opt/homebrew"
    elif [ -x "/usr/local/bin/brew" ]; then
        BREW_PREFIX="/usr/local"
    else
        echo "[ERROR] Homebrew tidak ditemukan. Install dulu: https://brew.sh" >&2
        exit 1
    fi
    echo "$BREW_PREFIX"
}

# Path binary php-fpm untuk versi tertentu (tap shivammathur/php)
fpm_bin() {
    local ver="$1"
    echo "$(brew_prefix)/opt/php@${ver}/sbin/php-fpm"
}

php_etc_dir() {
    local ver="$1"
    # Tap shivammathur/php di macOS: /opt/homebrew/etc/php/8.4 (fallback: etc/php@8.4)
    local d
    d="$(brew_prefix)/etc/php/${ver}"
    [ -d "$d" ] || d="$(brew_prefix)/etc/php@${ver}"
    echo "$d"
}

# ---- MariaDB ----
# brew --prefix mariadb tetap valid walau formula tidak ter-link (mis. bentrok mysql-client)
mdb_prefix() {
    if [ -n "${MDB_PREFIX:-}" ]; then echo "$MDB_PREFIX"; return; fi
    MDB_PREFIX="$(brew --prefix mariadb 2>/dev/null || echo "$(brew_prefix)/opt/mariadb")"
    echo "$MDB_PREFIX"
}
mdb_bin_dir() { echo "$(mdb_prefix)/bin"; }
mdb_data_dir() { echo "$ROOT/bin/mariadb/data"; }
mdb_socket() { echo "$ROOT/bin/mariadb/mysqld.sock"; }

# ---- Resolusi webroot absolut ----
webroot_abs() {
    local wr="$NGINX_WEB_ROOT"
    if [ "${wr:0:1}" = "/" ]; then echo "$wr"; else echo "$ROOT/${wr#./}"; fi
}

# ---- Util ----
port_in_use() {
    lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

pid_running() {
    [ -f "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null
}
