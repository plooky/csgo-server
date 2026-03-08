#!/usr/bin/env bash
set -euo pipefail

STEAM_USER="${STEAM_USER:-}"
STEAM_PASS="${STEAM_PASS:-}"
STEAM_GUARD_CODE="${STEAM_GUARD_CODE:-}"
STEAM_APP_ID="${STEAM_APP_ID:-740}"
APP_ROOT="/home/steam/csgo-dedicated"

find_steamcmd() {
  local candidate
  for candidate in \
    "$(command -v steamcmd 2>/dev/null || true)" \
    "/home/steam/steamcmd/steamcmd.sh" \
    "/home/steam/steamcmd/steamcmd" \
    "/usr/games/steamcmd" \
    "/usr/bin/steamcmd"
  do
    if [[ -n "${candidate}" && -f "${candidate}" ]]; then
      echo "${candidate}"
      return 0
    fi
  done
  return 1
}

STEAMCMD_BIN="$(find_steamcmd || true)"
if [[ -z "${STEAMCMD_BIN}" ]]; then
  echo "[steam-login] Could not find steamcmd binary in container" >&2
  exit 1
fi

if [[ -z "${STEAM_USER}" ]]; then
  read -r -p "Steam username: " STEAM_USER
fi

if [[ -z "${STEAM_USER}" ]]; then
  echo "[steam-login] Steam username is required." >&2
  exit 1
fi

if [[ -z "${STEAM_PASS}" ]]; then
  read -r -s -p "Steam password: " STEAM_PASS
  echo
fi

if [[ -z "${STEAM_PASS}" ]]; then
  echo "[steam-login] Steam password is required." >&2
  exit 1
fi

if [[ -z "${STEAM_GUARD_CODE}" ]]; then
  read -r -p "Steam Guard code (optional, press Enter to skip): " STEAM_GUARD_CODE
fi

mkdir -p "${APP_ROOT}"

echo "[steam-login] Login may ask for password and Steam Guard code."
echo "[steam-login] Steam session data is persisted in ./data/steam."
"${STEAMCMD_BIN}" \
  +force_install_dir "${APP_ROOT}" \
  +login "${STEAM_USER}" "${STEAM_PASS}" "${STEAM_GUARD_CODE}" \
  +app_info_print "${STEAM_APP_ID}" \
  +quit

echo "[steam-login] Login flow completed."
