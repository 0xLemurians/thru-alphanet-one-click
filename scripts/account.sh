#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

readonly MAX_RETRIES=10
readonly RETRY_DELAY=15

LAST_OUTPUT=""

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

retry_command() {
  local description=$1
  shift

  local attempt
  LAST_OUTPUT=""

  for ((attempt = 1; attempt <= MAX_RETRIES; attempt++)); do
    if LAST_OUTPUT="$("$@" 2>&1)"; then
      return 0
    fi

    warn "${description} başarısız (${attempt}/${MAX_RETRIES})."
    print_output "$LAST_OUTPUT" >&2

    if ((attempt < MAX_RETRIES)); then
      warn "${RETRY_DELAY} saniye sonra tekrar denenecek..."
      sleep "$RETRY_DELAY"
    fi
  done

  return 1
}

require_root
load_nvm

command -v thru >/dev/null 2>&1 ||
  die "Thru CLI bulunamadı."

command -v jq >/dev/null 2>&1 ||
  die "jq bulunamadı."

log "Default anahtar kontrol ediliyor"

keys_output="$(thru --json keys list 2>&1)" || {
  print_output "$keys_output" >&2
  die "Anahtar listesi okunamadı."
}

keys_json="$(printf '%s\n' "$keys_output" | extract_json)"

[[ -n "$keys_json" ]] ||
  die "Anahtar listesinde JSON bulunamadı."

if printf '%s\n' "$keys_json" |
  jq -e '.keys.list | index("default")' >/dev/null; then

  ok "Default anahtar zaten mevcut"
else
  log "Default anahtar oluşturuluyor"

  generate_output="$(thru keys generate default 2>&1)" || {
    printf '%s\n' "$generate_output" >&2
    die "Default anahtar oluşturulamadı."
  }

  ok "Default anahtar oluşturuldu"
fi

[[ -f "$CONFIG_FILE" ]] ||
  die "Yapılandırma dosyası bulunamadı: ${CONFIG_FILE}"

chmod 600 "$CONFIG_FILE"

log "On-chain hesap kontrol ediliyor"

account_exists=false
balance_output=""

for ((attempt = 1; attempt <= 5; attempt++)); do
  if balance_output="$(thru --json getbalance default 2>&1)"; then
    account_exists=true
    break
  fi

  if ((attempt < 5)); then
    warn "Hesap sorgusu başarısız (${attempt}/5), 10 saniye bekleniyor..."
    sleep 10
  fi
done

if $account_exists; then
  ok "On-chain hesap zaten mevcut"
else
  log "On-chain hesap oluşturuluyor"

  account_ready=false

  for ((attempt = 1; attempt <= MAX_RETRIES; attempt++)); do
    if create_output="$(thru --json account create default 2>&1)"; then
      print_output "$create_output"
      account_ready=true
      break
    fi

    warn "Hesap oluşturma başarısız (${attempt}/${MAX_RETRIES})."
    print_output "$create_output" >&2

    # Komut hata vermiş olsa bile hesap önceki denemede oluşmuş olabilir.
    sleep 5

    if balance_output="$(thru --json getbalance default 2>&1)"; then
      warn "Hesap zaten zincirde mevcut."
      account_ready=true
      break
    fi

    if ((attempt < MAX_RETRIES)); then
      warn "${RETRY_DELAY} saniye sonra tekrar denenecek..."
      sleep "$RETRY_DELAY"
    fi
  done

  $account_ready ||
    die "On-chain hesap oluşturulamadı."
fi

log "Test bakiyesi kontrol ediliyor"

retry_command \
  "Bakiye sorgulama" \
  thru --json getbalance default ||
  die "Hesap bakiyesi alınamadı."

balance_json="$(printf '%s\n' "$LAST_OUTPUT" | extract_json)"

[[ -n "$balance_json" ]] ||
  die "Bakiye çıktısında JSON bulunamadı."

printf '%s\n' "$balance_json" | jq .

balance="$(
  printf '%s\n' "$balance_json" |
    jq -r '.balance.balance // 0'
)"

if [[ "$balance" =~ ^[0-9]+$ ]] && ((balance < 10000)); then
  log "Faucet üzerinden test bakiyesi isteniyor"

  retry_command \
    "Faucet işlemi" \
    thru --json faucet withdraw default 10000 ||
    die "Faucet işlemi tamamlanamadı."

  print_output "$LAST_OUTPUT"
fi

log "Son bakiye doğrulanıyor"

retry_command \
  "Son bakiye sorgulama" \
  thru --json getbalance default ||
  die "Son bakiye doğrulanamadı."

print_output "$LAST_OUTPUT"

chmod 600 "$CONFIG_FILE"

ok "Anahtar, hesap ve test bakiyesi hazır"
