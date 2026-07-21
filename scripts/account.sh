#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
load_nvm

log "Default anahtar kontrol ediliyor"
keys_json=$(thru --json keys list)
if ! printf '%s\n' "$keys_json" | jq -e '.keys.list | index("default")' >/dev/null; then
  thru keys generate default
fi
chmod 600 "$CONFIG_FILE"

log "On-chain hesap kontrol ediliyor"
if account_json=$(thru --json getaccountinfo default 2>/dev/null); then
  printf '%s\n' "$account_json" | jq .
  ok "Hesap zaten mevcut"
else
  create_json=$(thru --json account create default)
  printf '%s\n' "$create_json" | jq .
  printf '%s\n' "$create_json" | json_has_success || die "On-chain hesap oluşturulamadı."
fi

log "Test bakiyesi kontrol ediliyor"
balance_json=$(thru --json getbalance default)
balance=$(printf '%s\n' "$balance_json" | jq -r '.balance.balance // 0')
if [[ "$balance" =~ ^[0-9]+$ ]] && (( balance < 10000 )); then
  faucet_json=$(thru --json faucet withdraw default 10000)
  printf '%s\n' "$faucet_json" | jq .
  printf '%s\n' "$faucet_json" | json_has_success || die "Faucet işlemi başarısız."
fi
thru --json getbalance default | jq .
ok "Anahtar, hesap ve test bakiyesi hazır"
