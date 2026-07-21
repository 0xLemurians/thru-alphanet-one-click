#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

log "Sistem paketleri kuruluyor"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl wget git jq openssl tar unzip xz-utils \
  perl autoconf automake autopoint gettext flex bison build-essential \
  gcc-multilib protobuf-compiler llvm lcov libgmp-dev libudev-dev \
  cmake libclang-dev pkg-config meson ninja-build texinfo libexpat1-dev \
  libmpfr-dev gawk libmpc-dev python3 python3-pip python3-tomli bc \
  zlib1g-dev libglib2.0-dev libslirp-dev zstd bear

for cmd in curl git jq openssl make gcc g++ cmake meson ninja python3; do
  command -v "$cmd" >/dev/null || die "$cmd kurulamadı."
done
ok "Sistem bağımlılıkları hazır"
