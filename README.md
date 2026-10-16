# unifi

Native iPhone client for Google Cloud-backed Gemini, with a repository-based development lifecycle.

## Status

Foundation source only: not yet compiled on macOS, connected to a live Google project, signed, installed, or released. Repository upload is pending write access. Swift SDK integration targets Firebase 12.3.0 (an explicit baseline, not a claim of the latest release).

Included: streaming text chat; configurable model ID, region and system instruction; Firebase email/password sign-in; App Check; one locally saved conversation per user; cancellation; share; explicit clear; simulator tests; GitHub CI; upstream-change reporting; agent instructions; issue templates; Codemagic configuration.

Not implemented: image/PDF input, conversation browser, prompt library, model comparison, Google OAuth/project switching, token/cost display, runtime telemetry, remote feature flags, actual coding-agent provisioning or autonomous fixes. The app is not a full mirror of Vertex AI Studio.

Start with [the iPhone guide](docs/IPHONE_SETUP.md). See [product scope](docs/PRODUCT.md), [lifecycle policy](docs/LIFECYCLE.md), and [verification status](docs/VERIFICATION.md).

## Build

On a cloud Mac: `bash scripts/check-ios.sh`. XcodeGen produces `Unifi.xcodeproj` from `project.yml`. The base app launches with a configuration-needed screen when GoogleService-Info.plist is absent; CI never needs a live Google key. Run monitor tests with `python3 -m unittest discover -s scripts -p 'test_*.py'`.

No license has been selected by the owner. This scaffold deliberately does not add one.
