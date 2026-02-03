#!/usr/bin/env bash

ai_available() {
  [[ "$AI_ENABLED" == true ]] || return 1
  command -v curl >/dev/null || return 1
  [[ "$AI_PROVIDER" == "ollama" ]] || return 1
}

ai_query() {
  local prompt="$1"

  ai_available || return 1

  curl -s --max-time "$AI_TIMEOUT" "$AI_ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{
      \"model\": \"$AI_MODEL\",
      \"prompt\": \"$prompt\",
      \"stream\": false
    }" \
  | jq -r '.response' 2>/dev/null \
  | head -c "$AI_MAX_CHARS"
}

