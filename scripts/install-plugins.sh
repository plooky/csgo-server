#!/bin/sh
set -eu

GAME_ROOT="${GAME_ROOT:-/home/steam/csgo-dedicated/csgo}"
OVERRIDES_ROOT="${OVERRIDES_ROOT:-/overrides/csgo}"
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

install_archive() {
  name="$1"
  url="$2"
  archive_path="${TMP_DIR}/${name}.tar.gz"

  echo "[plugin-bootstrap] Downloading ${name} from ${url}"
  curl -fsSL --retry 3 --retry-delay 2 "${url}" -o "${archive_path}"
  tar -xzf "${archive_path}" -C "${GAME_ROOT}"
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

if [ -d "${OVERRIDES_ROOT}" ]; then
  echo "[plugin-bootstrap] Applying tracked overrides from ${OVERRIDES_ROOT}"
  cp -a "${OVERRIDES_ROOT}/." "${GAME_ROOT}/"
fi

cat > "${GAME_ROOT}/addons/.bootstrap-manifest" <<EOF
MMS_URL=${MMS_URL}
SM_URL=${SM_URL}
FORCE_PLUGIN_REINSTALL=${FORCE_PLUGIN_REINSTALL}
UPDATED_AT_UTC=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF

echo "[plugin-bootstrap] Plugin bootstrap complete"
