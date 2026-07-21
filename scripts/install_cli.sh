#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

readonly NODE_VERSION="24.18.0"
readonly NVM_INSTALL_SHA256="2d8359a64a3cb07c02389ad88ceecd43f2fa469c06104f92f98df5b6f315275f"
readonly NVM_INSTALL_SCRIPT="/tmp/nvm-install-${NVM_INSTALLER_VERSION}.sh"

require_root
require_supported_host

log "NVM ${NVM_INSTALLER_VERSION} ve Node.js ${NODE_VERSION} kuruluyor"

export NVM_DIR="${HOME}/.nvm"

mkdir -p "$NVM_DIR"
chmod 700 "$NVM_DIR"

if [[ ! -s "${NVM_DIR}/nvm.sh" ]]; then
  rm -f "$NVM_INSTALL_SCRIPT"

  curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 5 \
    --retry-delay 5 \
    "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_INSTALLER_VERSION}/install.sh" \
    --output "$NVM_INSTALL_SCRIPT"

  log "NVM kurulum dosyasının SHA-256 değeri doğrulanıyor"

  printf '%s  %s\n' \
    "$NVM_INSTALL_SHA256" \
    "$NVM_INSTALL_SCRIPT" |
    sha256sum --check -

  chmod 700 "$NVM_INSTALL_SCRIPT"
  bash "$NVM_INSTALL_SCRIPT"

  rm -f "$NVM_INSTALL_SCRIPT"
fi

load_nvm

declare -F nvm >/dev/null 2>&1 ||
  die "NVM yüklenemedi."

installed_nvm_version="$(nvm --version)"

[[ "$installed_nvm_version" == "$NVM_INSTALLER_VERSION" ]] ||
  die "Beklenen NVM sürümü ${NVM_INSTALLER_VERSION}, bulunan ${installed_nvm_version}."

ok "NVM ${installed_nvm_version} hazır"

nvm install "$NODE_VERSION"
nvm alias default "$NODE_VERSION"
nvm use "$NODE_VERSION"

installed_node_version="$(node --version)"

[[ "$installed_node_version" == "v${NODE_VERSION}" ]] ||
  die "Node.js ${NODE_VERSION} kurulamadı. Bulunan: ${installed_node_version}"

ok "Node.js ${installed_node_version} hazır"

log "Thru CLI ${THRU_VERSION} kuruluyor"

npm install --global "thru@${THRU_VERSION}"

installed_thru_version="$(thru --version)"

case "$installed_thru_version" in
  *"${THRU_VERSION}"*)
    ;;
  *)
    die "Beklenen Thru CLI sürümü ${THRU_VERSION}, bulunan: ${installed_thru_version}"
    ;;
esac

ok "Thru CLI ${installed_thru_version} hazır"

log "AlphaNet bağlantısı doğrulanıyor"

version_output="$(thru --json getversion 2>&1)" || {
  printf '%s\n' "$version_output" >&2
  die "Thru AlphaNet bağlantısı başarısız."
}

json_output="$(
  printf '%s\n' "$version_output" |
    sed -n '/^[[:space:]]*[{[]/,$p'
)"

if [[ -n "$json_output" ]] &&
  printf '%s\n' "$json_output" | jq -e . >/dev/null 2>&1; then

  printf '%s\n' "$json_output" | jq .

  printf '%s\n' "$json_output" | json_has_success ||
    die "AlphaNet başarı durumu doğrulanamadı."
else
  printf '%s\n' "$version_output"

  warn "CLI çıktısı saf JSON değildi; bağlantı komutunun çıkış kodu kullanıldı."
fi

mkdir -p "$THRU_HOME"
chmod 700 "$THRU_HOME"

if [[ -f "$CONFIG_FILE" ]]; then
  chmod 600 "$CONFIG_FILE"
fi

ok "NVM, Node.js ve Thru CLI hazır"
