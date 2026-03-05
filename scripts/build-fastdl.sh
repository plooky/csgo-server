#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="${1:-${ROOT_DIR}/data/csgo/csgo}"
TARGET_DIR="${2:-${ROOT_DIR}/fastdl/csgo}"

if [[ ! -d "${SOURCE_DIR}" ]]; then
  echo "Source directory not found: ${SOURCE_DIR}" >&2
  exit 1
fi

mkdir -p "${TARGET_DIR}"

echo "[fastdl] Syncing from ${SOURCE_DIR} to ${TARGET_DIR}"
rsync -a --delete --prune-empty-dirs \
  --include "*/" \
  --include "*.bsp" \
  --include "*.nav" \
  --include "*.txt" \
  --include "*.res" \
  --include "*.wad" \
  --include "*.vtf" \
  --include "*.vmt" \
  --include "*.mdl" \
  --include "*.phy" \
  --include "*.vtx" \
  --include "*.vvd" \
  --include "*.wav" \
  --include "*.mp3" \
  --exclude "*" \
  "${SOURCE_DIR}/" "${TARGET_DIR}/"

echo "[fastdl] Building .bz2 files"
find "${TARGET_DIR}" -type f \
  \( -name "*.bsp" -o -name "*.nav" -o -name "*.txt" -o -name "*.res" -o \
     -name "*.wad" -o -name "*.vtf" -o -name "*.vmt" -o -name "*.mdl" -o \
     -name "*.phy" -o -name "*.vtx" -o -name "*.vvd" -o -name "*.wav" -o \
     -name "*.mp3" \) -print0 |
while IFS= read -r -d '' file; do
  bzip2 -fk "${file}"
done

echo "[fastdl] Completed"
