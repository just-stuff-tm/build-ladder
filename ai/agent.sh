#!/usr/bin/env bash
set -euo pipefail

#####################################################################
# BUILD LADDER — AI AGENT
# Advisory only. Never applies changes.
#####################################################################

MODE="${1:-}"

STATE="$HOME/.build-ladder"
PROJECT_LINK="$HOME/projects/current"
AI_DIR="$STATE/ai"
MODEL="$(cat "$AI_DIR/runtime/model" 2>/dev/null || echo qwen2.5-coder:7b)"

[[ "$MODE" == "forge" ]] || {
  echo "❌ Invalid AI mode"
  exit 1
}

[[ -L "$PROJECT_LINK" ]] || {
  echo "❌ No active project selected."
  exit 1
}

META="$PROJECT_LINK/.build-ladder.json"
[[ -f "$META" ]] || {
  echo "❌ Missing project metadata."
  exit 1
}

APP_NAME="$(jq -r .app_name "$META")"
GOAL="$(jq -r .goal "$META")"
PACKAGE="$(jq -r .package "$META")"

cat <<EOF
#!/usr/bin/env bash
# AI SUGGESTED PATCH (DO NOT AUTO-RUN)

# App: $APP_NAME
# Goal: $GOAL
# Package: $PACKAGE

# RULES:
# - Idempotent
# - Safe to re-run
# - No destructive deletes
# - Create missing files only

# TODO: Implement initial Android project structure
EOF
