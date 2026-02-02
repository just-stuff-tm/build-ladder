#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ────────────────────────────────────────────────
# CONFIG
# ────────────────────────────────────────────────
AI_MODE="${AI_MODE:-off}"
AI_ENDPOINT="${AI_ENDPOINT:-http://127.0.0.1:11434/api/generate}"
AI_MODEL="${AI_MODEL:-deepseek-coder:6.7b}"
AI_MAX_RETRIES=3

# ────────────────────────────────────────────────
# TERMUX DETECTION
# ────────────────────────────────────────────────
IS_TERMUX=false
if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d /data/data/com.termux ]]; then
  IS_TERMUX=true
fi

# ────────────────────────────────────────────────
# PATHS
# ────────────────────────────────────────────────
STATE="$HOME/.build-ladder"
PROJECT="$HOME/projects/current"
PATCHES="$PROJECT/scripts/patches"
META="$PROJECT/.build-ladder.json"
LAST_FEEDBACK="$PROJECT/.last_feedback.txt"
GRADLE_ERR="$STATE/last-gradle-error.txt"
FORGE_STATE_FILE="$PROJECT/.forge_state"

mkdir -p "$PROJECT" "$PATCHES"

export GRADLE_OPTS="-Xmx2g -Dorg.gradle.daemon=false"
export _JAVA_OPTIONS="-XX:+UseParallelGC"

# ────────────────────────────────────────────────
# HELPERS
# ────────────────────────────────────────────────
say(){ printf "%s\n" "$1"; }
die(){ say "❌ $1"; exit 1; }

extract_gradle_error() {
  sed -n '/FAILURE:/,$p' gradle.log 2>/dev/null | head -n 200
}

# ────────────────────────────────────────────────
# GRADLE SAFETY DEFAULTS
# ────────────────────────────────────────────────
ensure_gradle_properties() {
  local gp="$PROJECT/gradle.properties"
  touch "$gp"

  sed -i '/android.useAndroidX/d' "$gp"
  sed -i '/android.enableJetifier/d' "$gp"
  sed -i '/android.aapt2FromMavenOverride/d' "$gp"

  cat >> "$gp" <<'EOF'
android.useAndroidX=true
android.enableJetifier=true
android.aapt2FromMavenOverride=/data/data/com.termux/files/usr/bin/aapt2
EOF
}

# ────────────────────────────────────────────────
# INITIAL PROJECT BOOTSTRAP
# ────────────────────────────────────────────────
if [[ ! -s "$META" ]]; then
  say "📦 Initial project setup"

  read -r -p "App name: " APP_NAME
  read -r -p "One-line goal: " GOAL

  while true; do
    read -r -p "Package (com.example.app): " RAW
    PACKAGE="$(echo "$RAW" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9.]/_/g')"
    [[ "$PACKAGE" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]] && break
    say "Invalid package name."
  done

  printf '{"app_name":"%s","goal":"%s","package":"%s"}' \
    "$APP_NAME" "$GOAL" "$PACKAGE" > "$META"
fi

APP_NAME="$(jq -r .app_name "$META")"
GOAL="$(jq -r .goal "$META")"
PACKAGE="$(jq -r .package "$META")"

# ────────────────────────────────────────────────
# STEP DETECTION
# ────────────────────────────────────────────────
LAST_STEP=$(ls "$PATCHES"/patch-*.sh 2>/dev/null | grep -o '[0-9]\+' | sort -n | tail -1 || echo 0)
STEP=$((10#$LAST_STEP + 1))

cd "$PROJECT"

# ────────────────────────────────────────────────
# MAIN FORGE LOOP
# ────────────────────────────────────────────────
while true; do
  say "────────────────────────────────────────"
  say "🔨 Build Ladder Forge"
  say "App: $APP_NAME"
  say "Goal: $GOAL"
  say "Package: $PACKAGE"
  say "Step: $STEP"
  say "AI mode: $AI_MODE"
  say "────────────────────────────────────────"

  read -r -p "What is still wrong / missing? " FEEDBACK
  echo "$FEEDBACK" > "$LAST_FEEDBACK"

  PATCH="$PATCHES/patch-$(printf "%02d" "$STEP").sh"
  touch "$PATCH"
  chmod +x "$PATCH"

  say "📋 Paste patch, then Ctrl+D"
  cat > "$PATCH"

  grep -q '^#!/usr/bin/env bash' "$PATCH" || {
    say "⚠ Invalid patch (missing shebang)"
    continue
  }

  say "🧩 Applying patch..."
  mkdir -p "$PROJECT/app/src/main/java" "$PROJECT/app/src/main/res/layout"

  if ! bash "$PATCH"; then
    say "⚠ Patch failed"
    continue
  fi

  say "⚙ Building APK..."
  ensure_gradle_properties

  if ./gradlew assembleDebug 2>&1 | tee gradle.log; then
    APK="$PROJECT/app/build/outputs/apk/debug/app-debug.apk"
    say "✅ Build OK"
    say "📦 APK located at:"
    say "  $APK"
    echo "BUILT" > "$FORGE_STATE_FILE"
    ((STEP++))
  else
    extract_gradle_error > "$GRADLE_ERR"
    say "❌ Build failed — error saved"
  fi
done
