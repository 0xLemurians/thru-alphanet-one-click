#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/scripts/common.sh"

extract_json() {
  sed -n '/^[[:space:]]*[{[]/,$p'
}

require_root
load_nvm

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

[[ -r /etc/os-release ]] ||
  die "/etc/os-release bulunamadı."

# shellcheck disable=SC1091
source /etc/os-release

[[ ${ID:-} == "ubuntu" ]] ||
  die "Yalnızca Ubuntu destekleniyor."

[[ ${VERSION_ID:-} == "24.04" ]] ||
  die "Ubuntu 24.04 gerekli."

[[ $(uname -m) == "x86_64" ]] ||
  die "x86_64 mimarisi gerekli."

echo "=== SİSTEM ==="
printf '%s\n' "$PRETTY_NAME"
printf 'Mimari: %s\n' "$(uname -m)"
printf 'CPU: %s\n' "$(nproc)"

echo
echo "=== SÜRÜMLER ==="

for command_name in node npm thru jq; do
  command -v "$command_name" >/dev/null 2>&1 ||
    die "$command_name bulunamadı."
done

declare -F nvm >/dev/null 2>&1 ||
  die "NVM bulunamadı."

compiler="${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc"

[[ -x "$compiler" ]] ||
  die "RISC-V derleyicisi bulunamadı."

nvm_version="$(nvm --version)"
node_version="$(node --version)"
npm_version="$(npm --version)"
thru_version="$(thru --version)"
toolchain_version="$("$compiler" --version | sed -n '1p')"

printf 'NVM: %s\n' "$nvm_version"
printf 'Node: %s\n' "$node_version"
printf 'npm: %s\n' "$npm_version"
printf 'Thru: %s\n' "$thru_version"
printf 'Toolchain: %s\n' "$toolchain_version"

if [[ "$nvm_version" != "$NVM_INSTALLER_VERSION" ]]; then
  die "Beklenen NVM sürümü ${NVM_INSTALLER_VERSION}, bulunan ${nvm_version}."
fi

case "$node_version" in
  "v${NODE_MAJOR}."*)
    ;;
  *)
    die "Node.js ${NODE_MAJOR} gerekli, bulunan ${node_version}."
    ;;
esac

case "$thru_version" in
  *"${THRU_VERSION}"*)
    ;;
  *)
    die "Beklenen Thru CLI sürümü ${THRU_VERSION}, bulunan ${thru_version}."
    ;;
esac

echo
echo "=== SDK ==="

sdk_files=(
  "${C_SDK_DIR}/thru-sdk/include/thru-sdk/c/tn_sdk.h"
  "${C_SDK_DIR}/thru-sdk/lib/libtn_sdk.a"
  "${C_SDK_DIR}/thru-sdk/thru_c_program.mk"
)

for file in "${sdk_files[@]}"; do
  [[ -f "$file" ]] ||
    die "SDK dosyası eksik: $file"

  printf 'HAZIR: %s\n' "$file"
done

echo
echo "=== AĞ ==="

version_output="$(thru --json getversion 2>&1)" || {
  printf '%s\n' "$version_output" >&2
  die "AlphaNet bağlantı komutu başarısız oldu."
}

version_json="$(printf '%s\n' "$version_output" | extract_json)"

[[ -n "$version_json" ]] || {
  printf '%s\n' "$version_output" >&2
  die "AlphaNet çıktısında JSON bulunamadı."
}

printf '%s\n' "$version_json" | jq . ||
  die "AlphaNet çıktısı geçerli JSON değil."

printf '%s\n' "$version_json" | json_has_success ||
  die "AlphaNet bağlantısı doğrulanamadı."

ok "AlphaNet bağlantısı doğrulandı"

echo
echo "=== HESAP ==="

if balance_output="$(thru --json getbalance default 2>&1)"; then
  balance_json="$(printf '%s\n' "$balance_output" | extract_json)"

  if [[ -n "$balance_json" ]] &&
    printf '%s\n' "$balance_json" | jq -e . >/dev/null 2>&1; then

    printf '%s\n' "$balance_json" | jq .
  else
    printf '%s\n' "$balance_output"
  fi

  ok "Default hesap ve bakiye kontrol edildi"
else
  warn "Default hesap bulunamadı veya bakiye okunamadı."
  warn "Hesap oluşturmak için install.sh --full çalıştırın."
fi

if [[ -f "${THRU_HOME}/last-upload-seed" ]]; then
  seed="$(<"${THRU_HOME}/last-upload-seed")"

  [[ -n "$seed" ]] ||
    die "Son upload seed dosyası boş."

  echo
  printf '=== SON YÜKLEME: %s ===\n' "$seed"

  status_output="$(thru --json uploader status "$seed" 2>&1)" || {
    printf '%s\n' "$status_output" >&2
    die "Uploader durumu alınamadı."
  }

  status_json="$(printf '%s\n' "$status_output" | extract_json)"

  [[ -n "$status_json" ]] || {
    printf '%s\n' "$status_output" >&2
    die "Uploader çıktısında JSON bulunamadı."
  }

  printf '%s\n' "$status_json" | jq . ||
    die "Uploader çıktısı geçerli JSON değil."

  if ! printf '%s\n' "$status_json" |
    jq -e '
      .uploader_status.summary.status == "uploaded" and
      .uploader_status.summary.upload_exists == true and
      .uploader_status.summary.corrupted_accounts.any == false
    ' >/dev/null; then

    die "Son program yüklemesi doğrulanamadı."
  fi

  ok "Son program yüklemesi doğrulandı"
else
  warn "Henüz program upload kaydı bulunmuyor."
  warn "--full kurulumu yapılmadıysa bu normaldir."
fi

ok "Doğrulama başarıyla tamamlandı"
