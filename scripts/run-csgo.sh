#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/home/steam/csgo-dedicated}"
STEAM_APP_ID="${STEAM_APP_ID:-4465480}"
UPDATE_ON_START="${UPDATE_ON_START:-1}"
STEAM_LOGIN="${STEAM_LOGIN:-anonymous}"

SRCDS_TOKEN="${SRCDS_TOKEN:-}"
SRCDS_HOSTNAME="${SRCDS_HOSTNAME:-csgo server}"
SRCDS_RCONPW="${SRCDS_RCONPW:-}"
SRCDS_PW="${SRCDS_PW:-}"
SRCDS_PORT="${SRCDS_PORT:-27015}"
SRCDS_CLIENT_PORT="${SRCDS_CLIENT_PORT:-27005}"
SRCDS_TV_PORT="${SRCDS_TV_PORT:-27020}"
SRCDS_STARTMAP="${SRCDS_STARTMAP:-de_dust2}"
SRCDS_MAPGROUP="${SRCDS_MAPGROUP:-mg_active}"
SRCDS_GAMETYPE="${SRCDS_GAMETYPE:-0}"
SRCDS_GAMEMODE="${SRCDS_GAMEMODE:-1}"
SRCDS_MAXPLAYERS="${SRCDS_MAXPLAYERS:-12}"
TV_ENABLE="${TV_ENABLE:-1}"

mkdir -p "${APP_ROOT}"

if [[ "${UPDATE_ON_START}" == "1" ]]; then
  echo "[csgo] Updating app ${STEAM_APP_ID} into ${APP_ROOT}"
  steamcmd \
    +force_install_dir "${APP_ROOT}" \
    +login "${STEAM_LOGIN}" \
    +app_update "${STEAM_APP_ID}" validate \
    +quit
else
  echo "[csgo] UPDATE_ON_START=0, skipping Steam update"
fi

find_launcher() {
  local target
  for target in \
    "${APP_ROOT}/srcds_run" \
    "${APP_ROOT}/srcds_linux" \
    "${APP_ROOT}/game/csgo.sh" \
    "${APP_ROOT}/csgo.sh"
  do
    if [[ -f "${target}" ]]; then
      echo "${target}"
      return 0
    fi
  done

  target="$(find "${APP_ROOT}" -type f \( -name srcds_run -o -name srcds_linux -o -name csgo.sh \) | head -n 1 || true)"
  if [[ -n "${target}" ]]; then
    echo "${target}"
    return 0
  fi

  return 1
}

LAUNCHER="$(find_launcher || true)"
if [[ -z "${LAUNCHER}" ]]; then
  echo "[csgo] Could not find a dedicated server launcher under ${APP_ROOT}" >&2
  echo "[csgo] Current top-level files:" >&2
  ls -la "${APP_ROOT}" >&2 || true
  exit 1
fi

chmod +x "${LAUNCHER}" || true
echo "[csgo] Using launcher: ${LAUNCHER}"

ARGS=(
  -game csgo
  -console
  -usercon
  -port "${SRCDS_PORT}"
  +clientport "${SRCDS_CLIENT_PORT}"
  +tv_port "${SRCDS_TV_PORT}"
  +map "${SRCDS_STARTMAP}"
  +mapgroup "${SRCDS_MAPGROUP}"
  +game_type "${SRCDS_GAMETYPE}"
  +game_mode "${SRCDS_GAMEMODE}"
  +maxplayers "${SRCDS_MAXPLAYERS}"
  +tv_enable "${TV_ENABLE}"
  +hostname "${SRCDS_HOSTNAME}"
)

if [[ -n "${SRCDS_TOKEN}" ]]; then
  ARGS+=(+sv_setsteamaccount "${SRCDS_TOKEN}")
fi

if [[ -n "${SRCDS_RCONPW}" ]]; then
  ARGS+=(+rcon_password "${SRCDS_RCONPW}")
fi

if [[ -n "${SRCDS_PW}" ]]; then
  ARGS+=(+sv_password "${SRCDS_PW}")
fi

exec "${LAUNCHER}" "${ARGS[@]}"
