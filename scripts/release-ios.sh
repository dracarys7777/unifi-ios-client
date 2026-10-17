#!/usr/bin/env bash
# Run only on a trusted Mac or the protected GitHub Actions testflight job.
set -euo pipefail
# Never enable tracing: credentials are passed to Apple tools through arguments.
set +x
umask 077
cd "$(dirname "$0")/.."
REPO_ROOT="$PWD"

if [[ "$(uname -s)" != Darwin ]]; then
  echo 'iOS release builds require macOS and Xcode.' >&2
  exit 1
fi
for tool in xcodebuild xcrun security xcodegen python3 openssl; do
  command -v "$tool" >/dev/null || { echo "Missing release tool: $tool" >&2; exit 1; }
done
if [[ ! "${BUILD_NUMBER:-}" =~ ^[1-9][0-9]*\.[1-9][0-9]*$ ]]; then
  echo 'BUILD_NUMBER must be a positive run number and attempt, such as 12.1.' >&2
  exit 1
fi
if [[ -e App/GoogleService-Info.plist ]]; then
  echo 'Refusing to overwrite an existing Firebase configuration.' >&2
  exit 1
fi
if [[ -e build/Unifi.xcarchive || -e build/ios/ipa ]]; then
  echo 'Release outputs already exist; use a fresh checkout or move them aside.' >&2
  exit 1
fi

KEYCHAIN_LIST=$(security list-keychains -d user)
SIGNING_DIR=$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/unifi-signing.XXXXXX")
KEYCHAIN_PATH="$SIGNING_DIR/release.keychain-db"
KEYCHAIN_PASSWORD=$(openssl rand -base64 32)
KEYCHAIN_CHANGED=false
FIREBASE_CREATED=false
PROFILE_INSTALLED=false
PROFILE_PATHS=()
ORIGINAL_KEYCHAINS=()
while IFS= read -r keychain; do
  if [[ -n "$keychain" ]]; then ORIGINAL_KEYCHAINS+=("$keychain"); fi
done < <(printf '%s\n' "$KEYCHAIN_LIST" | sed -E 's/^[[:space:]]*"(.*)"[[:space:]]*$/\1/')

cleanup() {
  local result=$?
  trap - EXIT
  set +e
  if [[ "$KEYCHAIN_CHANGED" == true ]]; then
    security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}"
  fi
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1
  if [[ "$PROFILE_INSTALLED" == true ]]; then rm -f "${PROFILE_PATHS[@]}"; fi
  if [[ "$FIREBASE_CREATED" == true ]]; then rm -f "$REPO_ROOT/App/GoogleService-Info.plist"; fi
  rm -rf "$SIGNING_DIR"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

python3 scripts/prepare_release.py stage "$SIGNING_DIR"
FIREBASE_CREATED=true
python3 scripts/prepare_firebase.py
security cms -D -i "$SIGNING_DIR/profile.mobileprovision" > "$SIGNING_DIR/profile.plist"
python3 scripts/prepare_release.py profile "$SIGNING_DIR"
PROFILE_UUID=$(cat "$SIGNING_DIR/profile-uuid")
PROFILE_NAME=$(cat "$SIGNING_DIR/profile-name")
# Xcode releases use both locations. Install the identical profile in each;
# preserve existing files and track only our own copies for cleanup.
PROFILE_DIRECTORIES=(
  "$HOME/Library/MobileDevice/Provisioning Profiles"
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
)
for profile_directory in "${PROFILE_DIRECTORIES[@]}"; do
  if [[ -e "$profile_directory/$PROFILE_UUID.mobileprovision" ]]; then
    echo 'Refusing to replace an existing provisioning profile; use a fresh runner.' >&2
    exit 1
  fi
done
for profile_directory in "${PROFILE_DIRECTORIES[@]}"; do
  mkdir -p "$profile_directory"
  profile_path="$profile_directory/$PROFILE_UUID.mobileprovision"
  cp "$SIGNING_DIR/profile.mobileprovision" "$profile_path"
  PROFILE_PATHS+=("$profile_path")
  PROFILE_INSTALLED=true
done

security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$SIGNING_DIR/certificate.p12" -P "$P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security -t cert -f pkcs12 -k "$KEYCHAIN_PATH" >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
KEYCHAIN_CHANGED=true
security list-keychains -d user -s "$KEYCHAIN_PATH" "${ORIGINAL_KEYCHAINS[@]}"

python3 scripts/make_icon.py
xcodegen generate
PROFILE_NAME="$PROFILE_NAME" bash scripts/archive-ios.sh
xcodebuild -exportArchive -archivePath build/Unifi.xcarchive \
  -exportPath build/ios/ipa -exportOptionsPlist "$SIGNING_DIR/ExportOptions.plist"

IPAS=("$REPO_ROOT"/build/ios/ipa/*.ipa)
if [[ ${#IPAS[@]} -ne 1 || ! -f "${IPAS[0]}" ]]; then
  echo 'Expected exactly one exported IPA.' >&2
  exit 1
fi
if [[ "${UPLOAD_TO_TESTFLIGHT:-false}" == true ]]; then
  # altool looks for ./private_keys/AuthKey_<key ID>.p8.
  # This uploads a build only; Apple processing and tester assignment are separate.
  cd "$SIGNING_DIR"
  xcrun altool --upload-app --type ios --file "${IPAS[0]}" \
    --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
  cd "$REPO_ROOT"
fi
echo 'Signed IPA exported successfully.'
