#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
load_nvm
export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

log "Örnek C projesi hazırlanıyor"
rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECTS_DIR"
cd "$PROJECTS_DIR"
thru dev init c "$PROJECT_NAME" --path "$PROJECTS_DIR"

log "Örnek program derleniyor"
cd "$PROJECT_DIR"
make clean >/dev/null 2>&1 || true
make -j"$(nproc)"
test -f "$BINARY_REL" || die "Binary oluşmadı: ${PROJECT_DIR}/${BINARY_REL}"
ls -lh "$BINARY_REL"
sha256sum "$BINARY_REL"

log "Benzersiz seed ile AlphaNet'e yükleniyor"
seed="thru_demo_$(date +%s)_$(openssl rand -hex 3)"
printf '%s\n' "$seed" > "${THRU_HOME}/last-upload-seed"
chmod 600 "${THRU_HOME}/last-upload-seed"
upload_json=$(thru --json uploader upload "$seed" "$BINARY_REL")
printf '%s\n' "$upload_json" | jq .
printf '%s\n' "$upload_json" | json_has_success || die "Program yüklemesi başarısız."

status_json=$(thru --json uploader status "$seed")
printf '%s\n' "$status_json" | jq .
printf '%s\n' "$status_json" | jq -e \
  '.uploader_status.summary.status == "uploaded" and
   .uploader_status.summary.upload_exists == true and
   .uploader_status.summary.corrupted_accounts.any == false' >/dev/null || \
  die "Yükleme doğrulanamadı."

ok "Program başarıyla yüklendi"
printf 'Seed: %s\n' "$seed"
printf 'Seed dosyası: %s\n' "${THRU_HOME}/last-upload-seed"
