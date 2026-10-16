# unifi

Native iPhone client for Google Cloud-backed Gemini, with a repository-based development lifecycle.

## Status

The foundation source is uploaded and its GitHub Actions simulator checks passed at commit `297656b`. Live Google services, Apple signing, installation, and distribution remain unverified. Swift SDK integration targets Firebase 12.3.0 (an explicit baseline, not a claim of the latest release).

Included: streaming text chat; configurable model ID, region and system instruction; Firebase email/password sign-in; App Check; one locally saved conversation per user; cancellation; share; explicit clear; simulator tests; GitHub CI; upstream-change reporting; agent instructions; issue templates; a manual GitHub Actions TestFlight workflow using Apple command-line tools.

Not implemented: image/PDF input, conversation browser, prompt library, model comparison, Google OAuth/project switching, token/cost display, runtime telemetry, remote feature flags, actual coding-agent provisioning or autonomous fixes. The app is not a full mirror of Vertex AI Studio.

Start with [the iPhone guide](docs/IPHONE_SETUP.md). See [product scope](docs/PRODUCT.md), [lifecycle policy](docs/LIFECYCLE.md), and [verification status](docs/VERIFICATION.md).

## Build

On a cloud Mac: `bash scripts/check-ios.sh`. XcodeGen produces `Unifi.xcodeproj` from `project.yml`. The base app launches with a configuration-needed screen when GoogleService-Info.plist is absent; CI never needs a live Google key. Run monitor tests with `python3 -m unittest discover -s scripts -p 'test_*.py'`.

For a signed iPhone build, follow [the iPhone guide](docs/IPHONE_SETUP.md) to configure the protected `testflight` GitHub environment, then manually run **iOS TestFlight** on `main`. It uses `xcodebuild archive` and `xcodebuild -exportArchive`; optional TestFlight upload uses Apple's `xcrun altool`. Codemagic and a personally owned Mac are not required. A paid Apple Developer membership and signing assets are required. Downloading the IPA alone does not install it on an iPhone; use TestFlight.

No license has been selected by the owner. This scaffold deliberately does not add one.
