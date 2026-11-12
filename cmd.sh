#!/usr/bin/env bash
# cmd.sh — membuka shell dengan PATH & alias sesuai .env (pengganti cmd.bat).
set -u
source "$(cd "$(dirname "$0")" && pwd)/common.sh"
load_env

echo "======================================================="
echo "     Dev Environment Shell (PHP, Composer, MariaDB)"
echo "======================================================="
echo "ROOT: $ROOT"

export PATH="$ROOT/bin:$(mdb_bin_dir):$PATH"
alias php='"'"$ROOT/bin/php"'"'
alias php56='"'"$ROOT/bin/php56"'"'
alias php74='"'"$ROOT/bin/php74"'"'
alias php82='"'"$ROOT/bin/php82"'"'
alias php83='"'"$ROOT/bin/php83"'"'
alias php84='"'"$ROOT/bin/php84"'"'
alias composer='"'"$ROOT/bin/composer"'"'

$ROOT/bin/php -v
$ROOT/bin/composer --version
echo "Shortcut tersedia: php / php56..php84 / composer / mysql"
exec "$(command -v bash)" --norc --noprofile
