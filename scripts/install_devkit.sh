#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
require_supported_host

log "RISC-V toolchain v${THRU_VERSION} indiriliyor"

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

log "Toolchain SHA-256 değeri doğrulanıyor"

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

compiler="${TOOLCHAIN_DIR}/bin/riscv64-unknown-elf-gcc"

[[ -x "$compiler" ]] ||
  die "Toolchain derleyicisi bulunamadı."

toolchain_version="$("$compiler" --version | sed -n '1p')"
printf '%s\n' "$toolchain_version"

ensure_config_value "toolchain_path" "$TOOLCHAIN_DIR"
ensure_config_value "toolchain_version" "$THRU_VERSION"

log "C SDK v${THRU_VERSION} indiriliyor"

rm -rf "$C_SDK_DIR"
rm -rf /tmp/thru-c-sdk-src
rm -f "$C_SDK_ARCHIVE"

mkdir -p "$C_SDK_DIR"
mkdir -p /tmp/thru-c-sdk-src

chmod 700 "$C_SDK_DIR"
chmod 700 /tmp/thru-c-sdk-src

curl \
  --fail \
  --location \
  --retry 5 \
  --retry-delay 5 \
  --show-error \
  "$C_SDK_URL" \
  --output "$C_SDK_ARCHIVE"

log "C SDK SHA-256 değeri doğrulanıyor"

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

find "$C_SDK_DIR" -type f -exec touch {} +

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

touch "${HOME}/.bashrc"

toolchain_path_line='export PATH="$HOME/.thru/sdk/toolchain/bin:$PATH"'

if ! grep -qxF "$toolchain_path_line" "${HOME}/.bashrc"; then
  printf '%s\n' "$toolchain_path_line" >> "${HOME}/.bashrc"
fi

log "C SDK kütüphanesi hazırlanıyor"

make \
  -C "$C_SDK_DIR" \
  BASEDIR="${C_SDK_DIR}/" \
  BUILDDIR="thru-sdk" \
  all lib include

sdk_header="${C_SDK_DIR}/thru-sdk/include/thru-sdk/c/tn_sdk.h"
sdk_library="${C_SDK_DIR}/thru-sdk/lib/libtn_sdk.a"
sdk_makefile="${C_SDK_DIR}/thru-sdk/thru_c_program.mk"

[[ -f "$sdk_header" ]] ||
  die "tn_sdk.h bulunamadı."

[[ -f "$sdk_library" ]] ||
  die "libtn_sdk.a bulunamadı."

[[ -f "$sdk_makefile" ]] ||
  die "thru_c_program.mk bulunamadı."

[[ -f "$CONFIG_FILE" ]] ||
  die "Thru yapılandırma dosyası bulunamadı: ${CONFIG_FILE}"

chmod 600 "$CONFIG_FILE"

rm -rf /tmp/thru-c-sdk-src
rm -f "$TOOLCHAIN_ARCHIVE" "$C_SDK_ARCHIVE"

ok "Toolchain ve C SDK hazır"
