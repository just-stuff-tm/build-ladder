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

# Gradle + Java safety defaults (Termux-safe)
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

# =================================================
# ANDROID / GRADLE HARDENING
# =================================================
ensure_gradle_properties(){
  local gp="$PROJECT/gradle.properties"
  touch "$gp"

  sed -i '/android.useAndroidX/d' "$gp"
  sed -i '/android.enableJetifier/d' "$gp"
  sed -i '/android.aapt2FromMavenOverride/d' "$gp"
  sed -i '/android.enableAapt2Daemon/d' "$gp"

  cat >> "$gp" <<EOF
android.useAndroidX=true
android.enableJetifier=true
android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2
android.enableAapt2Daemon=false
EOF
}

ensure_local_properties(){
  local sdk="$HOME/android-sdk"
  mkdir -p "$sdk"
  cat > "$PROJECT/local.properties" <<EOF
sdk.dir=$sdk
EOF
}

ensure_kotlin_sanity(){
  local root="$PROJECT/build.gradle"
  local app="$PROJECT/app/build.gradle"

  touch "$root"

  if ! grep -q 'kotlin_version' "$root"; then
    cat >> "$root" <<'EOF'

ext {
    kotlin_version = '1.8.22'
}
EOF
  fi

  if [[ -f "$app" ]]; then
    sed -i '/kotlin-stdlib/d' "$app"

    if ! grep -q 'kotlin-bom' "$app"; then
      sed -i '/dependencies\s*{/a\
    implementation platform("org.jetbrains.kotlin:kotlin-bom:${kotlin_version}")\
' "$app"
    fi

    if ! grep -q 'configurations.all' "$app"; then
      cat >> "$app" <<'EOF'

configurations.all {
    exclude group: "org.jetbrains.kotlin", module: "kotlin-stdlib-jdk7"
    exclude group: "org.jetbrains.kotlin", module: "kotlin-stdlib-jdk8"
}
EOF
    fi
  fi
}

# =================================================
# BEGINNER TIPS
# =================================================
show_tip(){
  local tips=(
    "Describe what's missing — you don’t need to know the solution."
    "Small fixes converge faster than big ones."
    "If it builds once, it can build again."
    "The AI suggests. YOU decide."
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
# PROJECT SELECTION
# =================================================
while true; do
  select_project
  [[ -L "$PROJECT_LINK" ]] && break
done

# =================================================
# LOAD PROJECT
# =================================================
PROJECT="$PROJECT_LINK"
PATCHES="$PROJECT/scripts/patches"
META="$PROJECT/.build-ladder.json"
FORGE_STATE="$PROJECT/.forge_state"

APP_NAME="$(jq -r .app_name "$META")"
GOAL="$(jq -r .goal "$META")"
PACKAGE="$(jq -r .package "$META")"

mkdir -p "$PATCHES"
cd "$PROJECT"

LAST_STEP=$(ls "$PATCHES"/patch-*.sh 2>/dev/null | tr -dc '0-9\n' | sort -n | tail -1 || echo 0)
STEP=$((10#$LAST_STEP + 1))

# =================================================
# FORGE LOOP
# =================================================
while true; do
  echo
  echo "────────────────────────────────────────"
  echo "🔨 Build Ladder Forge"
  echo "App: $APP_NAME"
  echo "Goal: $GOAL"
  echo "Package: $PACKAGE"
  echo "Step: $STEP"
  echo "────────────────────────────────────────"
  echo

  read -r -p "What is still wrong / missing? " FEEDBACK
  echo

  read -r -p "🤖 Ask AI to suggest a patch? [y/N] " USE_AI
  if [[ "$USE_AI" =~ ^[Yy]$ && -x "$STATE/ai/agent.sh" ]]; then
    echo
    "$STATE/ai/agent.sh" forge
    echo
  fi

  PATCH="$PATCHES/patch-$(printf "%02d" "$STEP").sh"
  echo
  echo "📋 Paste patch now (Ctrl+D when done)"
  cat > "$PATCH"
  chmod +x "$PATCH"

  if ! grep -q '^#!/usr/bin/env bash' "$PATCH"; then
    echo "⚠ Patch rejected (missing shebang)"
    continue
  fi

  echo
  echo "🧩 Applying patch..."
  mkdir -p app/src/main/java app/src/main/res/layout

  bash "$PATCH" || continue

  echo
  echo "⚙ Building APK..."
  ensure_gradle_properties
  ensure_local_properties
  ensure_kotlin_sanity

  if ./gradlew assembleDebug 2>&1 | tee gradle.log; then
    echo
    echo "✅ Build succeeded"
    echo "📦 app/build/outputs/apk/debug/app-debug.apk"
    ((STEP++))
  else
    extract_gradle_error > "$GRADLE_ERR"
    echo
    echo "❌ Build failed — copy error into AI if needed"
  fi
done
