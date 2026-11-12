#!/usr/bin/env bash
# run.sh — Control panel interaktif (padanan run.bat di varian Windows).
set -u
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
load_env

pause() { printf "\nTekan Enter untuk kembali ke menu..."; read -r; }

# ---- Status helpers ----
any_fpm_running() { port_in_use "${FPM_PORT[8.4]}" || port_in_use "${FPM_PORT[8.3]}" || port_in_use "${FPM_PORT[8.2]}" || port_in_use "${FPM_PORT[7.4]}" || port_in_use "${FPM_PORT[5.6]}"; }
on_off() { if [ "$1" = "1" ]; then echo "[ON]"; else echo "[OFF]"; fi; }

current_active_php() {
    local port
    port=$(grep -oE '[0-9]{4}' "$ROOT/conf/nginx/default_php.conf" 2>/dev/null || echo "")
    case "$port" in
        9056) echo "5.6" ;;
        9074) echo "7.4" ;;
        9082) echo "8.2" ;;
        9083) echo "8.3" ;;
        9084) echo "8.4" ;;
        *) echo "${DEFAULT_PHP_VERSION:-unknown}" ;;
    esac
}

# ---- PATH management (macOS: ~/.zshrc & ~/.bash_profile) ----
path_add() {
    local f
    for f in "$HOME/.zshrc" "$HOME/.bash_profile"; do
        [ -f "$f" ] || touch "$f"
        # Hapus entri lama jika ada agar formatnya ter-update
        if grep -qs "MYDEVENV-MAC PATH BEGIN" "$f"; then
            sed -i '' '/# MYDEVENV-MAC PATH BEGIN/,/# MYDEVENV-MAC PATH END/d' "$f"
        fi
        cat >> "$f" <<EOF

# MYDEVENV-MAC PATH BEGIN
export PATH="$ROOT/bin:\$(brew --prefix mariadb 2>/dev/null || echo /opt/homebrew/opt/mariadb)/bin:\$PATH"
# MYDEVENV-MAC PATH END
EOF
        echo "[OK] PATH mydevenv-mac ditambahkan di awal (prioritas) pada $f"
    done
    echo "Catatan: buka jendela Terminal baru atau jalankan: source ~/.zshrc"
}

path_remove() {
    local f
    for f in "$HOME/.zshrc" "$HOME/.bash_profile"; do
        if grep -qs "MYDEVENV-MAC PATH BEGIN" "$f"; then
            sed -i '' '/# MYDEVENV-MAC PATH BEGIN/,/# MYDEVENV-MAC PATH END/d' "$f"
            echo "[OK] Entri PATH dihapus dari $f"
        else
            echo "[SKIP] $f tidak memiliki entri PATH mydevenv-mac."
        fi
    done
}

main_menu() {
    clear
    load_env
    echo "======================================================="
    echo "          MyDevEnv-mac - Portable Dev Control Panel"
    echo "======================================================="
    echo
    local s_nginx s_mdb s_php active_php
    s_nginx=$(on_off "$(port_in_use 8080 && echo 1 || echo 0)")
    s_mdb=$(on_off "$(port_in_use "$MARIADB_PORT" && echo 1 || echo 0)")
    s_php=$(on_off "$(any_fpm_running && echo 1 || echo 0)")
    active_php=$(current_active_php)
    echo "Status Services:"
    echo "  Nginx   : $s_nginx (Port 8080, 8056, 8074, 8082, 8083, 8084)"
    echo "  MariaDB : $s_mdb (Port $MARIADB_PORT)"
    echo "  PHP-FPM : $s_php (Default Port 8080: PHP $active_php)"
    echo
    echo "-------------------------------------------------------"
    echo " [1] Start All Services (Background)"
    echo " [2] Stop All Services"
    echo " [3] Restart All Services"
    echo " [4] Switch Default PHP Version (Port 8080)"
    echo " [5] Open Dev Terminal (cmd.sh with PATH)"
    echo " [6] Open Web in Browser (http://localhost:8080)"
    echo " [7] Install / Re-install Dependencies (install.sh)"
    echo " [8] Check Status Details"
    echo " [9] Manage User PATH (Add/Remove from shell profile)"
    echo " [0] Exit"
    echo "-------------------------------------------------------"
    printf "Pilih menu [0-9]: "
    read -r choice || exit 0
    case "$choice" in
        1) action_start ;;
        2) action_stop ;;
        3) action_restart ;;
        4) submenu_switch_php ;;
        5) action_terminal ;;
        6) action_browser ;;
        7) action_install ;;
        8) action_status ;;
        9) submenu_path ;;
        0) exit 0 ;;
        *) echo "Pilihan tidak valid."; sleep 2; main_menu ;;
    esac
}

action_start() {
    echo; echo "Menjalankan services di background..."
    "$ROOT/start.sh" | tail -n 3
    pause; main_menu
}

action_stop() {
    echo; echo "Menghentikan seluruh services..."
    "$ROOT/stop.sh"
    sleep 1; pause; main_menu
}

action_restart() {
    echo; echo "Me-restart services..."
    "$ROOT/stop.sh"
    sleep 1
    "$ROOT/start.sh" | tail -n 3
    pause; main_menu
}

submenu_switch_php() {
    clear
    load_env
    local active_php
    active_php=$(current_active_php)
    echo "======================================================="
    echo "              Switch Default PHP Version"
    echo "======================================================="
    echo
    echo "PHP aktif saat ini pada Port 8080: PHP $active_php"
    echo
    echo " [1] PHP 5.6 (Port 8056)"
    echo " [2] PHP 7.4 (Port 8074)"
    echo " [3] PHP 8.2 (Port 8082)"
    echo " [4] PHP 8.3 (Port 8083)"
    echo " [5] PHP 8.4 (Port 8084)"
    echo " [0] Kembali ke Menu Utama"
    echo "-------------------------------------------------------"
    printf "Pilih versi [0-5]: "
    read -r php_choice || exit 0
    [ "$php_choice" = "0" ] && { main_menu; return; }
    case "$php_choice" in
        1) NEW_VER="5.6" ;; 2) NEW_VER="7.4" ;; 3) NEW_VER="8.2" ;;
        4) NEW_VER="8.3" ;; 5) NEW_VER="8.4" ;;
        *) echo "Pilihan tidak valid."; sleep 2; submenu_switch_php; return ;;
    esac
    echo "fastcgi_pass 127.0.0.1:${FPM_PORT[$NEW_VER]};" > "$ROOT/conf/nginx/default_php.conf"
    sed -i '' "s|^DEFAULT_PHP_VERSION=.*|DEFAULT_PHP_VERSION=$NEW_VER|" "$ROOT/.env"
    if port_in_use 8080; then
        "$(brew_prefix)/opt/nginx/bin/nginx" -p "$ROOT/" -c "$ROOT/conf/nginx/nginx.conf" -s reload
    fi
    echo; echo "[OK] Default PHP diubah ke PHP $NEW_VER!"
    sleep 2; main_menu
}

action_terminal() {
    # Buka Terminal.app baru dengan cmd.sh
    open -a Terminal "$ROOT/cmd.sh" 2>/dev/null || osascript -e "tell app \"Terminal\" to do script \"$ROOT/cmd.sh\"" >/dev/null 2>&1
    echo "Terminal dev dibuka."
    sleep 1; main_menu
}

action_browser() {
    open "http://localhost:8080"
    echo "Dibuka di browser: http://localhost:8080"
    sleep 1; main_menu
}

action_install() {
    clear
    echo "======================================================="
    echo "          Install / Re-install Dependencies"
    echo "======================================================="
    echo
    echo "Menu ini menjalankan install.sh untuk mengunduh dan"
    echo "menginstal komponen yang belum lengkap."
    echo
    echo " [1] Lanjutkan Instalasi"
    echo " [0] Batal / Kembali ke Menu Utama"
    echo "-------------------------------------------------------"
    printf "Pilih [0/1]: "
    read -r ins_choice || exit 0
    if [ "$ins_choice" = "1" ]; then
        "$ROOT/install.sh"
        pause
    fi
    main_menu
}

action_status() {
    clear
    echo "======================================================="
    echo "                 Detail Status Process"
    echo "======================================================="
    echo
    echo "[Process List]"
    ps aux | grep -E "nginx|mariadbd|php-fpm" | grep -v grep || echo "Tidak ada process aktif."
    echo
    echo "[Listening Ports]"
    lsof -nP -iTCP -sTCP:LISTEN 2>/dev/null | grep -E ":(8080|8056|8074|8082|8083|8084|$MARIADB_PORT|9056|9074|9082|9083|9084)\b" || echo "Tidak ada port aktif."
    echo
    echo "[Service Summary]"
    "$ROOT/status.sh"
    pause; main_menu
}

submenu_path() {
    clear
    echo "======================================================="
    echo "            Manage User PATH (macOS)"
    echo "======================================================="
    echo
    echo "Menambahkan folder project (bin/) dan MariaDB client"
    echo "ke PATH shell (~/.zshrc & ~/.bash_profile) agar 'php',"
    echo "'composer', dan 'mysql' bisa dipanggil di Terminal mana pun."
    echo
    echo " [1] Tambahkan ke User PATH (Permanent)"
    echo " [2] Hapus dari User PATH"
    echo " [0] Kembali ke Menu Utama"
    echo "-------------------------------------------------------"
    printf "Pilih menu [0-2]: "
    read -r path_opt || exit 0
    case "$path_opt" in
        0) main_menu ;;
        1) path_add; pause; main_menu ;;
        2) path_remove; pause; main_menu ;;
        *) echo "Pilihan tidak valid."; sleep 2; submenu_path ;;
    esac
}

main_menu
