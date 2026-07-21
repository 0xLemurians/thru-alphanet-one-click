#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

log "RISC-V toolchain v${THRU_VERSION} indiriliyor"
rm -rf "$TOOLCHAIN_DIR"
rm -f "$TOOLCHAIN_ARCHIVE"
mkdir -p "$TOOLCHAIN_DIR"
curl -fL --retry 5 --retry-delay 5 "$TOOLCHAIN_URL" -o "$TOOLCHAIN_ARCHIVE"
printf '%s  %s\n' "$TOOLCHAIN_SHA256" "$TOOLCHAIN_ARCHIVE" | sha256sum -c -
tar -xzf "$TOOLCHAIN_ARCHIVE" --strip-components=1 -C "$TOOLCHAIN_DIR"
"${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc" --version | head -1
ensure_config_value toolchain_path "$TOOLCHAIN_DIR"
ensure_config_value toolchain_version "$THRU_VERSION"

log "C SDK v${THRU_VERSION} indiriliyor"
rm -rf "$C_SDK_DIR" /tmp/thru-c-sdk-src
rm -f "$C_SDK_ARCHIVE"
mkdir -p "$C_SDK_DIR" /tmp/thru-c-sdk-src
curl -fL --retry 5 --retry-delay 5 "$C_SDK_URL" -o "$C_SDK_ARCHIVE"
printf '%s  %s\n' "$C_SDK_SHA256" "$C_SDK_ARCHIVE" | sha256sum -c -
tar -xzf "$C_SDK_ARCHIVE" --strip-components=1 -C /tmp/thru-c-sdk-src
cp -a /tmp/thru-c-sdk-src/. "$C_SDK_DIR/"
find "$C_SDK_DIR" -type f -exec touch {} +

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"
grep -qxF 'export PATH="$HOME/.thru/sdk/toolchain/bin:$PATH"' "${HOME}/.bashrc" || \
  printf '%s\n' 'export PATH="$HOME/.thru/sdk/toolchain/bin:$PATH"' >> "${HOME}/.bashrc"

log "C SDK kütüphanesi hazırlanıyor"
make -C "$C_SDK_DIR" \
  BASEDIR="${C_SDK_DIR}/" \
  BUILDDIR="thru-sdk" \
  all lib include

test -x "${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc" || die "Toolchain derleyicisi bulunamadı."
test -f "${C_SDK_DIR}/thru-sdk/include/thru-sdk/c/tn_sdk.h" || die "tn_sdk.h bulunamadı."
test -f "${C_SDK_DIR}/thru-sdk/lib/libtn_sdk.a" || die "libtn_sdk.a bulunamadı."
test -f "${C_SDK_DIR}/thru-sdk/thru_c_program.mk" || die "thru_c_program.mk bulunamadı."
chmod 600 "$CONFIG_FILE"
ok "Toolchain ve C SDK hazır"
