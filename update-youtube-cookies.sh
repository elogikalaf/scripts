#!/usr/bin/env bash

set -euo pipefail

########################################
# CONFIG
########################################

REMOTE="rack"
REMOTE_DIR="~/ytdlpbot"

TMP_COOKIE_FILE="/tmp/firefox-cookies.txt"

FIREFOX_PROFILE="$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox/raq0qp9p.ytbot"

MAX_RETRIES=5
RETRY_DELAY=15

########################################
# PREVENT OVERLAPPING RUNS
########################################

exec 9>/tmp/youtube-cookie-refresh.lock

if ! flock -n 9; then
    echo "Another refresh is already running."
    exit 1
fi

########################################
# RETRY HELPER
########################################

retry() {
    local attempt=1

    while true; do
        if "$@"; then
            return 0
        fi

        if (( attempt >= MAX_RETRIES )); then
            echo "Command failed after $attempt attempts."
            return 1
        fi

        echo "Attempt $attempt failed. Retrying in $RETRY_DELAY seconds..."

        sleep "$RETRY_DELAY"

        ((attempt++))
    done
}

########################################
# EXPORT COOKIES
########################################

echo "[1/3] Exporting cookies..."

retry bash -c "
proxychains -q yt-dlp \
  --cookies-from-browser \"firefox:${FIREFOX_PROFILE}\" \
  --cookies \"${TMP_COOKIE_FILE}\" \
  --skip-download \
  'https://localhost' \
  || true

test -s \"${TMP_COOKIE_FILE}\"
"

echo "Cookie count:"

wc -l "${TMP_COOKIE_FILE}"

########################################
# UPLOAD COOKIES
########################################

echo "[2/3] Uploading cookies..."

retry scp \
    -o 'ProxyCommand=corkscrew 127.0.0.1 10808 %h %p' \
    -o ConnectTimeout=20 \
    "${TMP_COOKIE_FILE}" \
    "${REMOTE}:${REMOTE_DIR}/cookies.new"

########################################
# ATOMIC REPLACE
########################################

echo "[3/3] Replacing remote cookies..."

retry ssh \
    -o 'ProxyCommand=corkscrew 127.0.0.1 10808 %h %p' \
    -o ConnectTimeout=20 \
    "${REMOTE}" \
    "mv ${REMOTE_DIR}/cookies.new ${REMOTE_DIR}/cookies.txt && chmod 600 ${REMOTE_DIR}/cookies.txt"

echo "Cookie refresh complete."
