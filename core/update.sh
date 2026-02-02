#!/usr/bin/env bash
set -euo pipefail

STATE="$HOME/.build-ladder"
BIN="$STATE/bin"
REPO="https://raw.githubusercontent.com/just-stuff-tm/build-ladder/main"

mkdir -p "$BIN"

install() {
  local file="$1"
  echo "• Updating $file"
  curl -fsSL "$REPO/$file" -o "$BIN/$(basename "$file")"
  chmod +x "$BIN/$(basename "$file")"
}

echo "⬇ Updating Build Ladder..."

install core/build-ladder.sh
install core/core.sh
install bootstrap/bootstrap.sh
install core/update.sh

# metadata (no chmod needed)
curl -fsSL "$REPO/core/version.txt" -o "$BIN/version.txt"
curl -fsSL "$REPO/core/donation.txt" -o "$BIN/donation.txt"

echo "✅ Update complete"
echo "🙏 Support Continued development: CashApp \$yuptm"
