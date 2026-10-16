# iPhone setup checklist

## 1. Grant repository write access

The current ChatGPT GitHub connection can read dracarys7777/unifi-ios-client, but branch creation returned HTTP 403 Resource not accessible by integration. Your user account having push access does not mean the integration has it.

On iPhone Safari, open GitHub Settings > Applications > Installed GitHub Apps. Find the app used by ChatGPT/Codex, choose Configure and ensure unifi-ios-client is in its repository selection. Accept an offered permissions update if present. The integration needs repository contents write and pull requests write; workflow upload may need additional workflow permissions. If the installed app only offers read permissions, use a write-capable Codex/GitHub connection or upload through your own authenticated Codespace. Do not paste a personal access token into chat.

The repository is public. If that was unintended, change its visibility in repository Settings > General > Danger Zone. No visibility change has been made by this package.

## 2. Upload this package if using Codespaces

Open the repository in a Codespace using Safari. Upload and unzip the package, copy its contents INCLUDING .github and .gitignore into the repository root, create branch build/unifi-foundation, inspect the diff, commit and push, then open a PR. Do not commit the ZIP or a second nested repository folder. Run the PR checks before merging. Browser folder uploads sometimes omit dotfiles; verify .github/workflows/ci.yml is present.

## 3. First checks

Open the PR Checks tab. `validate` runs the monitor tests; `ios` generates the Xcode project and runs XCTest on an available iPhone simulator. No Firebase configuration or signing secrets are needed. Fix failures before configuring distribution. Commit the resolved Swift package lockfile from a successful build in a follow-up and teach CI to restore it before resolution.

## 4. Connect Google/Firebase

Create/select a billed Google Cloud project; add Firebase; enable Firebase AI Logic with the Google Cloud/Vertex provider. Register iOS bundle com.suhasmallya.unifi (change project.yml if unavailable). Download GoogleService-Info.plist to Files. Enable Firebase Authentication email/password and create your own account in its console. Do not enable public self-registration in the app.

Register App Check for the app with App Attest, complete required Apple identifiers/environment configuration, observe valid requests then enforce protection for Firebase AI Logic. Debug simulator tokens are only for development; never place them in source or public build logs. Review project quotas and set budget alerts. Verify access controls before distributing beyond yourself; Firebase authentication alone does not restrict access to the project owner.

Choose a currently supported model ID and region from your project's model access screen. The app deliberately does not assume a permanently available default model.

## 5. Connect Codemagic

Connect this repository at codemagic.io. The `ios-checks` workflow runs simulator checks without secrets. The manual `ios-beta` workflow is a starting configuration requiring:

- App Store Connect integration named `unifi-appstore`, using a suitably scoped API key uploaded directly in Codemagic.
- Environment group `unifi_release` containing secret `FIREBASE_PLIST_BASE64`, the base64 contents of GoogleService-Info.plist. Keep this out of the public repository.
- Apple Developer membership, matching bundle ID, distribution certificate/provisioning profile, and an App Store Connect app record.
- Internal TestFlight group named `Internal testers` with your eligible account added.

Use Codespaces to base64-encode the downloaded plist if needed; upload it only to a private workspace and remove it afterward. App Store Connect and Google credentials must go directly to the appropriate service, not into chat.

The beta workflow is manual and has no push trigger. Run it only on a reviewed revision after setup. It runs tests, validates the plist bundle ID, generates a temporary icon asset, signs and uploads. Apple processing/compliance questions can still require interaction. App Store production submission is not configured.

## 6. Device acceptance

Install TestFlight, install the processed build, sign in, and set the model ID/region. Verify a live reply; a second message using history; stop followed immediately by another message; airplane mode; relaunch persistence; sign-out/account separation; confirmed deletion; Dynamic Type and VoiceOver; App Check rejection and quota errors. Do not call the beta production-ready until these pass.

## 7. Activate lifecycle work

After merge, enable Actions and verify the upstream-watch manual run. Enable a coding-agent service and code review for the repository. File a small feature request using the template and assign it through that service. Review its PR and TestFlight build. Instructions in AGENTS.md are not a provisioned autonomous service.
