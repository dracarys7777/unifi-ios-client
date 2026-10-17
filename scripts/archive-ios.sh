#!/usr/bin/env bash
# Called from the repository root by release-ios.sh after signing setup.
set -euo pipefail
: "${APPLE_TEAM_ID:?Missing APPLE_TEAM_ID}"
: "${PROFILE_NAME:?Missing PROFILE_NAME}"
: "${BUILD_NUMBER:?Missing BUILD_NUMBER}"

# The app's Release configuration consumes UNIFI_SIGNING_* inputs. Native signing
# overrides here would also force the app's profile onto dependency resource bundles.
xcodebuild archive -project Unifi.xcodeproj -scheme Unifi -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Unifi.xcarchive \
  -derivedDataPath build/ReleaseDerivedData \
  UNIFI_SIGNING_TEAM="$APPLE_TEAM_ID" UNIFI_SIGNING_PROFILE="$PROFILE_NAME" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER"
