#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#####################################################################
# BUILD LADDER — CORE RUNTIME
# Deterministic engine. AI is advisory only.
#####################################################################

# =================================================
# GLOBAL PATHS & STATE
# =================================================
STATE="$HOME/.build-ladder"
PROJECT_ROOT="$HOME/projects"
PROJECT_LINK="$PROJECT_ROOT/current"
AI_DIR="$STATE/ai"
AI_HELPER_DIR="$STATE/ai-helper"
TIPS_FILE="$STATE/tips_seen"
GRADLE_ERR="$STATE/last-gradle-error.txt"

mkdir -p "$STATE" "$PROJECT_ROOT" "$AI_HELPER_DIR"

# Ensure "current" is ALWAYS a symlink
if [[ -d "$PROJECT_LINK" && ! -L "$PROJECT_LINK" ]]; then
  echo "⚠ Fixing invalid current project directory"
  rm -rf "$PROJECT_LINK"
fi

export GRADLE_OPTS="-Xmx2g -Dorg.gradle.daemon=false"
export _JAVA_OPTIONS="-XX:+UseParallelGC"

# =================================================
# UTILITIES
# =================================================
say(){ echo "$1"; }
die(){ echo "❌ $1"; exit 1; }

slugify(){
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g'
}

extract_gradle_error(){
  sed -n '/FAILURE:/,$p' gradle.log 2>/dev/null | head -n 200
}

ensure_gradle_properties(){
  local gp="$PROJECT/gradle.properties"
  touch "$gp"

  sed -i '/android.useAndroidX/d' "$gp"
  sed -i '/android.enableJetifier/d' "$gp"
  sed -i '/android.aapt2FromMavenOverride/d' "$gp"

  cat >> "$gp" <<EOF
android.useAndroidX=true
android.enableJetifier=true
android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2
EOF
}

# =================================================
# BEGINNER TIPS (SHOWN GRADUALLY)
# =================================================
show_tip(){
  local tips=(
    "You don’t need to write code — describe what’s missing."
    "If a build fails, you can ask the AI for a patch suggestion."
    "Small steps work better than giant ones."
    "Ctrl+C is always safe."
    "Every step is reversible."
  )

  touch "$TIPS_FILE"
  for tip in "${tips[@]}"; do
    if ! grep -Fxq "$tip" "$TIPS_FILE"; then
      echo
      echo "💡 Tip:"
      echo "  $tip"
      echo "$tip" >> "$TIPS_FILE"
      echo
      break
    fi
  done
}

# =================================================
# PROJECT MANAGER
# =================================================
create_project(){
  echo
  read -r -p "App name: " APP_NAME
  read -r -p "One-line goal: " GOAL

  while true; do
    read -r -p "Package (com.example.app): " RAW
    PACKAGE="$(echo "$RAW" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.]/_/g')"
    [[ "$PACKAGE" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] && break
    echo "Invalid package name."
  done

  DIR="$(slugify "$APP_NAME")"
  TARGET="$PROJECT_ROOT/$DIR"
  [[ -d "$TARGET" ]] && die "Project already exists."

  mkdir -p "$TARGET/scripts/patches"
  cat > "$TARGET/.build-ladder.json" <<EOF
{"app_name":"$APP_NAME","goal":"$GOAL","package":"$PACKAGE"}
EOF

  echo INIT > "$TARGET/.forge_state"
  ln -sfn "$TARGET" "$PROJECT_LINK"
}

delete_project(){
  echo
  ls -1 "$PROJECT_ROOT" | grep -v current || return
  echo
  read -r -p "Project folder to delete: " NAME
  echo "Type DELETE to confirm:"
  read -r CONFIRM
  [[ "$CONFIRM" == "DELETE" ]] && rm -rf "$PROJECT_ROOT/$NAME"
}

select_project(){
  local projects=()
  local i=1

  echo
  echo "🗂 Build Ladder Projects"
  echo

  for d in "$PROJECT_ROOT"/*; do
    [[ -d "$d" && "$(basename "$d")" != "current" ]] || continue
    projects+=("$(basename "$d")")
    META="$d/.build-ladder.json"
    NAME="$(jq -r .app_name "$META")"
    STEP="$(ls "$d/scripts/patches"/patch-*.sh 2>/dev/null | wc -l)"
    echo "[$i] Continue: $NAME (Step $STEP)"
    ((i++))
  done

  echo
  echo "[n] New  [d] Delete  [h] Tips  [0] Exit"
  echo
  read -r -p "Select: " choice

  case "$choice" in
    0) exit 0 ;;
    n) create_project ;;
    d) delete_project ;;
    h) show_tip ;;
    *) ln -sfn "$PROJECT_ROOT/${projects[$((choice-1))]}" "$PROJECT_LINK" ;;
  esac
}

# =================================================
# PROJECT SELECTION (ONCE)
# =================================================
if [[ ! -L "$PROJECT_LINK" ]]; then
  select_project
fi

show_tip

# =================================================
# LOAD PROJECT
# =================================================
PROJECT="$PROJECT_LINK"
PATCHES="$PROJECT/scripts/patches"
META="$PROJECT/.build-ladder.json"
LAST_FEEDBACK="$PROJECT/.last_feedback.txt"
FORGE_STATE="$PROJECT/.forge_state"

[[ -f "$META" ]] || die "Missing project metadata."

APP_NAME="$(jq -r .app_name "$META")"
GOAL="$(jq -r .goal "$META")"
PACKAGE="$(jq -r .package "$META")"

mkdir -p "$PATCHES"
cd "$PROJECT"

LAST_STEP=$(ls "$PATCHES"/patch-*.sh 2>/dev/null | tr -dc '0-9\n' | sort -n | tail -1 || echo 0)
STEP=$((10#$LAST_STEP + 1))

# =================================================
# AI HELPER (COPY-PASTE FRIENDLY)
# =================================================
write_ai_helper(){
  cat > "$AI_HELPER_DIR/step-$(printf "%02d" "$STEP")-debug.txt" <<EOF
BUILD LADDER DEBUG CONTEXT

App: $APP_NAME
Goal: $GOAL
Package: $PACKAGE
Step: $STEP

ERROR:
$(cat "$GRADLE_ERR" 2>/dev/null)

Return ONLY a bash patch script.
Must start with: #!/usr/bin/env bash
EOF
}

# =================================================
# FORGE LOOP
# =================================================
while true; do
  echo "────────────────────────────────────────"
  echo "🔨 Build Ladder Forge"
  echo "App: $APP_NAME"
  echo "Goal: $GOAL"
  echo "Package: $PACKAGE"
  echo "Step: $STEP"
  echo "────────────────────────────────────────"

  read -r -p "What is still wrong / missing? " FEEDBACK
  echo "$FEEDBACK" > "$LAST_FEEDBACK"
  echo

  read -r -p "Ask AI for a patch suggestion? [y/N] " USE_AI
  if [[ "$USE_AI" =~ ^[Yy]$ ]] && [[ -x "$AI_DIR/agent.sh" ]]; then
    echo
    echo "🧠 AI SUGGESTION (COPY ONLY):"
    echo "────────────────────────────────────────"
    "$AI_DIR/agent.sh" forge
    echo "────────────────────────────────────────"
    echo
  fi

  PATCH="$PATCHES/patch-$(printf "%02d" "$STEP").sh"
  echo "📋 Paste patch, Ctrl+D when done"
  cat > "$PATCH"
  chmod +x "$PATCH"

  grep -q '^#!/usr/bin/env bash' "$PATCH" || {
    echo "⚠ Patch missing shebang"
    continue
  }

  mkdir -p app/src/main/java app/src/main/res/layout

  if bash "$PATCH" && ./gradlew assembleDebug 2>&1 | tee gradle.log; then
    echo "✅ Build OK"
    echo BUILT > "$FORGE_STATE"
    ((STEP++))
  else
    extract_gradle_error > "$GRADLE_ERR"
    write_ai_helper
    echo
    echo "❌ Build failed. COPY BELOW INTO ANY AI:"
    echo "────────────────────────────────────────"
    cat "$AI_HELPER_DIR/step-$(printf "%02d" "$STEP")-debug.txt"
    echo "────────────────────────────────────────"
  fi
done
