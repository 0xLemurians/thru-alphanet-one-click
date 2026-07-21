#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

require_root
require_supported_host

log "Sistem paketleri kuruluyor"

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  wget \
  git \
  jq \
  openssl \
  tar \
  unzip \
  xz-utils \
  perl \
  autoconf \
  automake \
  autopoint \
  gettext \
  flex \
  bison \
  build-essential \
  gcc-multilib \
  protobuf-compiler \
  llvm \
  lcov \
  libgmp-dev \
  libudev-dev \
  cmake \
  libclang-dev \
  pkg-config \
  meson \
  ninja-build \
  texinfo \
  libexpat1-dev \
  libmpfr-dev \
  gawk \
  libmpc-dev \
  python3 \
  python3-pip \
  python3-tomli \
  bc \
  zlib1g-dev \
  libglib2.0-dev \
  libslirp-dev \
  zstd \
  bear

required_commands=(
  curl
  git
  jq
  openssl
  make
  gcc
  g++
  cmake
  meson
  ninja
  python3
)

for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null 2>&1 ||
    die "$command_name kurulamadı."
done

ok "Sistem bağımlılıkları hazır"
