#!/bin/sh
set -eu

GAME_ROOT="${GAME_ROOT:-/home/steam/csgo-dedicated/csgo}"
DEFAULT_OVERRIDES_ROOT="${DEFAULT_OVERRIDES_ROOT:-/overrides-default/csgo}"
LOCAL_OVERRIDES_ROOT="${LOCAL_OVERRIDES_ROOT:-/overrides-local/csgo}"
MMS_BRANCH="${MMS_BRANCH:-1.11}"
SM_BRANCH="${SM_BRANCH:-1.11}"
FORCE_PLUGIN_REINSTALL="${FORCE_PLUGIN_REINSTALL:-0}"

MMS_URL="${MMS_URL:-https://mms.alliedmods.net/mmsdrop/${MMS_BRANCH}/mmsource-latest-linux}"
SM_URL="${SM_URL:-https://sm.alliedmods.net/smdrop/${SM_BRANCH}/sourcemod-latest-linux}"

mkdir -p "${GAME_ROOT}" "${GAME_ROOT}/addons"

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

is_archive_ref() {
  value="$1"
  case "${value}" in
    ""|*" "*) return 1 ;;
  esac

  case "${value}" in
    *.tar.gz|*.tgz|*.tar|*.zip) return 0 ;;
    http://*.tar.gz|http://*.tgz|http://*.tar|http://*.zip) return 0 ;;
    https://*.tar.gz|https://*.tgz|https://*.tar|https://*.zip) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_archive_url() {
  source_url="$1"
  ref="$2"

  case "${ref}" in
    http://*|https://*) printf "%s" "${ref}" ;;
    *) printf "%s/%s" "${source_url%/*}" "${ref}" ;;
  esac
}

install_archive() {
  name="$1"
  url="$2"
  archive_path="${TMP_DIR}/${name}.archive"
  headers_path="${TMP_DIR}/${name}.headers"

  extract_archive() {
    archive="$1"

    if gzip -t "${archive}" >/dev/null 2>&1; then
      tar -xzf "${archive}" -C "${GAME_ROOT}"
      return 0
    fi

    if tar -tf "${archive}" >/dev/null 2>&1; then
      tar -xf "${archive}" -C "${GAME_ROOT}"
      return 0
    fi

    if unzip -tqq "${archive}" >/dev/null 2>&1; then
      unzip -oq "${archive}" -d "${GAME_ROOT}"
      return 0
    fi

    return 1
  }

  echo "[plugin-bootstrap] Downloading ${name} from ${url}"
  curl -fsSL --retry 3 --retry-delay 2 -D "${headers_path}" "${url}" -o "${archive_path}"

  if ! extract_archive "${archive_path}"; then
    first_line="$(head -n 1 "${archive_path}" | tr -d '\r\n' || true)"
    if [ -n "${first_line}" ] && is_archive_ref "${first_line}"; then
      resolved_url="$(resolve_archive_url "${url}" "${first_line}")"
      echo "[plugin-bootstrap] ${name} latest pointer resolved to ${resolved_url}"
      curl -fsSL --retry 3 --retry-delay 2 -D "${headers_path}" "${resolved_url}" -o "${archive_path}"
      if extract_archive "${archive_path}"; then
        return 0
      fi
    fi

    content_type="$(grep -i '^content-type:' "${headers_path}" | tail -n 1 | cut -d' ' -f2- | tr -d '\r' || true)"
    if [ -n "${content_type}" ]; then
      echo "[plugin-bootstrap] ${name} download content-type: ${content_type}" >&2
    fi

    first_line="$(head -n 1 "${archive_path}" | tr -d '\r' || true)"
    if [ -n "${first_line}" ]; then
      echo "[plugin-bootstrap] First response line: ${first_line}" >&2
    fi

    echo "[plugin-bootstrap] Unsupported archive format for ${name} from ${url}" >&2
    exit 1
  fi
}

apply_overrides() {
  label="$1"
  root="$2"

  if [ -d "${root}" ]; then
    echo "[plugin-bootstrap] Applying ${label} overrides from ${root}"
    cp -a "${root}/." "${GAME_ROOT}/"
  fi
}

ensure_srcds_run_launcher() {
  app_root="$(dirname "${GAME_ROOT}")"
  launcher="${app_root}/srcds_run"

  if [ -f "${launcher}" ]; then
    chmod +x "${launcher}" || true
    return 0
  fi

  cat > "${launcher}" <<'EOF'
#!/bin/sh
set -eu

APP_ROOT="$(cd "$(dirname "$0")" && pwd)"

find_target() {
  for target in \
    "$APP_ROOT/game/cs2.sh" \
    "$APP_ROOT/game/csgo.sh" \
    "$APP_ROOT/srcds_linux" \
    "$APP_ROOT/game/bin/linuxsteamrt64/cs2"
  do
    if [ -x "$target" ] || [ -f "$target" ]; then
      printf "%s" "$target"
      return 0
    fi
  done
  return 1
}

TARGET="$(find_target || true)"
if [ -z "$TARGET" ]; then
  echo "[srcds_run shim] Could not find a supported dedicated server launcher under $APP_ROOT" >&2
  exit 1
fi

case "$TARGET" in
  */cs2.sh|*/csgo.sh|*/cs2)
    exec "$TARGET" -dedicated "$@"
    ;;
  */srcds_linux)
    export LD_LIBRARY_PATH="$APP_ROOT/bin:${LD_LIBRARY_PATH:-}"
    exec "$TARGET" "$@"
    ;;
  *)
    exec "$TARGET" "$@"
    ;;
esac
EOF

  chmod +x "${launcher}"
  echo "[plugin-bootstrap] Installed compatibility launcher at ${launcher}"
}

if [ "${FORCE_PLUGIN_REINSTALL}" = "1" ]; then
  echo "[plugin-bootstrap] FORCE_PLUGIN_REINSTALL=1, clearing existing plugin files"
  rm -rf "${GAME_ROOT}/addons/metamod" "${GAME_ROOT}/addons/sourcemod" "${GAME_ROOT}/addons/metamod.vdf"
fi

if [ ! -f "${GAME_ROOT}/addons/metamod.vdf" ]; then
  install_archive "metamod" "${MMS_URL}"
else
  echo "[plugin-bootstrap] Metamod already installed"
fi

if [ ! -d "${GAME_ROOT}/addons/sourcemod" ]; then
  install_archive "sourcemod" "${SM_URL}"
else
  echo "[plugin-bootstrap] Sourcemod already installed"
fi

apply_overrides "tracked" "${DEFAULT_OVERRIDES_ROOT}"
apply_overrides "local" "${LOCAL_OVERRIDES_ROOT}"
ensure_srcds_run_launcher

cat > "${GAME_ROOT}/addons/.bootstrap-manifest" <<EOF
MMS_URL=${MMS_URL}
SM_URL=${SM_URL}
FORCE_PLUGIN_REINSTALL=${FORCE_PLUGIN_REINSTALL}
UPDATED_AT_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

echo "[plugin-bootstrap] Plugin bootstrap complete"
