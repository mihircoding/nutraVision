#!/bin/bash
# Writes ios/Config.local.xcconfig (gitignored): your signing team, bundle id and Supabase project.
# Only the options you pass change; the rest of the file is kept.
#
#   scripts/configure-ios.sh --team ABCDE12345 --bundle-id com.yourname.nutravision
#   scripts/configure-ios.sh --supabase-url https://abcdefghijkl.supabase.co --anon-key eyJhbGciOi...
#
# --team:          Apple Developer Team ID (Xcode > Settings > Accounts, or developer.apple.com > Membership)
# --bundle-id:     must be unique to your team; com.nutravision.app is likely taken
# --supabase-url:  Supabase > Project Settings > API > Project URL
# --anon-key:      the "anon public" (legacy) or "publishable" key. Never the service_role / secret key.
set -euo pipefail

FILE="$(cd "$(dirname "$0")/.." && pwd)/ios/Config.local.xcconfig"
touch "$FILE"

set_value() {  # set_value NAME VALUE
  local tmp
  tmp="$(mktemp)"
  grep -v "^$1 *=" "$FILE" > "$tmp" || true
  printf '%s = %s\n' "$1" "$2" >> "$tmp"
  mv "$tmp" "$FILE"
}

[ $# -gt 0 ] || { sed -n '2,13p' "$0"; exit 1; }
while [ $# -gt 0 ]; do
  case "$1" in
    --team) set_value DEVELOPMENT_TEAM "$2"; shift 2 ;;
    --bundle-id) set_value NV_BUNDLE_ID "$2"; shift 2 ;;
    --supabase-url)
      host="${2#https://}"; host="${host#http://}"; host="${host%%/*}"
      set_value SUPABASE_HOST "$host"; shift 2 ;;
    --anon-key)
      case "$2" in
        sb_secret_*) echo "That is a secret key. Use the anon or publishable key." >&2; exit 1 ;;
      esac
      set_value SUPABASE_ANON_KEY "$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

echo "Wrote $FILE:"
sed -E 's/^(SUPABASE_ANON_KEY = .{12}).*/\1.../' "$FILE"
