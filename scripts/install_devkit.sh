#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
require_supported_host

log
 "RISC-V toolchain v${THRU_VERSION} indiriliyor"

rm -rf "$TOOLCHAIN_DIR"
rm -f "$TOOLCHAIN_ARCHIVE"

mkdir -p "$TOOLCHAIN_DIR"
chmod 700 "$THRU_HOME" "${THRU_HOME}/sdk" "$TOOLCHAIN_DIR"

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 5 \
  --show-error \
  "$TOOLCHAIN_URL" \
  --output "$TOOLCHAIN_ARCHIVE"

printf '%s  %s\n' \
  "$TOOLCHAIN_SHA256" \
  "$TOOLCHAIN_ARCHIVE" |
  sha256sum --check -

tar \
  --extract \
  --gzip \
  --file "$TOOLCHAIN_ARCHIVE" \
  --strip-components=1 \
  --directory "$TOOLCHAIN_DIR"

toolchain_version="$(
  "${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc" --version |
    sed -n '1p'
)"

printf '%s\n' "$toolchain_version"

ensure_config_value "toolchain_path" "$TOOLCHAIN_DIR"
ensure_config_value "toolchain_version" "$THRU_VERSION"

log "C SDK v${THRU_VERSION} indiriliyor"

rm -rf "$C_SDK_DIR" /tmp/thru-c-sdk-src
rm -f "$C_SDK_ARCHIVE"

mkdir -p "$C_SDK_DIR" /tmp/thru-c-sdk-src
chmod 700 "$C_SDK_DIR" /tmp/thru-c-sdk-src

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 5 \
  --show-error \
  "$C_SDK_URL" \
  --output "$C_SDK_ARCHIVE"

printf '%s  %s\n' \
  "$C_SDK_SHA256" \
  "$C_SDK_ARCHIVE" |
  sha256sum --check -

tar \
  --extract \
  --gzip \
  --file "$C_SDK_ARCHIVE" \
  --strip-components=1 \
  --directory /tmp/thru-c-sdk-src

cp -a /tmp/thru-c-sdk-src/. "$C_SDK_DIR/"

# İndirilmiş kaynakların zaman damgalarını günceller.
find "$C_SDK_DIR" -type f -exec touch {} +

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

touch "${HOME}/.bashrc"

if ! grep -qxF \
  'export PATH="$HOME/.thru/sdk/toolchain/bin:$PATH"' \
  "${HOME}/.bashrc"; then

  printf '%s\n' \
    'export PATH="$HOME/.thru/sdk/toolchain/bin:$PATH"' \
    >> "${HOME}/.bashrc"
fi

log "C SDK kütüphanesi hazırlanıyor"

make \
  -C "$C_SDK_DIR" \
  BASEDIR="${C_SDK_DIR}/" \
  BUILDDIR="thru-sdk" \
  all lib include

[[ -x "${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc" ]] ||
  die "Toolchain derleyicisi bulunamadı."

[[ -f "${C_SDK_DIR}/thru-sdk/include/thru-sdk/c/tn_sdk.h" ]] ||
  die "tn_sdk.h bulunamadı."

[[ -f "${C_SDK_DIR}/thru-sdk/lib/libtn_sdk.a" ]] ||
  die "libtn_sdk.a bulunamadı."

[[ -f "${C_SDK_DIR}/thru-sdk/thru_c_program.mk" ]] ||
  die "thru_c_program.mk bulunamadı."

[[ -f "$CONFIG_FILE" ]] ||
  die "Thru yapılandırma dosyası bulunamadı: ${CONFIG_FILE}"

chmod 600 "$CONFIG_FILE"

rm -rf /tmp/thru-c-sdk-src
rm -f "$TOOLCHAIN_ARCHIVE" "$C_SDK_ARCHIVE"

ok "Toolchain ve C SDK hazır"
