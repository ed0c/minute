#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(CDPATH="" cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NORMALIZE_SCRIPT="$ROOT_DIR/scripts/normalize-app-store-archive.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

app_path="$tmp_dir/Minute.app"
ffmpeg_path="$app_path/Contents/Resources/ffmpeg"
helper_entitlements="$tmp_dir/helper-entitlements.plist"
app_entitlements="$tmp_dir/app-entitlements.plist"
legacy_helper_entitlements="$tmp_dir/legacy-helper-entitlements.plist"
normalized_ffmpeg_entitlements="$tmp_dir/normalized-ffmpeg-entitlements.plist"

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

cat > "$app_path/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.minute.tests.normalize</string>
  <key>CFBundleName</key>
  <string>Minute</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleExecutable</key>
  <string>Minute</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
</dict>
</plist>
PLIST

cat > "$helper_entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.inherit</key>
  <true/>
</dict>
</plist>
PLIST

cat > "$app_entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
</dict>
</plist>
PLIST

cat > "$legacy_helper_entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.inherit</key>
  <true/>
</dict>
</plist>
PLIST

cp /usr/bin/true "$app_path/Contents/MacOS/Minute"
chmod +x "$app_path/Contents/MacOS/Minute"
cp /usr/bin/true "$ffmpeg_path"
chmod +x "$ffmpeg_path"

/usr/bin/codesign --force --entitlements "$app_entitlements" --sign - "$app_path/Contents/MacOS/Minute"
/usr/bin/codesign --force --entitlements "$legacy_helper_entitlements" --sign - "$ffmpeg_path"
/usr/bin/codesign --force --entitlements "$app_entitlements" --sign - "$app_path"

MINUTE_HELPER_ENTITLEMENTS_FILE="$helper_entitlements" "$NORMALIZE_SCRIPT" "$app_path"

/usr/bin/codesign -d --entitlements :- "$ffmpeg_path" > "$normalized_ffmpeg_entitlements" 2>/dev/null
sandbox_value="$(/usr/libexec/PlistBuddy -c "Print :com.apple.security.app-sandbox" "$normalized_ffmpeg_entitlements" 2>/dev/null || true)"

if [ "$sandbox_value" != "true" ] && [ "$sandbox_value" != "YES" ]; then
  echo "expected normalized ffmpeg entitlement com.apple.security.app-sandbox=true" >&2
  exit 1
fi

echo "normalize app-store archive helper entitlement override smoke check passed"
