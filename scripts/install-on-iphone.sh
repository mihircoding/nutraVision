#!/bin/bash
# Builds NutraVision, signs it with your team and installs + launches it on a connected iPhone.
#
#   scripts/install-on-iphone.sh                 # the only connected iPhone
#   scripts/install-on-iphone.sh "My iPhone"      # pick one by name (or UDID / identifier)
#
# Needs: Xcode signed in to your Apple ID, ios/Config.local.xcconfig with your team
# (scripts/configure-ios.sh), and the iPhone unlocked, trusted and in Developer Mode.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS="$ROOT/ios"
DD="$HOME/Library/Developer/Xcode/DerivedData/NutraVision-device"
WANT="${1:-}"

XCODEGEN="$(command -v xcodegen || echo "$HOME/.local/xcodegen-dl/xcodegen/bin/xcodegen")"
[ -x "$XCODEGEN" ] || { echo "xcodegen not found. Install it: brew install xcodegen" >&2; exit 1; }
grep -q "^DEVELOPMENT_TEAM *= *[A-Z0-9]" "$IOS/Config.local.xcconfig" 2>/dev/null \
  || { echo "No signing team yet. Run: scripts/configure-ios.sh --team <TEAM_ID> --bundle-id com.you.nutravision" >&2; exit 1; }
grep -q "^SUPABASE_HOST *= *[a-z0-9]" "$IOS/Config.local.xcconfig" 2>/dev/null \
  || echo "Warning: no Supabase project configured; the app will install but can't sign in. See docs/BACKEND-SETUP.md."

# ---- find the iPhone
JSON="$(mktemp)"
xcrun devicectl list devices --json-output "$JSON" > /dev/null
read -r IDENT UDID NAME DEVMODE < <(python3 - "$JSON" "$WANT" <<'EOF'
import json, sys
devices = json.load(open(sys.argv[1]))["result"]["devices"]
want = sys.argv[2]
def label(d): return d["deviceProperties"].get("name", "?")
phones = [d for d in devices if d["hardwareProperties"].get("platform") == "iOS"]
norm = lambda s: (s or "").replace("’", "'").lower()
if want:  # name (curly or straight apostrophe, any case), identifier or UDID
    phones = [d for d in phones if norm(want) in (norm(label(d)), norm(d["identifier"]),
                                                  norm(d["hardwareProperties"].get("udid")))]
live = [d for d in phones if d["connectionProperties"].get("tunnelState") != "unavailable"]
if not live:
    names = ", ".join(f'{label(d)} ({d["connectionProperties"].get("tunnelState")})' for d in phones) or "none"
    sys.exit(f"No connected iPhone found. Known: {names}.\nPlug it in with a cable, unlock it and tap Trust.")
if len(live) > 1:
    sys.exit("Several iPhones are connected; pass one's name: " + ", ".join(label(d) for d in live))
d = live[0]
print(d["identifier"], d["hardwareProperties"]["udid"], label(d).replace(" ", "_"),
      d["deviceProperties"].get("developerModeStatus", "unknown"))
EOF
)
rm -f "$JSON"
echo "iPhone: ${NAME//_/ } ($UDID)"
if [ "$DEVMODE" = "disabled" ]; then
  echo "Developer Mode is off on this iPhone. Turn it on: Settings > Privacy & Security > Developer Mode," >&2
  echo "restart the phone, confirm, then run this script again." >&2
  exit 1
fi

# ---- build, sign, install, launch
cd "$IOS"
"$XCODEGEN" generate --quiet
echo "Building (the first build takes a few minutes)..."
xcodebuild build -project NutraVision.xcodeproj -scheme NutraVision -configuration Debug \
  -destination "id=$UDID" -derivedDataPath "$DD" -allowProvisioningUpdates -quiet
APP="$DD/Build/Products/Debug-iphoneos/NutraVision.app"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
echo "Installing $BUNDLE_ID..."
xcrun devicectl device install app --device "$IDENT" "$APP" > /dev/null
xcrun devicectl device process launch --device "$IDENT" "$BUNDLE_ID" > /dev/null \
  || echo "Installed. Unlock the phone and open NutraVision from the home screen."
echo "Done: NutraVision is on ${NAME//_/ }."
