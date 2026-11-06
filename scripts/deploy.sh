#!/usr/bin/env bash

set -euo pipefail

# Настройки
REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"

# Определяем путь к репозиторию
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_DIR="${REPO_ROOT}/site"

# 1. Обработка аргументов
DRY_RUN=false

if [[ $# -eq 1 && "$1" == "--dry-run" ]]; then
    DRY_RUN=true
elif [[ $# -ne 0 ]]; then
    echo "Usage: $0 [--dry-run]" >&2
    exit 1
fi

# 2. Проверка главной страницы
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Error: site/index.html not found" >&2
    exit 1
fi

# 3. Проверка незакоммиченных изменений
if [[ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]]; then
    echo "Error: repository has uncommitted changes" >&2
    exit 1
fi

# 4. Проверка сертификата
if [[ "$DRY_RUN" == false && ! -f "$CA_CERT" ]]; then
    echo "Error: certificate not found: $CA_CERT" >&2
    exit 1
fi

# 5. Подготовка rsync
RSYNC_ARGS=(-avz --delete --chmod=D755,F644)

if [[ "$DRY_RUN" == true ]]; then
    RSYNC_ARGS+=(--dry-run)
fi

# 6. Доставка файлов
rsync "${RSYNC_ARGS[@]}" \
    -e "ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=yes" \
    "${LOCAL_DIR}/" "${REMOTE}:${REMOTE_DIR}/"

# 7. Завершение пробного запуска
if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run completed"
    exit 0
fi

# 8. Проверка HTTPS
if ! curl -fsS --cacert "$CA_CERT" \
    -o /dev/null "$SITE_URL"; then
    echo "Error: website is unavailable" >&2
    exit 1
fi

# 9. Вывод хеша коммита
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"

echo "Successfully deployed commit: $COMMIT"
