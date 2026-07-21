#!/usr/bin/env bash
set -Eeuo pipefail

readonly THRU_VERSION="0.2.38"
readonly NVM_VERSION="0.40.3"
readonly NODE_MAJOR="24"
readonly THRU_HOME="${HOME}/.thru"
readonly TOOLCHAIN_DIR="${THRU_HOME}/sdk/toolchain"
readonly C_SDK_DIR="${THRU_HOME}/sdk/c"
readonly CONFIG_FILE="${THRU_HOME}/cli/config.yaml"
readonly PROJECTS_DIR="${HOME}/thru-projects"
readonly PROJECT_NAME="my-first-thru-program"
readonly PROJECT_DIR="${PROJECTS_DIR}/${PROJECT_NAME}"
readonly BINARY_REL="build/thruvm/bin/my_first_thru_program_c.bin"
readonly TOOLCHAIN_ARCHIVE="/tmp/thru-toolchain-v${THRU_VERSION}.tar.gz"
readonly C_SDK_ARCHIVE="/tmp/thru-program-sdk-c-v${THRU_VERSION}.tar.gz"
readonly TOOLCHAIN_URL="https://github.com/Unto-Labs/thru/releases/download/v${THRU_VERSION}/thru-toolchain-Linux-x86_64-v${THRU_VERSION}.tar.gz"
readonly C_SDK_URL="https://github.com/Unto-Labs/thru/releases/download/v${THRU_VERSION}/thru-program-sdk-c-v${THRU_VERSION}.tar.gz"
readonly TOOLCHAIN_SHA256="48837e2191ec697ae63e368d00c911c3e739c4fc8e7c0f4b56b59ef0aa7c244a"
readonly C_SDK_SHA256="e691b4164b209ba7d695641f76abd8afbebefd20f6fabccd5f7611cdeba632c8"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*" >&2; }
die() { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  local line_no=${1:-unknown}
  printf '\n\033[1;31mKurulum durdu (satır %s, çıkış kodu %s).\033[0m\n' "$line_no" "$exit_code" >&2
  printf 'Log dosyası: %s\n' "${LOG_FILE:-oluşturulmadı}" >&2
  exit "$exit_code"
}
trap 'on_error $LINENO' ERR

require_root() {
  [[ ${EUID} -eq 0 ]] || die "Bu script root olarak çalıştırılmalı: sudo -H bash install.sh"
  [[ ${HOME} == "/root" ]] || warn "HOME=${HOME}. Önerilen kullanım: sudo -H bash install.sh"
}

require_supported_host() {
  [[ -r /etc/os-release ]] || die "/etc/os-release bulunamadı."
  # shellcheck disable=SC1091
  source /etc/os-release
  [[ ${ID:-} == "ubuntu" ]] || die "Yalnızca Ubuntu destekleniyor. Algılanan: ${ID:-bilinmiyor}"
  [[ ${VERSION_ID:-} == "24.04" ]] || die "Ubuntu 24.04 gerekli. Algılanan: ${VERSION_ID:-bilinmiyor}"
  [[ $(uname -m) == "x86_64" ]] || die "x86_64 gerekli. Algılanan: $(uname -m)"

  local free_kb
  free_kb=$(df --output=avail / | tail -1 | tr -d ' ')
  (( free_kb >= 8 * 1024 * 1024 )) || die "En az 8 GB boş disk alanı gerekli."
}

load_nvm() {
  export NVM_DIR="${HOME}/.nvm"
  # shellcheck disable=SC1090
  [[ -s "${NVM_DIR}/nvm.sh" ]] && source "${NVM_DIR}/nvm.sh"
}

ensure_config_value() {
  local key=$1 value=$2
  mkdir -p "$(dirname "$CONFIG_FILE")"
  touch "$CONFIG_FILE"
  if grep -q "^${key}:" "$CONFIG_FILE"; then
    sed -i "s|^${key}:.*|${key}: ${value}|" "$CONFIG_FILE"
  else
    printf '%s: %s\n' "$key" "$value" >> "$CONFIG_FILE"
  fi
}

json_has_success() {
  jq -e '.. | objects | select(.status? == "success")' >/dev/null 2>&1
}
