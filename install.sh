#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/scripts/common.sh"

FULL=false
ASSUME_YES=false

for arg in "$@"; do
  case "$arg" in
    --full)
      FULL=true
      ;;
    --yes|-y)
      ASSUME_YES=true
      ;;
    --help|-h)
      cat <<'HELP'
Kullanım:
  sudo -H bash install.sh          # Sistem + CLI + toolchain + C SDK
  sudo -H bash install.sh --full   # Yukarıdakiler + hesap + faucet + örnek build/upload
  sudo -H bash install.sh --full -y
HELP
      exit 0
      ;;
    *)
      die "Bilinmeyen seçenek: $arg"
      ;;
  esac
done

require_root
require_supported_host

LOG_FILE="/root/thru-one-click-$(date +%Y%m%d-%H%M%S).log"
export LOG_FILE

# Log dosyasını yalnızca root okuyup yazabilsin.
install -m 600 /dev/null "$LOG_FILE"

# Bundan sonraki bütün çıktıları hem ekranda hem güvenli log dosyasında göster.
exec > >(tee -a "$LOG_FILE") 2>&1

cat <<'BANNER'
============================================================
 Thru AlphaNet One-Click DevKit — TESTNET / PRE-RELEASE
============================================================
Bu script:
- Ubuntu paketlerini kurar
- NVM + Node.js + Thru CLI 0.2.38 kurar
- RISC-V toolchain ve C SDK 0.2.38 kurar
- --full ile private key, hesap, faucet, build ve upload yapar

UYARI: Thru private key'i ~/.thru/cli/config.yaml içinde düz metin
olarak tutulur. Bu dosyayı paylaşmayın veya GitHub'a yüklemeyin.
BANNER

if ! $ASSUME_YES; then
  read -r -p "Devam edilsin mi? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || exit 0
fi

bash "${SCRIPT_DIR}/scripts/install_system.sh"
bash "${SCRIPT_DIR}/scripts/install_cli.sh"
bash "${SCRIPT_DIR}/scripts/install_devkit.sh"

if $FULL; then
  bash "${SCRIPT_DIR}/scripts/account.sh"
  bash "${SCRIPT_DIR}/scripts/build_upload.sh"
fi

log "Son doğrulama"
bash "${SCRIPT_DIR}/verify.sh"

ok "Kurulum tamamlandı"
printf 'Log: %s\n' "$LOG_FILE"
