# Build and install using only an iPhone

Use Safari for GitHub, Apple Developer, App Store Connect, and Firebase. GitHub Actions supplies the Mac and runs Apple's `xcodebuild`; Codemagic and Xcode Cloud are not used. The migration is already merged into `main`. You do not need to upload the ZIP, set up Codemagic, or merge the migration again.

A paid Apple Developer membership is required for TestFlight. You do not need your own Mac, but you must supply a distribution certificate with its private key and an App Store provisioning profile. The first export-only run still creates a **signed** build: it requires those signing files and Firebase configuration. Only the App Store Connect upload key can wait until later.

The path to installation is:

1. Prepare Apple signing files and Firebase configuration.
2. Create the protected GitHub environment named `testflight`.
3. Add `APPLE_TEAM_ID` as an **environment variable**, and signing values as **environment secrets**.
4. Run **iOS TestFlight** on `main` with upload unchecked and confirm IPA export succeeds.
5. Add the upload key, run again with upload checked, then install through TestFlight.

On iPhone, use Safari's **Request Desktop Website** if GitHub or Apple settings are hidden. You need repository administrator access for environment settings and appropriate Apple account access for certificates, API keys, and the app record.

## 1. Check the source

Open [GitHub Actions](https://github.com/dracarys7777/unifi-ios-client/actions) and confirm the `validate` and `ios` checks pass for the reviewed `main` revision. Neither check needs Firebase or signing credentials. Successful simulator checks do not establish that signing, upload, or live Firebase access works.

The current release workflow is [`.github/workflows/testflight.yml`](../.github/workflows/testflight.yml). Older proposals describing Xcode Cloud are not the setup used by this guide.

If editing from an iPhone, use a private GitHub Codespace or GitHub's web editor, a scoped branch, and a PR. Do not upload the source ZIP again. Signing credentials belong in the protected release environment, never in the repository or coding-agent environment.

## 2. Prepare Apple distribution

In Safari, sign in to [Apple Developer](https://developer.apple.com/account/) and [App Store Connect](https://appstoreconnect.apple.com/).

1. Register an explicit App ID for `com.suhasmallya.unifi` and create the matching App Store Connect app record. If this identifier is unavailable, change it consistently in `project.yml`, `scripts/prepare_firebase.py`, and `scripts/prepare_release.py` through a separate reviewed change, and use matching Firebase and Apple registrations.
2. Create an **Apple Distribution** certificate and export it with its private key as a password-protected `.p12`. A downloaded `.cer` alone is insufficient. If you already have a signing identity, reuse it; do not revoke existing certificates to make this workflow work.
3. Create an **App Store Connect distribution** provisioning profile for this App ID and certificate. Development, ad hoc, and enterprise profiles are rejected. Complete the App Attest capability setup required by Firebase App Check.
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

Open [Settings → Environments](https://github.com/dracarys7777/unifi-ios-client/settings/environments) in Safari:

1. Tap **New environment**, enter exactly **`testflight`**, then configure the environment. If it already exists, open it instead.
2. Under **Required reviewers**, add yourself or another trusted reviewer and save. If you are the only reviewer and will start the run yourself, leave **Prevent self-review** unchecked; otherwise you cannot approve that run. If your policy requires independent approval, add another eligible reviewer instead.
3. Under **Deployment branches and tags**, choose **Selected branches and tags**, add a branch rule for **`main`**, and save. The workflow also rejects dispatches on other branches.
4. Keep repository Actions permissions at read-only; this workflow needs no write permission. If your plan or role cannot enforce the required protections, resolve that before adding release credentials.

On this same `testflight` page, find **Environment variables → Add variable**:

| Variable | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your 10-character Apple team identifier |

`APPLE_TEAM_ID` is a **variable, not a secret**. The workflow reads `${{ vars.APPLE_TEAM_ID }}`. Find your Team ID in your Apple Developer membership details; it is not your Apple ID email, app bundle ID, API key ID, or App Store Connect issuer ID.

Next, use **Environment secrets → Add secret** on that same page. Add these four secrets for the first export-only build:

| Secret | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Single-line base64 of the password-protected distribution `.p12` |
| `P12_PASSWORD` | The `.p12` export password |
| `BUILD_PROVISION_PROFILE_BASE64` | Single-line base64 of the App Store distribution `.mobileprovision` |
| `FIREBASE_PLIST_BASE64` | Single-line base64 of `GoogleService-Info.plist` |

Add these three more **environment secrets** before enabling upload:

| Secret | Value |
| --- | --- |
| `ASC_KEY_ID` | App Store Connect team API key ID; required only for upload |
| `ASC_ISSUER_ID` | App Store Connect issuer UUID; required only for upload |
| `ASC_PRIVATE_KEY_BASE64` | Single-line base64 of the `.p8`; required only for upload |

To encode a file in a private terminal, write the output to a private file instead of printing it in build logs:

```bash
python3 -c 'import base64, pathlib, sys; pathlib.Path(sys.argv[2]).write_bytes(base64.b64encode(pathlib.Path(sys.argv[1]).read_bytes()))' input-file output.base64
```

For example, replace `input-file` with your `.p12`, `.mobileprovision`, Firebase plist, or `.p8` filename. Open the resulting `output.base64` privately and copy its contents into the matching GitHub secret. `P12_PASSWORD`, `ASC_KEY_ID`, and `ASC_ISSUER_ID` are entered directly, without base64 encoding.

Store all these entries under **the `testflight` environment**, not repository-wide Actions secrets or Codex environment settings. Base64 is not encryption. Remove temporary copies after saving and backing up the originals securely. Do not put signing files or values into a coding-agent task, chat, or this public repository. This guide does not verify whether your settings have been entered.

## 5. Run the first build with upload disabled

1. Open [Actions → iOS TestFlight](https://github.com/dracarys7777/unifi-ios-client/actions/workflows/testflight.yml) and tap **Run workflow**.
2. Select the branch **`main`**.
3. Leave **Upload the signed build to App Store Connect for TestFlight** **unchecked**, then tap **Run workflow** to start.
4. Open the new run. The `checks` job runs Python and simulator tests without release credentials.
5. When the `release` job is waiting, tap **Review deployments**, select **`testflight`**, review the commit, and approve it. Only configured reviewers can approve; if self-review prevention is enabled, someone other than the person who started the run must approve.
6. Wait for the `release` job to turn green. It uses a temporary keychain, validates the profile and Firebase plist, runs `xcodebuild archive` and `xcodebuild -exportArchive`, and cleans up credentials on normal completion or failure.
7. Open the run's **Artifacts** section. The **Unifi-…** artifact contains the signed IPA and is retained for seven days. A downloaded App Store IPA cannot be installed directly from Files or Safari; use the next steps to reach TestFlight.

Build numbers use `run number.run attempt`, so retries get a new build number. If this marketing version already has higher build numbers from another system, adjust the numbering in a reviewed change before upload.

## 6. Enable TestFlight upload

After export succeeds:

1. Confirm the matching app record exists in App Store Connect and the three `ASC_*` environment secrets from section 4 are set.
2. Open **Actions → iOS TestFlight → Run workflow**, choose **`main`**, and **check** the upload option.
3. Start the run, wait for `checks`, and approve the `testflight` deployment as before.
4. Wait for the archive/export/upload step to succeed. This run creates a new signed build and uses Apple's `xcrun altool` to upload it. Upload success does not mean Apple processing or installation has finished.

These builds are marked for **internal TestFlight testing only**. This workflow does not submit to App Review, publish to the App Store, or automatically add a build to a tester group. No Codemagic integration or environment group is needed.

## 7. Install through TestFlight

1. In Safari, open **App Store Connect → My Apps → your app → TestFlight**.
2. Wait for the uploaded build to finish processing and complete any requested export-compliance information.
3. Create an **internal testing** group, add the processed build, and add your eligible App Store Connect user as a tester.
4. Install [TestFlight](https://apps.apple.com/app/testflight/id899247664) from the App Store on your iPhone.
5. Accept the tester invitation, open the app in TestFlight, and tap **Install**.

On the iPhone, verify sign-in; a live reply; a second message using history; stop followed immediately by another message; airplane mode; relaunch persistence; account separation; confirmed deletion; Dynamic Type and VoiceOver; App Check and quota failures. A successful archive or simulator run does not establish these behaviors.

## 8. Troubleshooting

| What you see | What to check |
| --- | --- |
| No **Run workflow** button | Sign in with repository write access, open the `iOS TestFlight` workflow rather than `iOS checks`, and try Safari's desktop website view. |
| Both jobs skipped | Run the workflow on `main`; other branches are intentionally excluded. |
| **Waiting for review** | Use **Review deployments** with a configured reviewer. Check the self-review setting if you started the run. |
| Missing `APPLE_TEAM_ID` | Add it under **testflight → Environment variables**, not secrets. |
| Missing signing/Firebase setting | Add the exact name from the first secrets table under **testflight → Environment secrets**, even for export-only runs. |
| Base64 validation fails | Encode the complete original file as one line, without spaces or line breaks. Do not base64-encode passwords or API key IDs. |
| Provisioning profile rejected | Use an unexpired iOS App Store distribution profile for the same team, bundle ID, and distribution certificate. |
| Certificate import or signing fails | Confirm the `.p12` contains the private key, its password is correct, and its certificate matches the profile. Share error text only, without credentials. |
| Export succeeds but there is no TestFlight build | Export-only does not upload. Set the three upload secrets, run again with upload checked, then check Apple processing status. |
| Upload fails after export | Inspect the failed step's error. If the IPA was exported, the workflow can still retain it as an artifact; an artifact alone does not confirm upload. |

## 9. Maintenance and recovery

After CI has run, require the `validate` and `ios` checks and owner review for workflow/signing changes. Scheduled upstream-watch configuration is independent of the release workflow; verify its operation separately. Coding/review agents and production telemetry require separate setup.

If a beta is faulty, stop new release dispatches, expire the affected TestFlight build if appropriate, and prepare a reviewed correction. Source rollback does not replace an already installed app. Existing Codemagic account connections are external settings: this change removes the repository configuration but does not disconnect your account, delete its secrets, or cancel its jobs. Disable any old Codemagic triggers before the first GitHub release.
