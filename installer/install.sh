#!/usr/bin/env bash
set -e

REPO="https://raw.githubusercontent.com/just-stuff-tm/build-ladder/main"

PREFIX="/data/data/com.termux/files/usr"
STATE="$HOME/.build-ladder"
BIN="$STATE/bin"

mkdir -p "$BIN"

echo "⬇ Installing Build Ladder..."

download() {
  echo "• Fetching $1"
  curl -fsSL "$REPO/$1" -o "$BIN/$(basename "$1")"
}

# Core runtime files (MUST all exist)
download core/build-ladder.sh
download core/core.sh
download core/update.sh
download core/version.txt
download core/donation.txt

# Bootstrap
download bootstrap/bootstrap.sh

chmod +x "$BIN"/*.sh

# Entrypoint
cat > "$PREFIX/bin/build-ladder" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.build-ladder/bin/build-ladder.sh" "$@"
EOF

chmod +x "$PREFIX/bin/build-ladder"

echo "✅ Build Ladder installed successfully"
echo "🙏 Voluntary donations welcome: \$yuptm"

