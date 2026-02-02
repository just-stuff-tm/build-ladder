#!/usr/bin/env bash
set -euo pipefail

STATE="$HOME/.build-ladder"
BIN="$STATE/bin"

mkdir -p "$BIN"

DONATE="$BIN/donation.txt"
VERSION_FILE="$BIN/version.txt"

if [[ ! -f "$STATE/.donation_seen" ]] && [[ -f "$DONATE" ]]; then
  cat "$DONATE"
  touch "$STATE/.donation_seen"
fi

case "${1:-}" in
  update)
    exec "$BIN/update.sh"
    ;;
  version)
    cat "$VERSION_FILE"
    echo "Support development: $yuptm"
    exit 0
    ;;
esac

if [[ ! -f "$STATE/BOOTSTRAP_DONE" ]]; then
  bash "$BIN/bootstrap.sh"
fi

exec "$BIN/core.sh" "$@"
