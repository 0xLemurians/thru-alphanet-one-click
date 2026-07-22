#!/usr/bin/env bash
set -Eeuo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

readonly MAX_UPLOAD_ATTEMPTS=10
readonly MAX_STATUS_CHECKS=10
readonly NOT_UPLOADED_CONFIRMATIONS=3
readonly RETRY_DELAY=15

LAST_STATUS_STATE="unknown"

extract_json() {
  sed -n '/^[[:space:]]*[{[]/,$p'
}

print_output() {
  local output=$1
  local json

  json="$(printf '%s\n' "$output" | extract_json)"

  if [[ -n "$json" ]] &&
    printf '%s\n' "$json" | jq -e . >/dev/null 2>&1; then

    printf '%s\n' "$json" | jq .
  else
    printf '%s\n' "$output"
  fi
}

query_upload_status() {
  local seed=$1
  local status_output
  local status_json
  local corrupted

  LAST_STATUS_STATE="unknown"

  if ! status_output="$(thru --json uploader status "$seed" 2>&1)"; then
    LAST_STATUS_STATE="unavailable"
    warn "Uploader status query failed."
    print_output "$status_output" >&2
    return 1
  fi

  status_json="$(printf '%s\n' "$status_output" | extract_json)"

  if [[ -z "$status_json" ]]; then
    LAST_STATUS_STATE="invalid"
    warn "Uploader status output did not contain JSON."
    printf '%s\n' "$status_output" >&2
    return 1
  fi

  if ! printf '%s\n' "$status_json" |
    jq -e . >/dev/null 2>&1; then

    LAST_STATUS_STATE="invalid"
    warn "Uploader status output was not valid JSON."
    printf '%s\n' "$status_output" >&2
    return 1
  fi

  LAST_STATUS_STATE="$(
    printf '%s\n' "$status_json" |
      jq -r '.uploader_status.summary.status // "unknown"'
  )"

  corrupted="$(
    printf '%s\n' "$status_json" |
      jq -r '.uploader_status.summary.corrupted_accounts.any // false'
  )"

  if [[ "$corrupted" == "true" ]]; then
    printf '%s\n' "$status_json" | jq .
    die "Uploader account corruption detected."
  fi

  if printf '%s\n' "$status_json" |
    jq -e '
      .uploader_status.summary.status == "uploaded" and
      .uploader_status.summary.upload_exists == true and
      .uploader_status.summary.corrupted_accounts.any == false
    ' >/dev/null; then

    printf '%s\n' "$status_json" | jq .
    return 0
  fi

  return 1
}

wait_for_upload() {
  local seed=$1
  local check
  local not_uploaded_count=0

  for ((check = 1; check <= MAX_STATUS_CHECKS; check++)); do
    if query_upload_status "$seed"; then
      return 0
    fi

    case "$LAST_STATUS_STATE" in
      partial)
        not_uploaded_count=0
        warn "Upload is still in progress: ${check}/${MAX_STATUS_CHECKS}."
        ;;

      not_uploaded)
        ((not_uploaded_count += 1))
        warn "Program is not uploaded yet: ${check}/${MAX_STATUS_CHECKS}."

        if ((not_uploaded_count >= NOT_UPLOADED_CONFIRMATIONS)); then
          return 2
        fi
        ;;

      unavailable|invalid|unknown)
        not_uploaded_count=0
        warn "Upload status is currently unavailable: ${check}/${MAX_STATUS_CHECKS}."
        ;;

      *)
        not_uploaded_count=0
        warn "Unexpected upload status: ${LAST_STATUS_STATE}"
        ;;
    esac

    if ((check < MAX_STATUS_CHECKS)); then
      warn "Retrying status check in ${RETRY_DELAY} seconds..."
      sleep "$RETRY_DELAY"
    fi
  done

  if [[ "$LAST_STATUS_STATE" == "partial" ]]; then
    return 3
  fi

  return 1
}

require_root
require_supported_host
load_nvm

export PATH="${TOOLCHAIN_DIR}/bin:${PATH}"

command -v thru >/dev/null 2>&1 ||
  die "Thru CLI was not found."

command -v jq >/dev/null 2>&1 ||
  die "jq was not found."

command -v openssl >/dev/null 2>&1 ||
  die "OpenSSL was not found."

log "Preparing the example C project"

rm -rf "$PROJECT_DIR"
mkdir -p "$PROJECTS_DIR"
chmod 700 "$PROJECTS_DIR"

cd "$PROJECTS_DIR"

thru dev init c "$PROJECT_NAME" --path "$PROJECTS_DIR"

log "Building the example program"

cd "$PROJECT_DIR"

make clean >/dev/null 2>&1 || true
make -j"$(nproc)"

[[ -f "$BINARY_REL" ]] ||
  die "Binary was not created: ${PROJECT_DIR}/${BINARY_REL}"

ls -lh "$BINARY_REL"
sha256sum "$BINARY_REL"

log "Preparing a unique uploader seed"

seed="thru_demo_$(date +%s)_$(openssl rand -hex 3)"

mkdir -p "$THRU_HOME"
chmod 700 "$THRU_HOME"

install -m 600 /dev/null "${THRU_HOME}/last-upload-seed"
printf '%s\n' "$seed" > "${THRU_HOME}/last-upload-seed"

upload_verified=false

for ((attempt = 1; attempt <= MAX_UPLOAD_ATTEMPTS; attempt++)); do
  log "AlphaNet upload attempt ${attempt}/${MAX_UPLOAD_ATTEMPTS}"

  if upload_output="$(
    thru --json uploader upload "$seed" "$BINARY_REL" 2>&1
  )"; then

    print_output "$upload_output"

    upload_json="$(
      printf '%s\n' "$upload_output" |
        extract_json
    )"

    if [[ -n "$upload_json" ]] &&
      printf '%s\n' "$upload_json" |
        json_has_success; then

      ok "Upload command completed successfully"
    else
      warn "Upload command returned without a JSON success field."
      warn "The uploader status will be checked."
    fi
  else
    warn "Upload command failed."
    warn "The same seed will be checked before any retry."
    print_output "$upload_output" >&2
  fi

  log "Verifying program upload status"

  if wait_for_upload "$seed"; then
    upload_verified=true
    break
  else
    wait_result=$?
  fi

  case "$wait_result" in
    2)
      if ((attempt < MAX_UPLOAD_ATTEMPTS)); then
        warn "The program was confirmed as not uploaded."
        warn "Retrying the same seed in ${RETRY_DELAY} seconds..."
        sleep "$RETRY_DELAY"
      fi
      ;;

    3)
      die "Upload remained partial. The same seed will not be submitted again: ${seed}"
      ;;

    *)
      die "Upload status could not be confirmed safely. The same seed will not be submitted again: ${seed}"
      ;;
  esac
done

$upload_verified ||
  die "Program upload could not be verified after ${MAX_UPLOAD_ATTEMPTS} attempts. Seed: ${seed}"

ok "Program uploaded successfully"
printf 'Seed: %s\n' "$seed"
printf 'Seed file: %s\n' "${THRU_HOME}/last-upload-seed"
