#!/usr/bin/env bash
# status.sh — ringkasan status service.
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
load_env

printf "%-18s %-10s %s\n" "SERVICE" "PORT" "STATUS"
for ver in "${PHP_VERSIONS[@]}"; do
    fport="${FPM_PORT[$ver]}"; wport="${WEB_PORT[$ver]}"
    if port_in_use "$fport"; then s="running"; else s="stopped"; fi
    printf "%-18s %-10s %s\n" "PHP $ver (fpm)" "$fport" "$s"
    if port_in_use "$wport"; then s="running"; else s="stopped"; fi
    printf "%-18s %-10s %s\n" "PHP $ver (web)" "$wport" "$s"
done
if port_in_use 8080; then s="running"; else s="stopped"; fi
printf "%-18s %-10s %s\n" "Nginx (default)" "8080" "$s"
if port_in_use "${MARIADB_PORT:-3306}" || "$(mdb_bin_dir)/mariadb" --socket="$(mdb_socket)" -u root -e "SELECT 1" >/dev/null 2>&1; then
    printf "%-18s %-10s %s\n" "MariaDB" "${MARIADB_PORT:-3306}" "running"
else
    printf "%-18s %-10s %s\n" "MariaDB" "${MARIADB_PORT:-3306}" "stopped"
fi
