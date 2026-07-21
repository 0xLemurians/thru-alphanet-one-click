#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/scripts/common.sh"
load_nvm
export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

echo "=== SİSTEM ==="
source /etc/os-release
echo "$PRETTY_NAME"
echo "Mimari: $(uname -m)"
echo "CPU: $(nproc)"

echo
echo "=== SÜRÜMLER ==="
printf 'NVM: '; nvm --version
printf 'Node: '; node --version
printf 'npm: '; npm --version
printf 'Thru: '; thru --version
"${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc" --version | head -1

echo
echo "=== SDK ==="
for file in \
  "${C_SDK_DIR}/thru-sdk/include/thru-sdk/c/tn_sdk.h" \
  "${C_SDK_DIR}/thru-sdk/lib/libtn_sdk.a" \
  "${C_SDK_DIR}/thru-sdk/thru_c_program.mk"; do
  [[ -f "$file" ]] && echo "HAZIR: $file" || echo "EKSİK: $file"
done

echo
echo "=== AĞ VE HESAP ==="
thru --json getversion | jq .
thru --json getbalance default | jq .

if [[ -f "${THRU_HOME}/last-upload-seed" ]]; then
  seed=$(cat "${THRU_HOME}/last-upload-seed")
  echo
echo "=== SON YÜKLEME: $seed ==="
  thru --json uploader status "$seed" | jq .
fi
