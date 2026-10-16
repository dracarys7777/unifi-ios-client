# Verification status

The foundation is merged into `main`. [GitHub Actions run 38970749799](https://github.com/dracarys7777/unifi-ios-client/actions/runs/38970749799) passed the `validate` and macOS `ios` jobs for foundation commit `297656b`. This demonstrates the foundation's simulator workflow; it is not a signed device build or live Firebase verification.

For the Codemagic-to-GitHub-Actions migration, executed in Linux:

- Twelve Python tests passed: four upstream monitor tests and eight release-input/profile tests, using deliberately fake signing data.
- Shell syntax and ShellCheck checks passed for the simulator and release scripts.
- GitHub Actions workflows passed actionlint; Python compilation, YAML parsing, and diff whitespace checks passed.
- The release script rejected Linux with the expected macOS/Xcode requirement before reading credentials.

Not executed for this migration:

- macOS simulator tests on the migration revision; the existing PR CI must run those.
- Native keychain import, certificate/profile compatibility, signed archive, IPA export, or App Store Connect upload. These require a protected owner-configured release environment and a Mac runner.
- Live Firebase authentication, Gemini requests, App Check, iPhone storage/accessibility/cancellation checks, or TestFlight installation.
- Activation of coding agents, scheduled monitoring, or external account configuration. The migration does not disconnect existing Codemagic accounts or configure GitHub environment reviewers/secrets.

The manual TestFlight workflow is configuration awaiting owner review and an actual release run. It does not prove signing or distribution works. Firebase API signatures were previously checked against official SDK 12.3.0 source; device and backend checks remain required before distribution beyond the personal beta.
