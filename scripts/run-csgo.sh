#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${APP_ROOT:-/home/steam/csgo-dedicated}"
STEAM_APP_ID="${STEAM_APP_ID:-4465480}"
UPDATE_ON_START="${UPDATE_ON_START:-1}"
STEAM_LOGIN="${STEAM_LOGIN:-anonymous}"
STEAM_USER="${STEAM_USER:-}"
STEAM_PASS="${STEAM_PASS:-}"
STEAM_GUARD_CODE="${STEAM_GUARD_CODE:-}"
USE_STEAM_PASSWORD_LOGIN="${USE_STEAM_PASSWORD_LOGIN:-0}"
STEAM_RUNTIME_APP_ID="${STEAM_RUNTIME_APP_ID:-1628350}"

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

check_writable_dir() {
  local dir="$1"
  local marker="${dir}/.write-test-$$"
  mkdir -p "${dir}"
  if ! touch "${marker}" 2>/dev/null; then
    echo "[csgo] Directory is not writable: ${dir}" >&2
    ls -ld "${dir}" >&2 || true
    return 1
  fi
  rm -f "${marker}" 2>/dev/null || true
}

check_writable_dir "${APP_ROOT}" || exit 21
check_writable_dir "/home/steam/Steam" || exit 22

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
  echo "[csgo] Could not find steamcmd binary in container" >&2
  exit 1
fi

if [[ "${UPDATE_ON_START}" == "1" ]]; then
  update_log="$(mktemp)"
  trap 'rm -f "${update_log}"' EXIT

  echo "[csgo] Updating app ${STEAM_APP_ID} into ${APP_ROOT}"
  if [[ "${STEAM_APP_ID}" == "4465480" && -z "${STEAM_USER}" ]]; then
    echo "[csgo] App ${STEAM_APP_ID} requires account login. Run: docker compose --profile setup run --rm steam-login" >&2
    exit 17
  fi

  if [[ -n "${STEAM_USER}" && -n "${STEAM_PASS}" && "${USE_STEAM_PASSWORD_LOGIN}" == "1" ]]; then
    echo "[csgo] Using authenticated Steam login for app update"
    set +e
    if [[ -n "${STEAM_GUARD_CODE}" ]]; then
      "${STEAMCMD_BIN}" \
        +force_install_dir "${APP_ROOT}" \
        +login "${STEAM_USER}" "${STEAM_PASS}" "${STEAM_GUARD_CODE}" \
        +app_update "${STEAM_APP_ID}" validate \
        +quit 2>&1 | tee "${update_log}"
    else
      "${STEAMCMD_BIN}" \
        +force_install_dir "${APP_ROOT}" \
        +login "${STEAM_USER}" "${STEAM_PASS}" \
        +app_update "${STEAM_APP_ID}" validate \
        +quit 2>&1 | tee "${update_log}"
    fi
    steamcmd_status=${PIPESTATUS[0]}
    set -e
  elif [[ -n "${STEAM_USER}" ]]; then
    echo "[csgo] Using Steam user login for app update (session/guard cache)"
    set +e
    "${STEAMCMD_BIN}" \
      +force_install_dir "${APP_ROOT}" \
      +login "${STEAM_USER}" \
      +app_update "${STEAM_APP_ID}" validate \
      +quit 2>&1 | tee "${update_log}"
    steamcmd_status=${PIPESTATUS[0]}
    set -e
  else
    echo "[csgo] Using anonymous Steam login for app update"
    set +e
    "${STEAMCMD_BIN}" \
      +force_install_dir "${APP_ROOT}" \
      +login "${STEAM_LOGIN}" \
      +app_update "${STEAM_APP_ID}" validate \
      +quit 2>&1 | tee "${update_log}"
    steamcmd_status=${PIPESTATUS[0]}
    set -e
  fi

  if grep -q "No subscription" "${update_log}"; then
    echo "[csgo] Steam account does not have access to app ${STEAM_APP_ID}." >&2
    echo "[csgo] Add local secrets files: secrets/steam_user and secrets/steam_pass" >&2
    exit 18
  fi

  if grep -q "Failed to install app '${STEAM_APP_ID}'" "${update_log}"; then
    echo "[csgo] SteamCMD failed to install app ${STEAM_APP_ID}." >&2
    exit 19
  fi

  if [[ ${steamcmd_status} -ne 0 ]]; then
    echo "[csgo] SteamCMD exited with status ${steamcmd_status}" >&2
    exit "${steamcmd_status}"
  fi
else
  echo "[csgo] UPDATE_ON_START=0, skipping Steam update"
fi

find_launcher() {
  is_bad_shim() {
    local candidate="$1"
    if [[ ! -f "${candidate}" ]]; then
      return 1
    fi
    if grep -q "srcds_run shim" "${candidate}" 2>/dev/null; then
      return 0
    fi
    return 1
  }

  local target
  for target in \
    "${APP_ROOT}/srcds_linux" \
    "${APP_ROOT}/bin/srcds_linux" \
    "${APP_ROOT}/game/csgo.sh" \
    "${APP_ROOT}/csgo.sh" \
    "${APP_ROOT}/csgo_linux64" \
    "${APP_ROOT}/srcds_run"
  do
    if [[ -f "${target}" ]]; then
      if is_bad_shim "${target}"; then
        continue
      fi
      echo "${target}"
      return 0
    fi
  done

  target="$(find "${APP_ROOT}" -type f \( -name srcds_run -o -name srcds_linux -o -name csgo.sh -o -name csgo_linux64 \) | head -n 1 || true)"
  if [[ -n "${target}" ]]; then
    if is_bad_shim "${target}"; then
      target=""
    fi
  fi
  if [[ -n "${target}" ]]; then
    echo "${target}"
    return 0
  fi

  return 1
}

is_runtime_launcher() {
  local candidate="$1"
  if [[ -z "${candidate}" || ! -f "${candidate}" || ! -x "${candidate}" ]]; then
    return 1
  fi

  case "${candidate}" in
    */steam-runtime/run.sh|\
    */SteamLinuxRuntime*/_v2-entry-point|\
    */SteamLinuxRuntime*/run|\
    */SteamLinuxRuntime*/scout-on-soldier-entry-point-v2|\
    */SteamLinuxRuntime*/entry-point|\
    */SteamLinuxRuntime*/_entry-point)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

find_steam_runtime_run() {
  local candidate
  for candidate in \
    "/home/steam/Steam/ubuntu12_32/steam-runtime/run.sh" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime_scout/_v2-entry-point" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime_scout/run" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime_soldier/_v2-entry-point" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime_soldier/run" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime_sniper/run" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime/_v2-entry-point" \
    "/home/steam/Steam/steamapps/common/SteamLinuxRuntime/run" \
    "/home/steam/steamcmd/linux32/steam-runtime/run.sh" \
    "/home/steam/.steam/steam/ubuntu12_32/steam-runtime/run.sh" \
    "/home/steam/.steam/root/ubuntu12_32/steam-runtime/run.sh" \
    "/home/steam/.local/share/Steam/ubuntu12_32/steam-runtime/run.sh" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime_scout/_v2-entry-point" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime_scout/run" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime_soldier/_v2-entry-point" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime_soldier/run" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/run" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime/_v2-entry-point" \
    "/home/steam/.local/share/Steam/steamapps/common/SteamLinuxRuntime/run"
  do
    if is_runtime_launcher "${candidate}"; then
      echo "${candidate}"
      return 0
    fi
  done

  while IFS= read -r candidate; do
    if is_runtime_launcher "${candidate}"; then
      echo "${candidate}"
      return 0
    fi
  done < <(find /home/steam -maxdepth 14 -type f \( \
      -path '*/steam-runtime/run.sh' -o \
      -path '*/SteamLinuxRuntime*/_v2-entry-point' -o \
      -path '*/SteamLinuxRuntime*/run' -o \
      -path '*/SteamLinuxRuntime*/scout-on-soldier-entry-point-v2' -o \
      -path '*/SteamLinuxRuntime*/entry-point' -o \
      -path '*/SteamLinuxRuntime*/_entry-point' \
    \) 2>/dev/null)

  return 1
}

install_steam_runtime_if_missing() {
  local runtime_run
  local runtime_app_id
  local attempted_ids=""
  runtime_run="$(find_steam_runtime_run || true)"
  if [[ -n "${runtime_run}" ]]; then
    echo "${runtime_run}"
    return 0
  fi

  for runtime_app_id in "${STEAM_RUNTIME_APP_ID}" 1628350 1391110 1070560; do
    case " ${attempted_ids} " in
      *" ${runtime_app_id} "*) continue ;;
    esac
    attempted_ids="${attempted_ids} ${runtime_app_id}"

    echo "[csgo] Steam runtime wrapper not found; installing Steam Linux Runtime app ${runtime_app_id}" >&2
    set +e
    "${STEAMCMD_BIN}" \
      +force_install_dir "/home/steam/Steam" \
      +login anonymous \
      +app_update "${runtime_app_id}" validate \
      +quit >/tmp/steam-runtime-install.log 2>&1
    runtime_status=$?
    set -e

    if [[ ${runtime_status} -ne 0 ]]; then
      echo "[csgo] Failed to install Steam runtime app ${runtime_app_id}" >&2
      tail -n 40 /tmp/steam-runtime-install.log >&2 || true
      continue
    fi

    runtime_run="$(find_steam_runtime_run || true)"
    if [[ -n "${runtime_run}" ]]; then
      echo "${runtime_run}"
      return 0
    fi
  done

  echo "[csgo] Steam runtime app installed, but runtime wrapper still not found" >&2
  find /home/steam -maxdepth 10 -type d -name 'SteamLinuxRuntime*' 2>/dev/null >&2 || true
  find /home/steam -maxdepth 14 -type f \( \
      -path '*/SteamLinuxRuntime*/run' -o \
      -path '*/SteamLinuxRuntime*/*entry-point*' -o \
      -path '*/steam-runtime/run.sh' \
    \) 2>/dev/null | head -n 40 >&2 || true
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
  -steam
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

case "${LAUNCHER}" in
  */csgo.sh|*/csgo_linux64)
    RUNTIME_RUN="$(install_steam_runtime_if_missing || true)"
    if [[ -z "${RUNTIME_RUN}" ]]; then
      echo "[csgo] Could not find Steam scout runtime wrapper. Trying direct launch with STEAM_RUNTIME=1." >&2
      export STEAM_RUNTIME=1
      exec "${LAUNCHER}" -dedicated "${ARGS[@]}"
    fi
    echo "[csgo] Using runtime wrapper: ${RUNTIME_RUN}"
    case "${RUNTIME_RUN}" in
      */_v2-entry-point)
        exec "${RUNTIME_RUN}" --verb=waitforexitandrun -- "${LAUNCHER}" -dedicated "${ARGS[@]}"
        ;;
      *)
        exec "${RUNTIME_RUN}" "${LAUNCHER}" -dedicated "${ARGS[@]}"
        ;;
    esac
    ;;
  *)
    exec "${LAUNCHER}" "${ARGS[@]}"
    ;;
esac
