#!/usr/bin/env bash
set -Eeuo pipefailSüper kanka ✅ Şimdi **`verify.sh`** dosyasını düzelt
umask 077

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/scripts/common.sh"

require_root
load_nvm
export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

[[ -r /etc/os-release ]] || die "/etc/os-release bulunamadı."

# shellcheck disable=SC1091
source /etc/os-release

[[ ${ID:-} == "ubuntu" ]] || die "Yalnızca Ubuntu destekleniyor."
[[ ${VERSION_ID:-} == "24.04" ]] || die "Ubuntu 24.04 gerekli."
[[ $(uname -m) == "x86_64" ]] || die "x86_64 mimarisi gerekli."

echo "=== SİSTEM ==="
echo "$PRETTY_NAME"
echo "Mimari: $(uname -m)"
echo "CPU: $(nproc)"

echo
echo "=== SÜRÜMLER ==="

for command_name in nvm node npm thru jq; do
  command -v "$command_name" >/dev/null ||
    die "$command_name bulunamadı."
done

test -x "${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc" ||
  die "RISC-V derleyicisi bulunamadı."

nvm_version=$(nvm --version)
node_version=$(node --version)
npm_version=$(npm --version)
thru_version=$(thru --version)
toolchain_version=$(
  "${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc" --version |
    sed -n '1p'
)

printf 'NVM: %s\n' "$nvm_version"
printf 'Node: %s\n' "$node_version"
printf 'npm: %s\n' "$npm_version"
printf 'Thru: %s\n' "$thru_version"
printf 'Toolchain: %s\n' "$toolchain_version"

[[ "$nvm_version" == "$NVM_VERSION" ]] ||
  die "Beklenen NVM sürümü ${NVM_VERSION}, bulunan ${nvm_version}."

[[ "$node_version" == v${NODE_MAJOR}.* ]] ||
  die "Node.js ${NODE_MAJOR} gerekli, bulunan ${node_version}."

[[ "$thru_version" == *"${THRU_VERSION}"* ]] ||
  die "Beklenen Thru CLI sürümü ${THRU_VERSION}, bulunan ${thru_version}."

echo
echo "=== SDK ==="

sdk_files=(
  "${C_SDK_DIR}/thru-sdk/include/thru-sdk/c/tn_sdk.h"
  "${C_SDK_DIR}/thru-sdk/lib/libtn_sdk.a"
  "${C_SDK_DIR}/thru-sdk/thru_c_program.mk"
)

for file in "${sdk_files[@]}"; do
  [[ -f "$file" ]] || die "SDK dosyası eksik: $file"
  printf 'HAZIR: %s\n' "$file"
done

echo
echo "=== AĞ ==="

version_json=$(thru --json getversion)
printf '%s\n' "$version_json" | jq .

printf '%s\n' "$version_json" | json_has_success ||
  die "AlphaNet bağlantısı doğrulanamadı."

echo
echo "=== HESAP ==="

if keys_json=$(thru --json keys list 2>/dev/null); then
  if printf '%s\n' "$keys_json" |
    jq -e '.keys.list | index("default")' >/dev/null; then

    balance_json=$(thru --json getbalance default)
    printf '%s\n' "$balance_json" | jq .

    ok "Default hesap ve bakiye kontrol edildi"
  else
    warn "Default anahtar bulunamadı. Normal kurulumda bu beklenebilir."
    warn "Hesap oluşturmak için install.sh --full çalıştırın."
  fi
else
  warn "Anahtar listesi okunamadı."
fi

if [[ -f "${THRU_HOME}/last-upload-seed" ]]; then
  seed=$(<"${THRU_HOME}/last-upload-seed")

  [[ -n "$seed" ]] ||
    die "Son upload seed dosyası boş."

  echo
  echo "=== SON YÜKLEME: $seed ==="

  status_json=$(thru --json uploader status "$seed")
  printf '%s\n' "$status_json" | jq .

  printf '%s\n' "$status_json" |
    jq -e \
      '.uploader_status.summary.status == "uploaded" and
       .uploader_status.summary.upload_exists == true and
       .uploader_status.summary.corrupted_accounts.any == false' \
      >/dev/null ||
    die "Son program yüklemesi doğrulanamadı."
else
  warn "Henüz program upload kaydı bulunmuyor."
  warn "--full kurulumu yapılmadıysa bu normaldir."
fi

ok "Doğrulama başarıyla tamamlandı"
