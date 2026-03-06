#!/bin/sh
set -eu

APP_ROOT="/home/steam/csgo-dedicated"

find_target() {
  for target in \
    "${APP_ROOT}/game/cs2.sh" \
    "${APP_ROOT}/game/csgo.sh" \
    "${APP_ROOT}/srcds_linux" \
    "${APP_ROOT}/game/bin/linuxsteamrt64/cs2"
  do
    if [ -x "${target}" ] || [ -f "${target}" ]; then
      printf "%s" "${target}"
      return 0
    fi
  done
  return 1
}

TARGET="$(find_target || true)"
if [ -z "${TARGET}" ]; then
  echo "[srcds_run shim] No supported dedicated server launcher found in ${APP_ROOT}" >&2
  exit 1
fi

case "${TARGET}" in
  */cs2.sh|*/csgo.sh|*/cs2)
    exec "${TARGET}" -dedicated "$@"
    ;;
  */srcds_linux)
    export LD_LIBRARY_PATH="${APP_ROOT}/bin:${LD_LIBRARY_PATH:-}"
    exec "${TARGET}" "$@"
    ;;
  *)
    exec "${TARGET}" "$@"
    ;;
esac
