#!/bin/sh
set -eu

SECRETS_DIR="${SECRETS_DIR:-/secrets}"
TOKEN_FILE="${SECRETS_DIR}/srcds_token"
RCON_FILE="${SECRETS_DIR}/srcds_rconpw"
FORCE="${FORCE:-0}"

trim_newlines() {
  tr -d '\r\n'
}

confirm_overwrite() {
  if [ "${FORCE}" = "1" ]; then
    return 0
  fi

  if [ -t 0 ]; then
    printf "Secret files already exist in %s. Overwrite? [y/N]: " "${SECRETS_DIR}" >&2
    IFS= read -r answer
    case "${answer}" in
      y|Y|yes|YES) return 0 ;;
      *) return 1 ;;
    esac
  fi

  return 1
}

prompt_secret() {
  label="$1"
  value=""

  while [ -z "${value}" ]; do
    printf "%s: " "${label}" >&2
    old_stty="$(stty -g)"
    stty -echo
    IFS= read -r value || true
    stty "${old_stty}"
    printf "\n" >&2
    value="$(printf "%s" "${value}" | trim_newlines)"

    if [ -z "${value}" ]; then
      echo "Value cannot be empty." >&2
    fi
  done

  printf "%s" "${value}"
}

write_secret() {
  value="$1"
  file="$2"
  printf "%s" "${value}" > "${file}"
  chmod 600 "${file}" || true
}

mkdir -p "${SECRETS_DIR}"

if [ -f "${TOKEN_FILE}" ] || [ -f "${RCON_FILE}" ]; then
  if ! confirm_overwrite; then
    echo "No changes made." >&2
    exit 0
  fi
fi

if [ -n "${SRCDS_TOKEN:-}" ] || [ -n "${SRCDS_RCONPW:-}" ]; then
  if [ -z "${SRCDS_TOKEN:-}" ] || [ -z "${SRCDS_RCONPW:-}" ]; then
    echo "When using env input, set both SRCDS_TOKEN and SRCDS_RCONPW." >&2
    exit 1
  fi

  token="$(printf "%s" "${SRCDS_TOKEN}" | trim_newlines)"
  rconpw="$(printf "%s" "${SRCDS_RCONPW}" | trim_newlines)"
else
  if [ ! -t 0 ]; then
    echo "Interactive mode requires a TTY. Re-run with -it or set SRCDS_TOKEN and SRCDS_RCONPW env vars." >&2
    exit 1
  fi

  token="$(prompt_secret "Enter SRCDS_TOKEN (GSLT)")"
  rconpw="$(prompt_secret "Enter SRCDS_RCONPW")"
fi

if [ -z "${token}" ] || [ -z "${rconpw}" ]; then
  echo "Secret values must not be empty." >&2
  exit 1
fi

write_secret "${token}" "${TOKEN_FILE}"
write_secret "${rconpw}" "${RCON_FILE}"

echo "Wrote secret files:"
echo "- ${TOKEN_FILE}"
echo "- ${RCON_FILE}"
