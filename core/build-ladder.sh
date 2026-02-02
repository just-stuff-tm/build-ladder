#!/usr/bin/env bash
set -euo pipefail

STATE="$HOME/.build-ladder"
BIN="$STATE/bin"

mkdir -p "$BIN"

DONATE="$BIN/donation.txt"
VERSION_FILE="$BIN/version.txt"

# ── Donation message (once)
if [[ ! -f "$STATE/.donation_seen" ]] && [[ -f "$DONATE" ]]; then
  cat "$DONATE"
  touch "$STATE/.donation_seen"
fi

# ── Commands handled here
case "${1:-}" in
  doctor)
    echo "🔍 Build Ladder Doctor"
    command -v java >/dev/null && echo "✓ Java" || echo "✗ Java"
    command -v gradle >/dev/null && echo "✓ Gradle" || echo "✗ Gradle"
    command -v aapt2 >/dev/null && echo "✓ aapt2" || echo "✗ aapt2"
    [[ -d "$HOME/android-sdk" ]] && echo "✓ Android SDK" || echo "✗ Android SDK"
    exit 0
    ;;
  update)
    exec "$BIN/update.sh"
    ;;
  version)
    cat "$VERSION_FILE"
    echo "Support development: \$yuptm"
    exit 0
    ;;
esac

# ── Bootstrap if needed
if [[ ! -f "$STATE/BOOTSTRAP_DONE" ]]; then
  bash "$BIN/bootstrap.sh"
fi

# ── Hand off to core forge
exec "$BIN/core.sh" "$@"
