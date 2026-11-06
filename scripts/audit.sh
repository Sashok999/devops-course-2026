#!/usr/bin/env bash
set -euo pipefail

failures=0
cert_min_seconds=${CERT_MIN_SECONDS:-2592000}

check() {
    local description=$1
    shift
    if "$@"; then
        printf '[OK] %s\n' "$description"
    else
        printf '[FAIL] %s\n' "$description"
        failures=$((failures + 1))
    fi
}

check_site_permissions() {
    local writable_paths key_mode
    writable_paths=$(find /var/www/devops-site -perm -o+w -print) || return 1
    key_mode=$(sudo stat -c '%a' /etc/ssl/private/devops.key) || return 1
    [[ -z "$writable_paths" && "$key_mode" == 600 ]]
}

printf '[4] Веб-сервер\n'
check 'Служба nginx активна' systemctl is-active --quiet nginx
check 'Конфигурация nginx корректна' sudo nginx -t
check "Сертификат действует ещё минимум $cert_min_seconds с" \
    openssl x509 -in /etc/ssl/certs/devops.crt -noout -checkend "$cert_min_seconds"
check 'Нет прав записи для всех, режим ключа 600' check_site_permissions

if (( failures > 0 )); then
    exit 1
fi
