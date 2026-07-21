#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

readonly MAX_STATUS_RETRIES=10
readonly STATUS_RETRY_DELAY=15

FINAL_STATUS_JSON=""

extract_json() {
  sed -n '/^[[:space:]]*[{[]/,$p'
}

print_output() {
  local output=$1
  local json

  json="$(printf '%s\n' "$output" | extract_json)"

  if [[ -n "$json" ]] &&
    printf '%s\n' "$json" | jq -e . >/dev/null 2>&1; then

    printf '%s\n' "$json" | jq .
  else
    printf '%s\n' "$output"
  fi
}

verify_upload_with_retry() {
  local seed=$1
  local attempt
  local status_output
  local status_json
  local current_status

  FINAL_STATUS_JSON=""

  for ((attempt = 1; attempt <= MAX_STATUS_RETRIES; attempt++)); do
    if status_output="$(thru --json uploader status "$seed" 2>&1)"; then
      status_json="$(printf '%s\n' "$status_output" | extract_json)"

      if [[ -n "$status_json" ]] &&
        printf '%s\n' "$status_json" | jq -e . >/dev/null 2>&1; then

        FINAL_STATUS_JSON="$status_json"

        if printf '%s\n' "$status_json" |
          jq -e '
            .uploader_status.summary.status == "uploaded" and
            .uploader_status.summary.upload_exists == true and
            .uploader_status.summary.corrupted_accounts.any == false
          ' >/dev/null; then

          printf '%s\n' "$status_json" | jq .
          return 0
        fi

        current_status="$(
          printf '%s\n' "$status_json" |
            jq -r '.uploader_status.summary.status // "bilinmiyor"'
        )"

        warn "Yükleme henüz doğrulanmadı. Durum: ${current_status}"
      else
        warn "Uploader durum çıktısı geçerli JSON değildi."
        printf '%s\n' "$status_output" >&2
      fi
    else
      warn "Uploader durum sorgusu başarısız (${attempt}/${MAX_STATUS_RETRIES})."
      print_output "$status_output" >&2
    fi

    if ((attempt < MAX_STATUS_RETRIES)); then
      warn "${STATUS_RETRY_DELAY} saniye sonra tekrar kontrol edilecek..."
      sleep "$STATUS_RETRY_DELAY"
    fi
  done

  return 1
}

require_root
load_nvm

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

command -v thru >/dev/null 2>&1 ||
  die "Thru CLI bulunamadı."

command -v jq >/dev/null 2>&1 ||
  die "jq bulunamadı."

command -v openssl >/dev/null 2>&1 ||
  die "OpenSSL bulunamadı."

log "Örnek C projesi hazırlanıyor"

rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECTS_DIR"
chmod 700 "$PROJECTS_DIR"

cd "$PROJECTS_DIR"

thru dev init c "$PROJECT_NAME" --path "$PROJECTS_DIR"

log "Örnek program derleniyor"

cd "$PROJECT_DIR"

make clean >/dev/null 2>&1 || true
make -j"$(nproc)"

[[ -f "$BINARY_REL" ]] ||
  die "Binary oluşmadı: ${PROJECT_DIR}/${BINARY_REL}"

ls -lh "$BINARY_REL"
sha256sum "$BINARY_REL"

log "Benzersiz seed ile AlphaNet'e yükleniyor"

seed="thru_demo_$(date +%s)_$(openssl rand -hex 3)"

mkdir -p "$THRU_HOME"
chmod 700 "$THRU_HOME"

install -m 600 /dev/null "${THRU_HOME}/last-upload-seed"
printf '%s\n' "$seed" > "${THRU_HOME}/last-upload-seed"

upload_command_succeeded=false

if upload_output="$(
  thru --json uploader upload "$seed" "$BINARY_REL" 2>&1
)"; then
  upload_command_succeeded=true
  print_output "$upload_output"
else
  warn "Upload komutu hata verdi."
  warn "İşlem zincire ulaşmış olabileceği için seed durumu kontrol edilecek."
  print_output "$upload_output" >&2
fi

if $upload_command_succeeded; then
  upload_json="$(printf '%s\n' "$upload_output" | extract_json)"

  if [[ -n "$upload_json" ]] &&
    printf '%s\n' "$upload_json" | json_has_success; then

    ok "Upload işlemi ağa gönderildi"
  else
    warn "Upload çıktısında başarı durumu bulunamadı; durum sorgulanacak."
  fi
fi

log "Program yükleme durumu doğrulanıyor"

if ! verify_upload_with_retry "$seed"; then
  die "Program yüklemesi ${MAX_STATUS_RETRIES} denemede doğrulanamadı."
fi

ok "Program başarıyla yüklendi"
printf 'Seed: %s\n' "$seed"
printf 'Seed dosyası: %s\n' "${THRU_HOME}/last-upload-seed"
