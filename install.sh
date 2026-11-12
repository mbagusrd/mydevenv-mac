#!/usr/bin/env bash
# install.sh — installer mydevenv-mac.
# Mengunduh/menginstal via Homebrew: nginx, MariaDB, PHP 5.6/7.4/8.2/8.3/8.4 (tap shivammathur/php),
# dan Composer; lalu menyiapkan seluruh konfigurasi di dalam folder project ini.
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
load_env

echo "=== Setup MyDevEnv-mac di $ROOT ==="
BP="$(brew_prefix)"

if [ ! -x "$(command -v brew)" ] && [ ! -x "$BP/bin/brew" ]; then
    echo "[ERROR] Homebrew belum terpasang. Jalankan: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
    exit 1
fi

mkdir -p "$ROOT/bin/mariadb" "$ROOT/conf/php-fpm" "$ROOT/conf/nginx" "$ROOT/logs" "$ROOT/tmp" "$ROOT/www"

# ---------- 1. PHP multi versi (tap shivammathur/php) ----------
echo "--> Menambahkan tap shivammathur/php ..."
brew tap shivammathur/php >/dev/null

for ver in "${PHP_VERSIONS[@]}"; do
    echo "--> Menginstal PHP $ver ..."
    # Terima versi dari tap mana pun (shivammathur/php atau homebrew/core) —
    # path binary /opt/homebrew/opt/php@<ver> sama untuk keduanya.
    if ! brew list --formula "php@${ver}" >/dev/null 2>&1 \
       && ! brew list --formula "shivammathur/php/php@${ver}" >/dev/null 2>&1; then
        if ! brew install --formula "shivammathur/php/php@${ver}"; then
            echo "    Gagal dari tap shivammathur/php, mencoba homebrew/core ..."
            brew install --formula "php@${ver}"
        fi
    else
        echo "    PHP $ver sudah terinstal, dilewati."
    fi

    # php.ini: copy dari template bawaan, aktifkan timezone
    etc="$(php_etc_dir "$ver")"
    if [ ! -f "$etc/php.ini" ]; then
        for tpl in php.ini-development php.ini-production php.ini.default; do
            if [ -f "$etc/$tpl" ]; then
                cp "$etc/$tpl" "$etc/php.ini"
                sed -i '' 's|^;*date.timezone *=.*|date.timezone = Asia/Jakarta|' "$etc/php.ini" 2>/dev/null || true
                echo "    php.ini dikonfigurasi untuk PHP $ver"
                break
            fi
        done
    fi

    # Tautkan binari CLI ke bin/ project agar mudah dipanggil
    for tool in php php-config; do
        src="$BP/opt/php@${ver}/bin/$tool"
        [ -f "$src" ] && ln -sf "$src" "$ROOT/bin/${tool}${ver//./}"
    done
done

# ---------- 2. Nginx ----------
echo "--> Menginstal Nginx ..."
brew list --formula nginx >/dev/null 2>&1 || brew install --formula nginx

# ---------- 3. MariaDB (data lokal di project, portabel) ----------
if [ ! -f "$(mdb_bin_dir)/mariadbd" ] && [ ! -f "$(mdb_bin_dir)/mysqld" ]; then
    echo "--> Menginstal MariaDB ..."
    brew list --formula mariadb >/dev/null 2>&1 || brew install --formula mariadb
fi

if [ ! -d "$(mdb_data_dir)/mysql" ]; then
    echo "--> Inisialisasi database MariaDB di $(mdb_data_dir) ..."
    "$(mdb_bin_dir)/mariadb-install-db" \
        --basedir="$(brew_prefix)/opt/mariadb" \
        --datadir="$(mdb_data_dir)" \
        --auth-root-authentication-method=normal >/dev/null
    touch "$ROOT/bin/mariadb/.need_root_pw"
fi

# ---------- 4. Composer ----------
if [ ! -f "$ROOT/bin/composer.phar" ]; then
    echo "--> Mengunduh Composer ..."
    curl -fsSL https://getcomposer.org/composer.phar -o "$ROOT/bin/composer.phar"
fi

# ---------- 5. Konfigurasi Nginx (di dalam project) ----------
echo "--> Membuat konfigurasi Nginx ..."
NGINX_FASTCGI_PARAMS="$BP/etc/nginx/fastcgi_params"
NGINX_MIME_TYPES="$BP/etc/nginx/mime.types"
[ -f "$NGINX_FASTCGI_PARAMS" ] || NGINX_FASTCGI_PARAMS="$BP/etc/nginx/fastcgi_params.default"
[ -f "$NGINX_MIME_TYPES" ] || NGINX_MIME_TYPES="$BP/etc/nginx/mime.types.default"

cat > "$ROOT/tmp/nginx.conf.template" <<'TPL'
worker_processes  1;
error_log  __ROOT__/logs/nginx.error.log;
pid        __ROOT__/logs/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       __MIME_TYPES__;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    # Default Server (Port 8080) - target FastCGI dinamis via default_php.conf
    server {
        listen       8080;
        server_name  localhost;
        include      __ROOT__/conf/nginx/webroot.conf;
        index        index.php index.html;

        location / {
            # Generic Laravel projects support (e.g. /my-app/public/...)
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files $uri $uri/ /$app/public/index.php?$query_string;

                location ~ \.php$ {
                    include        __ROOT__/conf/nginx/default_php.conf;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
                    include        __FASTCGI_PARAMS__;
                }
            }

            # Nested project routing (CodeIgniter / legacy MVC with index.php/path)
            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files $uri $uri/ /$app/index.php$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    include        __ROOT__/conf/nginx/default_php.conf;
                    fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        $sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /$app_name$php_script;
                    include        __FASTCGI_PARAMS__;
                }
            }

            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            include        __ROOT__/conf/nginx/default_php.conf;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            fastcgi_param  PATH_INFO        $path_info;
            fastcgi_param  SCRIPT_NAME      $php_script;
            include        __FASTCGI_PARAMS__;
        }
    }

__SERVERS__
}
TPL

# Dedicated servers untuk tiap versi PHP (port 8056..8084)
SERVERS=""
for ver in "${PHP_VERSIONS[@]}"; do
    fport="${FPM_PORT[$ver]}"; wport="${WEB_PORT[$ver]}"
    block="$(sed -e "s|__VER__|$ver|g" -e "s|__FPORT__|$fport|g" -e "s|__WPORT__|$wport|g" -e "s|__ROOT__|$ROOT|g" -e "s|__FASTCGI_PARAMS__|$NGINX_FASTCGI_PARAMS|g" -e "s|__MIME_TYPES__|$NGINX_MIME_TYPES|g" <<'BLK'
    # PHP __VER__ Dedicated (Port __WPORT__)
    server {
        listen       __WPORT__;
        server_name  localhost;
        include      __ROOT__/conf/nginx/webroot.conf;
        index        index.php index.html;

        location / {
            location ~ ^/(?<app>[^/]+)/public/ {
                try_files $uri $uri/ /$app/public/index.php?$query_string;

                location ~ \.php$ {
                    fastcgi_pass   127.0.0.1:__FPORT__;
                    fastcgi_index  index.php;
                    fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
                    include        __FASTCGI_PARAMS__;
                }
            }

            location ~ ^/(?<app>[^/]+)(?<path_info>/.*)?$ {
                try_files $uri $uri/ /$app/index.php$path_info;

                location ~ ^/(?<app_name>[^/]+)(?<php_script>.+\.php)(?<sub_path_info>.*)$ {
                    fastcgi_pass   127.0.0.1:__FPORT__;
                    fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
                    fastcgi_param  PATH_INFO        $sub_path_info;
                    fastcgi_param  SCRIPT_NAME      /$app_name$php_script;
                    include        __FASTCGI_PARAMS__;
                }
            }

            try_files $uri $uri/ /index.php?$query_string;
        }

        location ~ ^(?<php_script>.+\.php)(?<path_info>.*)$ {
            fastcgi_pass   127.0.0.1:__FPORT__;
            fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
            fastcgi_param  PATH_INFO        $path_info;
            fastcgi_param  SCRIPT_NAME      $php_script;
            include        __FASTCGI_PARAMS__;
        }
    }

BLK
)"
    SERVERS="$SERVERS$block"
done

printf '%s' "$SERVERS" > "$ROOT/tmp/servers.inc"
awk -v root="$ROOT" -v mime="$NGINX_MIME_TYPES" -v fparams="$NGINX_FASTCGI_PARAMS" \
    -v inc="$ROOT/tmp/servers.inc" '
    /^__SERVERS__$/ { while ((getline line < inc) > 0) print line; next }
    { gsub(/__ROOT__/, root); gsub(/__MIME_TYPES__/, mime); gsub(/__FASTCGI_PARAMS__/, fparams); print }' \
    "$ROOT/tmp/nginx.conf.template" > "$ROOT/conf/nginx/nginx.conf"
rm -f "$ROOT/tmp/nginx.conf.template" "$ROOT/tmp/servers.inc"

chmod +x "$ROOT"/*.sh 2>/dev/null || true

echo
echo "=== Setup Selesai ==="
echo "Jalankan : ./start.sh"
echo "Matikan  : ./stop.sh"
echo "Status   : ./status.sh"
