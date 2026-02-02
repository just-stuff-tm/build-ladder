#!/usr/bin/env bash
set -e

PREFIX="/data/data/com.termux/files/usr"
STATE="$HOME/.build-ladder"
BIN="$PREFIX/bin/build-ladder"

mkdir -p "$STATE/bin"

echo "⬇ Installing Build Ladder..."

curl -fsSL https://raw.githubusercontent.com/just-stuff-tm/build-ladder/main/core/build-ladder.sh   -o "$STATE/bin/build-ladder.sh"

curl -fsSL https://raw.githubusercontent.com/just-stuff-tm/build-ladder/main/bootstrap/bootstrap.sh   -o "$STATE/bin/bootstrap.sh"

chmod +x "$STATE/bin/"*.sh

cat > "$BIN" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.build-ladder/bin/build-ladder.sh" "$@"
EOF

chmod +x "$BIN"

echo "✅ Installed. Run: build-ladder"
echo "🙏 Optional donations welcome: $yuptm"
