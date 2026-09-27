#!/bin/bash
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "A Mac with full Xcode is required. Or run the included GitHub Actions workflow."
  exit 1
fi

# These tests use fixtures. No live account or credential is needed.
python3 scripts/check-source.py
swift test

xcodebuild \
  -project TagLookup.xcodeproj \
  -scheme TagLookup \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY='' \
  build

app_path="$project_dir/build/DerivedData/Build/Products/Release-iphoneos/TagLookup.app"
if [ ! -f "$app_path/TagLookup" ]; then
  echo "Build did not produce the device executable."
  exit 1
fi
xcrun lipo -verify_arch arm64 "$app_path/TagLookup"

mkdir -p "$project_dir/build/Payload"
rm -rf "$project_dir/build/Payload/TagLookup.app"
ditto "$app_path" "$project_dir/build/Payload/TagLookup.app"
rm -f "$project_dir/build/TagLookup-unsigned.ipa"
cd "$project_dir/build"
/usr/bin/zip -qry TagLookup-unsigned.ipa Payload
python3 "$project_dir/scripts/verify-ipa.py" TagLookup-unsigned.ipa
echo "Created: $project_dir/build/TagLookup-unsigned.ipa"
echo "Sign the IPA with your sideloading app before installing."
