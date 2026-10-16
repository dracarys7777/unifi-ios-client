# Product contract

## Objective

Operate a native Google Cloud Gemini workspace from iPhone and develop it through scoped requests, reviewable code changes, and repeatable cloud builds.

## Foundation acceptance criteria

- Unconfigured builds display setup guidance without making model calls.
- Configured builds allow sign-in to an existing Firebase email/password account.
- Model ID is explicitly supplied by the user; region and system instruction are editable.
- Model output streams and can be stopped. A cancelled task must not modify a new request.
- Complete conversation pairs provide context. Partial/empty replies never enter subsequent history.
- History survives relaunch and is partitioned by Firebase user ID, protected on disk, and excluded from backup.
- Corrupt history is not silently overwritten. Clearing history requires an explicit confirmation.
- Requests send prompts/history to Google. No prompt telemetry is included.

## Next milestones

1. Compile and run simulator checks; configure Firebase and verify one live text request on device.
2. Sign and install through TestFlight; validate cancellation, persistence, sign-out, accessibility, offline behavior, quota failures and App Attest.
3. Add multi-conversation browsing, attachments, prompt presets and model capabilities through separate feature issues.
4. Add privacy-aware runtime monitoring, budgeted API canaries and feature flags.
5. Provision coding/review agents and validate the first issue-to-PR-to-device loop.

## Architecture decisions

SwiftUI, iOS 17 minimum; Firebase AI Logic using the Vertex backend; FirebaseAuth email/password as bootstrap access; Firebase App Check; Codable local history; XcodeGen; GitHub Actions for checks, scheduled upstream watch, and manually dispatched TestFlight builds using Apple's command-line tools.

This is a personal beta foundation. Public distribution requires an account-management/access-control design (including limiting access to paid APIs), deletion flows, privacy disclosures, live backend validation and release review. A sign-in screen alone is not a project-owner allowlist.

Google project credentials, Apple signing identity, model access and CI service settings are supplied by the owner. No paid services are automatically enrolled.
