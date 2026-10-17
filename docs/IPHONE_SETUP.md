# Build and install using only an iPhone

Use Safari for GitHub, Apple Developer, App Store Connect, and Firebase. GitHub Actions supplies the Mac and runs Apple's `xcodebuild`; Codemagic and Xcode Cloud are not used. A paid Apple Developer membership is required for TestFlight. You do not need your own Mac, but you must supply a distribution certificate with its private key and an App Store provisioning profile.

## 1. Merge and check the source

The foundation files are already on `main`. Review and merge the migration PR containing `.github/workflows/testflight.yml` before using the new release workflow. In GitHub Actions, confirm both `validate` and `ios` pass for the reviewed revision. Neither job requires Firebase or signing credentials.

The open earlier PR adding `docs/SETUP.md` proposes Xcode Cloud; that proposal is superseded by this GitHub Actions workflow. Review that PR separately rather than merging conflicting build instructions.

If editing from an iPhone, use a private GitHub Codespace or GitHub's web editor, a scoped branch, and a PR. Do not upload the source ZIP again. Signing credentials belong in the protected release environment, never in the repository or coding-agent environment.

## 2. Prepare Apple distribution

In Safari, sign in to [Apple Developer](https://developer.apple.com/account/) and [App Store Connect](https://appstoreconnect.apple.com/).

1. Register an explicit App ID for `com.suhasmallya7.unifi` and create the matching App Store Connect app record. If this identifier is unavailable, change it consistently in `project.yml`, `scripts/prepare_firebase.py`, and `scripts/prepare_release.py` through a separate reviewed change, and use matching Firebase and Apple registrations.
2. Create an **Apple Distribution** certificate and export it with its private key as a password-protected `.p12`. A downloaded `.cer` alone is insufficient. If you already have a signing identity, reuse it; do not revoke existing certificates to make this workflow work.
3. Enable **App Attest** for this App ID, then create an **App Store Connect distribution** provisioning profile for this App ID and certificate. The app requests `com.apple.developer.devicecheck.appattest-environment = production` in `App/Unifi.entitlements`; the profile must permit that value. Development, ad hoc, and enterprise profiles are rejected. If you enable the capability after creating a profile, regenerate and download the profile and replace `BUILD_PROVISION_PROFILE_BASE64` under the GitHub `testflight` environment. Editing the entitlement file alone cannot grant a capability missing from the profile.
4. Record your 10-character Apple Team ID.
5. For upload, create a suitably scoped App Store Connect **team API key**, with access to this app and build upload (for example, the Developer role). Save its `.p8`, key ID, and issuer ID securely. The private key is downloadable only once. Exporting an IPA without upload does not require this API key.

Without a Mac, you can generate a private key and CSR using OpenSSL in a private terminal you control, upload the CSR to Apple's certificate portal in Safari, and download the resulting distribution certificate. For example, in a private Codespace with no coding agents running, outside the checkout:

```bash
umask 077
mkdir -p /tmp/unifi-owner-signing
cd /tmp/unifi-owner-signing
openssl genrsa -aes256 -out distribution.key 2048
openssl req -new -key distribution.key -out distribution.csr
# Upload distribution.csr in Apple's portal, then download distribution.cer here.
openssl x509 -inform DER -in distribution.cer -out distribution.pem
openssl pkcs12 -export -inkey distribution.key -in distribution.pem -out distribution.p12
```

OpenSSL prompts locally for passwords and CSR details. Keep the private key, `.p12`, and passwords under your control; do not paste them into chat or commit them. Securely back up the signing identity before deleting temporary files or the Codespace. Certificate issuance and API access depend on your Apple membership and role.

## 3. Connect Google/Firebase

Create/select a billed Google Cloud project; add Firebase; enable Firebase AI Logic with the Google Cloud/Vertex provider. Register the matching iOS bundle ID and download `GoogleService-Info.plist`. Enable Firebase Authentication email/password and create your own account in the console. The app does not provide public self-registration.

Register App Check with App Attest, complete the Apple capability/environment configuration, observe valid requests, then enforce protection for Firebase AI Logic. Debug simulator tokens are only for development and must not be committed or put in public build logs. Review project quotas and budget alerts. Firebase authentication alone does not restrict access to the project owner.

Choose a supported model ID and region from your project's model access screen. No permanently available default model is assumed.

## 4. Configure protected GitHub release settings

In the repository's **Settings → Environments**, create **`testflight`**. Before adding credentials, configure required owner review and deployment branches restricted to `main`. Keep repository Actions permissions at read-only; this workflow needs no write permission. If your plan or role cannot enforce these protections, resolve that before adding release credentials.

Add this environment variable:

| Variable | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your 10-character Apple team identifier |

Add these **environment secrets**, not repository-wide secrets:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Single-line base64 of the password-protected distribution `.p12` |
| `P12_PASSWORD` | The `.p12` export password |
| `BUILD_PROVISION_PROFILE_BASE64` | Single-line base64 of the App Store distribution `.mobileprovision` |
| `FIREBASE_PLIST_BASE64` | Single-line base64 of `GoogleService-Info.plist` |
| `ASC_KEY_ID` | App Store Connect team API key ID; required only for upload |
| `ASC_ISSUER_ID` | App Store Connect issuer UUID; required only for upload |
| `ASC_PRIVATE_KEY_BASE64` | Single-line base64 of the `.p8`; required only for upload |

To encode a file in a private terminal, write the output to a private file instead of printing it in build logs:

```bash
python3 -c 'import base64, pathlib, sys; pathlib.Path(sys.argv[2]).write_bytes(base64.b64encode(pathlib.Path(sys.argv[1]).read_bytes()))' input-file output.base64
```

Transfer the encoded value only through GitHub's secret-entry UI. Base64 is not encryption. Remove temporary copies after saving and backing up the originals securely. Do not put these files into a coding-agent task or this public repository. No signing or Firebase values have been supplied by this migration.

## 5. Run the build from Safari

1. Open **Actions → iOS TestFlight → Run workflow**. Choose `main`.
2. Leave **Upload the signed build to App Store Connect for TestFlight** off for the first export check.
3. The workflow runs the Python and simulator tests first, without release credentials. Approve the separate release job only after reviewing the revision.
4. The release job uses a temporary keychain, validates the profile and Firebase plist, runs `xcodebuild archive` and `xcodebuild -exportArchive`, and cleans up its credentials on success or failure. Build numbers use `run number.run attempt`, so retries get a new build number. If this marketing version already has higher build numbers from another system, adjust the numbering in a reviewed change before upload.
5. On success, the **Unifi-…** artifact contains the signed IPA and is retained for seven days. A downloaded App Store IPA cannot be installed directly from Files or Safari.
6. To send it to Apple, run the workflow again with upload enabled. It creates a new build and uses `xcrun altool` to upload. Upload success does not mean Apple processing or installation has finished.

These builds are marked for **internal TestFlight testing only**. This workflow does not submit to App Review, publish to the App Store, or automatically add a build to a tester group. No Codemagic integration or environment group is needed.

For a trusted separate Mac, the same script can be used after resolving packages with `xcodegen generate` and `xcodebuild -resolvePackageDependencies -project Unifi.xcodeproj -scheme Unifi`, setting the documented release inputs and a unique `BUILD_NUMBER` such as `12.1`. Use Xcode 16 or newer and a fresh checkout; `bash scripts/release-ios.sh` refuses to overwrite an existing Firebase plist, installed matching profile, or release outputs.

## 6. Install through TestFlight

In App Store Connect, wait for processing, complete any required export-compliance information, create an internal testing group, and add the processed build and your eligible App Store Connect user. Install [TestFlight](https://apps.apple.com/app/testflight/id899247664) from the App Store and accept the invitation.

On the iPhone, verify sign-in; a live reply; a second message using history; stop followed immediately by another message; airplane mode; relaunch persistence; account separation; confirmed deletion; Dynamic Type and VoiceOver; App Check and quota failures. A successful archive or simulator run does not establish these behaviors.

## 7. Maintenance and recovery

After CI has run, require the `validate` and `ios` checks and owner review for workflow/signing changes. Scheduled upstream-watch configuration is independent of the release workflow; verify its operation separately. Coding/review agents and production telemetry require separate setup.

If a beta is faulty, stop new release dispatches, expire the affected TestFlight build if appropriate, and prepare a reviewed correction. Source rollback does not replace an already installed app. Existing Codemagic account connections are external settings: this change removes the repository configuration but does not disconnect your account, delete its secrets, or cancel its jobs. Disable any old Codemagic triggers before the first GitHub release.
