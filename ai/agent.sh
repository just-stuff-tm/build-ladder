#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#####################################################################
# BUILD LADDER — AI AGENT (READ-ONLY SUGGESTION ENGINE)
#
# CONTRACT (ENFORCED)
# - OUTPUT: PURE bash only
# - MUST start with #!/usr/bin/env bash
# - MUST be idempotent
# - SAFE if re-run
# - NEVER execute commands
# - NEVER modify update.sh
#####################################################################

STATE="$HOME/.build-ladder"
PROJECT="$HOME/projects/current"

AI_DIR="$STATE/ai"
RUNTIME_DIR="$AI_DIR/runtime"
LOG_DIR="$AI_DIR/logs"
MODEL_FILE="$RUNTIME_DIR/model"
GRADLE_ERR="$STATE/last-gradle-error.txt"

mkdir -p "$LOG_DIR"

# ----------------------------------------------------------
# Preconditions (never hard-fail Forge)
# ----------------------------------------------------------
command -v ollama >/dev/null 2>&1 || {
  echo "# ERROR: Ollama not installed"
  exit 0
}

[[ -f "$MODEL_FILE" ]] || {
  echo "# ERROR: Missing model file: $MODEL_FILE"
  exit 0
}

[[ -L "$PROJECT" && -f "$PROJECT/.build-ladder.json" ]] || {
  echo "# ERROR: No active project"
  exit 0
}

MODEL="$(cat "$MODEL_FILE")"

# ----------------------------------------------------------
# Project context
# ----------------------------------------------------------
META="$PROJECT/.build-ladder.json"

APP_NAME="$(jq -r .app_name "$META")"
GOAL="$(jq -r .goal "$META")"
PACKAGE="$(jq -r .package "$META")"

PATCH_COUNT="$(ls "$PROJECT/scripts/patches"/patch-*.sh 2>/dev/null | wc -l | tr -d ' ')"
NEXT_STEP="$(printf "%02d" $((PATCH_COUNT + 1)))"

LAST_ERROR="$(cat "$GRADLE_ERR" 2>/dev/null || true)"

# ----------------------------------------------------------
# Prompt (bulletproof)
# ----------------------------------------------------------
PROMPT="$(cat <<EOF
You are Build Ladder AI.

STRICT RULES:
- OUTPUT MUST BE VALID BASH ONLY
- FIRST LINE MUST BE: #!/usr/bin/env bash
- COMMENTS MUST START WITH #
- NO MARKDOWN
- NO PROSE
- NO LISTS
- NO EXPLANATIONS
- NO COMMAND EXECUTION
- NO EXIT STATEMENTS
- FILE CHECKS ALLOWED ONLY FOR CREATE / MODIFY
- DO NOT TOUCH update.sh
- IDEMPOTENT ONLY

PROJECT:
App: $APP_NAME
Goal: $GOAL
Package: $PACKAGE
Step: patch-$NEXT_STEP

LAST ERROR:
$LAST_ERROR

OUTPUT = CONTENTS OF:
scripts/patches/patch-$NEXT_STEP.sh
EOF
)"

# ----------------------------------------------------------
# Run model
# ----------------------------------------------------------
RAW_OUTPUT="$(
  ollama run "$MODEL" 2>>"$LOG_DIR/agent.log" <<EOF
$PROMPT
EOF
)"

# ----------------------------------------------------------
# Sanitize HARD (bash-only)
# ----------------------------------------------------------
SANITIZED="$(
  printf '%s\n' "$RAW_OUTPUT" |
  sed '/^```/d' |
  sed -n '/^#!\/usr\/bin\/env bash/,$p' |
  awk '
    NR==1 { print; next }
    /^[[:space:]]*$/ { print; next }
    /^[[:space:]]*#/ { print; next }
    /^[[:space:]]*[a-zA-Z0-9_]+=/ { print; next }
    /^[[:space:]]*(if|then|fi|for|while|do|done|case|esac|\{|\}|\(|\))/ { print; next }
    { exit }
  '
)"

# ----------------------------------------------------------
# Validate
# ----------------------------------------------------------
if ! printf '%s\n' "$SANITIZED" | head -n1 | grep -q '^#!/usr/bin/env bash'; then
  cat <<EOF
#!/usr/bin/env bash
# ERROR: AI output invalid
# Reason: Missing or malformed shebang
# Raw output saved to: $LOG_DIR/agent.log
EOF
  printf '%s\n' "$RAW_OUTPUT" >>"$LOG_DIR/agent.log"
  exit 0
fi

# ----------------------------------------------------------
# Emit READ-ONLY patch
# ----------------------------------------------------------
printf '%s\n' "$SANITIZED"
