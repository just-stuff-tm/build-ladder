#!/usr/bin/env bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/just-stuff-tm/build-ladder/main"

PREFIX="/data/data/com.termux/files/usr"
STATE="$HOME/.build-ladder"
BIN="$STATE/bin"
AI="$STATE/ai"

mkdir -p "$BIN" "$AI/prompts" "$AI/runtime" "$AI/logs"

echo "⬇ Installing Build Ladder..."

download(){
  echo "• Fetching $1"
  curl -fsSL "$REPO/$1" -o "$2"
}

# =================================================
# CORE
# =================================================
download core/build-ladder.sh "$BIN/build-ladder.sh"
download core/core.sh "$BIN/core.sh"
download core/update.sh "$BIN/update.sh"
download core/version.txt "$BIN/version.txt"
download core/donation.txt "$BIN/donation.txt"

# =================================================
# BOOTSTRAP
# =================================================
download bootstrap/bootstrap.sh "$BIN/bootstrap.sh"

# =================================================
# AI (STATIC)
# =================================================
download ai/agent.sh "$AI/agent.sh"

chmod +x "$BIN"/*.sh
chmod +x "$AI"/*.sh

# =================================================
# DEV-ONLY AI RUNTIME
# =================================================
if [[ "${BUILD_LADDER_DEV_AI:-0}" == "1" ]]; then
  echo "🧠 Installing local AI runtime (DEV MODE)"

  if ! command -v ollama >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | bash
  fi

  MODEL="qwen2.5-coder:7b"
  ollama pull "$MODEL" || true
  echo "$MODEL" > "$AI/runtime/model"
else
  echo "ℹ️ AI runtime install skipped (set BUILD_LADDER_DEV_AI=1)"
fi

# =================================================
# ENTRYPOINT
# =================================================
cat > "$PREFIX/bin/build-ladder" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.build-ladder/bin/build-ladder.sh" "$@"
EOF

chmod +x "$PREFIX/bin/build-ladder"

echo "✅ Build Ladder installed"
echo "🧠 AI: advisory only"
echo "🙏 Voluntary donations welcome: CashApp \$yuptm"
