#!/usr/bin/env bash
set -euo pipefail

# ---- config ----
BUCKET="hl-testnet-evm-blocks"
REGION="ap-northeast-1"
DEST="${HOME}/evm-blocks-testnet"
WORKERS=512
S3SYNC="${HOME}/.local/bin/s3sync"   # install & run from here
# ----------------

now(){ date +"%F %T"; }
log(){ printf '[%s] %s\n' "$(now)" "$*"; }
die(){ log "ERROR: $*"; exit 1; }
trap 'log "Signal received, exiting."; exit 2' INT TERM

need(){ command -v "$1" >/dev/null 2>&1 || die "missing dependency: $1"; }

get_latest_version() {
  # follows redirect to .../releases/tag/vX.Y.Z ; extract the tag
  curl -fsSL -o /dev/null -w '%{url_effective}' \
    https://github.com/nidor1998/s3sync/releases/latest \
  | sed -n 's#.*/tag/\(v[0-9][^/]*\).*#\1#p'
}

install_s3sync_latest() {
  need curl
  local version os arch fname url tmpdir tmpbin
  version="$(get_latest_version)"; [[ -n "$version" ]] || die "could not resolve latest version"
  os="$(uname | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "unsupported arch: $arch" ;;
  esac
  fname="s3sync-${os}-${arch}.tar.gz"
  url="https://github.com/nidor1998/s3sync/releases/download/${version}/${fname}"

  log "Installing s3sync ${version} -> ${S3SYNC}"
  mkdir -p "${HOME}/.local/bin"
  tmpdir="$(mktemp -d)"; trap 'rm -rf "$tmpdir"' EXIT
  curl -fL --retry 5 --retry-delay 1 -o "${tmpdir}/${fname}" "$url"
  tar -xzf "${tmpdir}/${fname}" -C "${tmpdir}"
  tmpbin="${tmpdir}/s3sync"
  [[ -x "$tmpbin" ]] || die "extracted s3sync not executable"
  chmod +x "$tmpbin"
  mv -f "$tmpbin" "$S3SYNC"
  log "s3sync installed at ${S3SYNC}"
}

# --- deps & install/update ---
need aws
install_s3sync_latest   # <-- always refresh to latest
[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"

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
