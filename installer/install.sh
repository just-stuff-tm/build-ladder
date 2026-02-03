#!/usr/bin/env bash
set -euo pipefail

REPO="https://raw.githubusercontent.com/just-stuff-tm/build-ladder/main"

PREFIX="/data/data/com.termux/files/usr"
STATE="$HOME/.build-ladder"
BIN="$STATE/bin"
AI="$STATE/ai"

mkdir -p "$BIN" "$AI/prompts" "$AI/runtime" "$AI/logs"

echo "⬇ Installing Build Ladder..."

download() {
  echo "• Fetching $1"
  curl -fsSL "$REPO/$1" -o "$2"
}

# =================================================
# CORE RUNTIME
# =================================================
download core/build-ladder.sh "$BIN/build-ladder.sh"
download core/core.sh         "$BIN/core.sh"
download core/update.sh       "$BIN/update.sh"
download core/version.txt     "$BIN/version.txt"
download core/donation.txt    "$BIN/donation.txt"

# =================================================
# BOOTSTRAP
# =================================================
download bootstrap/bootstrap.sh "$BIN/bootstrap.sh"

# =================================================
# AI SUBSYSTEM (FILES)
# =================================================
download ai/agent.sh    "$AI/agent.sh"
download ai/config.sh   "$AI/config.sh"
download ai/client.sh   "$AI/client.sh"
download ai/memory.sh   "$AI/memory.sh"
download ai/ux.sh       "$AI/ux.sh"

download ai/prompts/build_fail.txt    "$AI/prompts/build_fail.txt"
download ai/prompts/suggest_patch.txt "$AI/prompts/suggest_patch.txt"
download ai/prompts/explain_error.txt "$AI/prompts/explain_error.txt"
download ai/prompts/improve_ux.txt    "$AI/prompts/improve_ux.txt"

chmod +x "$BIN"/*.sh
chmod +x "$AI"/*.sh

# =================================================
# AI RUNTIME (TERMUX-SAFE OLLAMA INSTALL)
# =================================================
echo "🧠 Installing local AI runtime (Termux-compatible)..."

if ! command -v ollama >/dev/null 2>&1; then
  echo "• Installing Ollama via ollama-in-termux"
  curl -sL https://github.com/Anon4You/ollama-in-termux/raw/main/ollama.sh | bash
else
  echo "• Ollama already installed"
fi

MODEL="qwen2.5-coder:7b"

if ! ollama list | grep -q "^$MODEL"; then
  echo "• Pulling AI model: $MODEL"
  ollama pull "$MODEL"
else
  echo "• AI model already present"
fi

echo "$MODEL" > "$AI/runtime/model"

# =================================================
# ENTRYPOINT
# =================================================
cat > "$PREFIX/bin/build-ladder" <<'EOF'
#!/usr/bin/env bash
exec "$HOME/.build-ladder/bin/build-ladder.sh" "$@"
EOF

chmod +x "$PREFIX/bin/build-ladder"

# =================================================
# FINAL
# =================================================
echo "✅ Build Ladder installed successfully"
echo "🧠 Local AI: ENABLED (Termux)"
echo "🤖 Model: $MODEL"
echo "🙏 Voluntary donations welcome: CashApp \$yuptm"
