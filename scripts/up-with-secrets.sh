#!/bin/sh
set -eu

ENV_FILE="${ENV_FILE:-.env}"
SECRETS_DIR="${SECRETS_DIR:-./secrets}"

require_file() {
  if [ ! -f "$1" ]; then
    echo "[up-with-secrets] Missing required file: $1" >&2
    exit 1
  fi
}

read_secret() {
  tr -d '\r\n' < "$1"
}

require_file "${ENV_FILE}"
require_file "${SECRETS_DIR}/srcds_token"
require_file "${SECRETS_DIR}/srcds_rconpw"

export SRCDS_TOKEN="$(read_secret "${SECRETS_DIR}/srcds_token")"
export SRCDS_RCONPW="$(read_secret "${SECRETS_DIR}/srcds_rconpw")"

if [ -z "${SRCDS_TOKEN}" ] || [ -z "${SRCDS_RCONPW}" ]; then
  echo "[up-with-secrets] Secret files must not be empty" >&2
  exit 1
fi

if [ "$#" -eq 0 ]; then
  set -- up -d
fi

exec docker compose --env-file "${ENV_FILE}" "$@"
