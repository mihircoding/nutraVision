#!/bin/bash
# Stores the Anthropic and USDA keys as Supabase Edge Function secrets. Keys are typed at hidden prompts,
# so they never land in shell history, the chat or a file in the repo.
#
#   scripts/set-api-keys.sh <project-ref>
#
# Press Enter at a prompt to leave that key unchanged.
set -euo pipefail

REF="${1:?usage: scripts/set-api-keys.sh <project-ref>}"
SUPABASE="$(command -v supabase || echo "$HOME/.local/supabase-cli/supabase")"

read -r -s -p "Anthropic API key (sk-ant-..., Enter to skip): " ANTHROPIC; echo
read -r -s -p "USDA FoodData Central key (Enter to skip): " FDC; echo

ENV_FILE="$(mktemp)"
chmod 600 "$ENV_FILE"
trap 'rm -f "$ENV_FILE"' EXIT
if [ -n "$ANTHROPIC" ]; then
  case "$ANTHROPIC" in sk-ant-*) ;; *) echo "That doesn't look like an Anthropic key (sk-ant-...)." >&2; exit 1 ;; esac
  echo "ANTHROPIC_API_KEY=$ANTHROPIC" >> "$ENV_FILE"
fi
[ -n "$FDC" ] && echo "FDC_API_KEY=$FDC" >> "$ENV_FILE"
[ -s "$ENV_FILE" ] || { echo "Nothing to set."; exit 0; }

# --yes: running this script is the confirmation; the CLI otherwise asks again and defaults to No.
"$SUPABASE" secrets set --env-file "$ENV_FILE" --remote="$REF" --yes
echo "Saved. Secret names on the project:"
"$SUPABASE" secrets list --remote="$REF" -o json | grep -o '"name": *"[A-Z_]*"' | cut -d\" -f4
