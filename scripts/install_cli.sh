#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

log "NVM ${NVM_VERSION} ve Node.js ${NODE_MAJOR} kuruluyor"
if [[ ! -s "${HOME}/.nvm/nvm.sh" ]]; then
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh" | bash
fi
load_nvm
command -v nvm >/dev/null || die "NVM yüklenemedi."
nvm install "${NODE_MAJOR}"
nvm alias default "${NODE_MAJOR}"
nvm use "${NODE_MAJOR}"

log "Thru CLI ${THRU_VERSION} kuruluyor"
npm install -g "thru@${THRU_VERSION}"
thru --version | grep -q "${THRU_VERSION}" || die "Beklenen Thru CLI sürümü kurulamadı."

log "AlphaNet bağlantısı doğrulanıyor"
version_json=$(thru --json getversion)
printf '%s\n' "$version_json" | jq .
printf '%s\n' "$version_json" | json_has_success || die "Thru AlphaNet bağlantısı başarısız."
chmod 700 "${THRU_HOME}" 2>/dev/null || true
[[ -f "$CONFIG_FILE" ]] && chmod 600 "$CONFIG_FILE"
ok "NVM, Node.js ve Thru CLI hazır"
