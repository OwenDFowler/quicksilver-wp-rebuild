#!/bin/sh
set -eu

THEME_SLUG="quicksilver-construction"
THEME_SOURCE="/opt/quicksilver/themes/${THEME_SLUG}"
THEME_ROOT="/var/www/html/wp-content/themes"
THEME_TARGET="${THEME_ROOT}/${THEME_SLUG}"
THEME_STAGING="${THEME_ROOT}/.${THEME_SLUG}.next"
THEME_BACKUP="${THEME_ROOT}/.${THEME_SLUG}.previous"

if [ ! -d "${THEME_SOURCE}" ]; then
    echo "Missing bundled theme source: ${THEME_SOURCE}" >&2
    exit 1
fi

if [ ! -d "${THEME_ROOT}" ]; then
    echo "Missing WordPress theme directory: ${THEME_ROOT}" >&2
    exit 1
fi

if [ ! -w "${THEME_ROOT}" ]; then
    echo "WordPress theme directory is not writable: ${THEME_ROOT}" >&2
    exit 1
fi

rm -rf "${THEME_STAGING}"
mkdir -p "${THEME_STAGING}"
cp -a "${THEME_SOURCE}/." "${THEME_STAGING}/"
test -f "${THEME_STAGING}/style.css"
test -f "${THEME_STAGING}/index.php"
chown -R www-data:www-data "${THEME_STAGING}"

rm -rf "${THEME_BACKUP}"
if [ -d "${THEME_TARGET}" ]; then
    mv "${THEME_TARGET}" "${THEME_BACKUP}"
fi

if ! mv "${THEME_STAGING}" "${THEME_TARGET}"; then
    if [ -d "${THEME_BACKUP}" ]; then
        mv "${THEME_BACKUP}" "${THEME_TARGET}"
    fi
    echo "Failed to move staged theme into place: ${THEME_TARGET}" >&2
    exit 1
fi

if [ ! -f "${THEME_TARGET}/style.css" ] || [ ! -f "${THEME_TARGET}/index.php" ]; then
    rm -rf "${THEME_TARGET}"
    if [ -d "${THEME_BACKUP}" ]; then
        mv "${THEME_BACKUP}" "${THEME_TARGET}"
    fi
    echo "Synced theme is missing required WordPress files." >&2
    exit 1
fi

if [ -e /etc/apache2/mods-enabled/mpm_event.load ]; then
    a2dismod mpm_event
fi

if [ -e /etc/apache2/mods-enabled/mpm_worker.load ]; then
    a2dismod mpm_worker
fi

if [ ! -e /etc/apache2/mods-enabled/mpm_prefork.load ]; then
    a2enmod mpm_prefork
fi

exec docker-entrypoint.sh "$@"
