#!/usr/bin/env bash

MEMORY_FILE="$STATE/memory.json"

init_memory() {
  [[ -f "$MEMORY_FILE" ]] && return

  cat > "$MEMORY_FILE" <<EOF
{
  "skill_level": "beginner",
  "failures": {},
  "preferences": {
    "ai_hints": true
  }
}
EOF
}

record_failure() {
  local key="$1"
  init_memory

  jq --arg k "$key" '
    .failures[$k] = (.failures[$k] // 0) + 1
  ' "$MEMORY_FILE" > "$MEMORY_FILE.tmp" \
  && mv "$MEMORY_FILE.tmp" "$MEMORY_FILE"
}

get_skill_level() {
  init_memory
  jq -r '.skill_level' "$MEMORY_FILE"
}

