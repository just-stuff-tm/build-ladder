#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ────────────────────────────────────────────────
# CONFIG
# ────────────────────────────────────────────────
AI_MODE="${AI_MODE:-off}"   # off | auto
AI_ENDPOINT="${AI_ENDPOINT:-http://127.0.0.1:11434/api/generate}"
AI_MODEL="${AI_MODEL:-deepseek-coder:6.7b}"
AI_MAX_RETRIES=3

# ────────────────────────────────────────────────
# PATHS
# ────────────────────────────────────────────────
STATE="$HOME/.build-ladder"
PROJECT="$HOME/projects/current"
PATCHES="$PROJECT/scripts/patches"
META="$PROJECT/.build-ladder.json"
LAST_FEEDBACK="$PROJECT/.last_feedback.txt"
GRADLE_ERR="$STATE/last-gradle-error.txt"

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

ai_generate_patch() {
  local step="$1" feedback="$2" gradle_err="$3"

  jq -n \
    --arg m "$AI_MODEL" \
    --arg p "
Project metadata:
$(cat "$META")

Step: $step

User feedback:
$feedback

Gradle error:
$gradle_err

Return ONLY a bash script.
Must start with: #!/usr/bin/env bash
Path: scripts/patches/patch-$step.sh
No markdown. No explanations.
" \
  '{model:$m,prompt:$p,stream:false}' \
  | curl -s "$AI_ENDPOINT" -H "Content-Type: application/json" -d @- \
  | jq -r '.response'
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
PATCH="$PATCHES/patch-$(printf "%02d" "$STEP").sh"
FAILCOUNT="$STATE/fail-$STEP"

touch "$PATCH"
chmod +x "$PATCH"

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

  if [[ "$AI_MODE" == "off" ]]; then
    read -r -p "What is still wrong / missing? " FEEDBACK
  else
    FEEDBACK="$(cat "$LAST_FEEDBACK" 2>/dev/null || echo auto)"
    say "🤖 AI autonomous feedback mode"
  fi
  echo "$FEEDBACK" > "$LAST_FEEDBACK"

  SNAP="$PROJECT/.rollback-$STEP.tgz"
  tar czf "$SNAP" . >/dev/null 2>&1 || true

  # ── PATCH GENERATION
  if [[ "$AI_MODE" == "auto" ]]; then
    say "🤖 AI generating patch..."
    ERR="$(cat "$GRADLE_ERR" 2>/dev/null || echo none)"
    ai_generate_patch "$STEP" "$FEEDBACK" "$ERR" > "$PATCH"
  else
    say "📋 Paste patch, then Ctrl+D"
    cat > "$PATCH"
  fi

  grep -q '^#!/usr/bin/env bash' "$PATCH" || {
    say "⚠ Invalid patch (missing shebang)"
    continue
  }

  say "🧩 Applying patch..."
  if ! bash "$PATCH"; then
    say "⚠ Patch failed — rolling back"
    tar xzf "$SNAP" -C "$PROJECT" --strip-components=1
    echo $(( $(cat "$FAILCOUNT" 2>/dev/null || echo 0) + 1 )) > "$FAILCOUNT"
    (( $(cat "$FAILCOUNT") >= AI_MAX_RETRIES )) && die "Patch failed too many times"
    continue
  fi

  say "⚙ Building APK..."
  if ./gradlew assembleDebug 2>&1 | tee gradle.log; then
    say "✅ Build OK"
    APK="app/build/outputs/apk/debug/app-debug.apk"
    [[ -f "$APK" ]] && adb install -r "$APK" >/dev/null 2>&1 || true
    rm -f "$FAILCOUNT"
    STEP=$((STEP+1))
    PATCH="$PATCHES/patch-$(printf "%02d" "$STEP").sh"
    touch "$PATCH"
    chmod +x "$PATCH"
  else
    extract_gradle_error > "$GRADLE_ERR"
    say "❌ Build failed — error saved for next step"
  fi
done
