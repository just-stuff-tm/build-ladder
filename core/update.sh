#!/usr/bin/env bash
set -e

REPO="https://raw.githubusercontent.com/YOURNAME/build-ladder/main"
STATE="$HOME/.build-ladder"
BIN="$STATE/bin"
BACKUP="$STATE/backup-$(date +%s)"

mkdir -p "$BACKUP"
cp -r "$BIN" "$BACKUP"

download() {
  curl -fsSL "$REPO/$1" -o "$BIN/$(basename "$1")"
}

if download core/build-ladder.sh &&
   download core/core.sh &&
   download core/update.sh &&
   download bootstrap/bootstrap.sh &&
   download core/version.txt &&
   download core/donation.txt; then
  chmod +x "$BIN"/*.sh
  echo "✅ Update complete"
  echo "🙏 Support continued development: \$yuptm"
else
  echo "⚠️ Update failed — restoring backup"
  rm -rf "$BIN"
  mv "$BACKUP/bin" "$BIN"
  exit 1
fi
