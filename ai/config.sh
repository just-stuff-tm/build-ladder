#!/usr/bin/env bash

# Master switch
AI_ENABLED=true          # true | false

# Behavior mode
AI_MODE=suggest          # off | suggest | auto (auto later, not now)

# Provider (local-first)
AI_PROVIDER=ollama       # ollama | none

# Model config
AI_MODEL=deepseek-coder:6.7b
AI_ENDPOINT=http://127.0.0.1:11434/api/generate

# Safety
AI_TIMEOUT=15
AI_MAX_CHARS=12000
