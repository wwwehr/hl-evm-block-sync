#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
BUCKET="hl-testnet-evm-blocks"
REGION="ap-northeast-1"
DEST="${HOME}/evm-blocks-testnet"
WORKERS=512
S3SYNC="${HOME}/.local/bin/s3sync"   # preferred path
VERSION="v1.36.0"
# ----------------

now() { date +"%F %T"; }
log() { printf '[%s] %s\n' "$(now)" "$*"; }
die() { log "ERROR: $*"; exit 1; }
trap 'log "Signal received, exiting."; exit 2' INT TERM

install_s3sync() {
  log "Installing s3sync $VERSION into ~/.local/bin..."
  BASE_URL="https://github.com/nidor1998/s3sync/releases/download/$VERSION"
  OS="$(uname | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) die "Unsupported architecture: $ARCH" ;;
  esac

  FILENAME="s3sync-${OS}-${ARCH}.tar.gz"
  URL="$BASE_URL/$FILENAME"

  mkdir -p ~/.local/bin

  curl -L --fail -o "$FILENAME" "$URL"
  tar -xzf "$FILENAME"

  chmod +x s3sync
  mv s3sync "$S3SYNC"
  rm "$FILENAME"

  log "Installed s3sync $VERSION successfully at $S3SYNC"
}

# --- check deps ---
command -v aws >/dev/null 2>&1 || die "aws CLI not found"
if [[ ! -x "$S3SYNC" ]]; then
  if command -v s3sync >/dev/null 2>&1; then
    S3SYNC="$(command -v s3sync)"
  else
    install_s3sync
  fi
fi

mkdir -p "$DEST"

# list prefixes
log "Listing top-level prefixes in s3://${BUCKET}/"
mapfile -t PREFIXES < <(
  aws s3 ls "s3://${BUCKET}/" --region "$REGION" --request-payer requester \
  | awk '/^ *PRE /{print $2}' | sed 's:/$::' | grep -E '^[0-9]+$' || true
)
((${#PREFIXES[@]})) || die "No prefixes found."

total_start=$(date +%s)

for p in "${PREFIXES[@]}"; do
  src="s3://${BUCKET}/${p}/"
  dst="${DEST}/${p}/"
  mkdir -p "$dst"

  log "START  ${p}"
  start=$(date +%s)

  "$S3SYNC" \
    --source-request-payer \
    --source-region "$REGION" \
    --worker-size "$WORKERS" \
    --max-parallel-uploads "$WORKERS" \
    "$src" "$dst"

  end=$(date +%s)
  mins=$(( (end - start + 59) / 60 ))
  printf '[%s] %s took %d minutes!\n' "$(now)" "$p" "$mins"
done

total_end=$(date +%s)
total_mins=$(( (total_end - total_start + 59) / 60 ))
printf '[%s] ALL DONE in %d minutes.\n' "$(now)" "$total_mins"

