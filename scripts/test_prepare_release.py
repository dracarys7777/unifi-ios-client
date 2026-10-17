import base64
from copy import deepcopy
from datetime import datetime, timedelta, timezone
import plistlib
from pathlib import Path
import tempfile
import unittest

from prepare_release import APP_ATTEST_ENTITLEMENT, BUNDLE_ID, export_options, stage_credentials


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.team = "TESTTEAM01"
        self.now = datetime(2026, 1, 1, tzinfo=timezone.utc)
        self.profile = {
            "UUID": "11111111-2222-3333-4444-555555555555",
            "ExpirationDate": self.now + timedelta(days=30),
            "TeamIdentifier": [self.team],
            "Platform": ["iOS"],
            "Entitlements": {
                "application-identifier": f"{self.team}.{BUNDLE_ID}",
                "com.apple.developer.team-identifier": self.team,
                "get-task-allow": False,
                APP_ATTEST_ENTITLEMENT: "production",
            },
        }
        # Deliberately fake bytes; no Apple or Firebase credentials are used.
        self.environment = {
            "APPLE_TEAM_ID": self.team,
            "P12_PASSWORD": "unit-test-placeholder",
            "FIREBASE_PLIST_BASE64": "unit-test-placeholder",
            "BUILD_CERTIFICATE_BASE64": base64.b64encode(b"fake certificate").decode(),
            "BUILD_PROVISION_PROFILE_BASE64": base64.b64encode(b"fake profile").decode(),
        }

    def test_export_is_manual_internal_testflight_and_does_not_upload(self):
        options = export_options(self.profile, self.team, self.now)
        self.assertEqual(options["provisioningProfiles"], {BUNDLE_ID: self.profile["UUID"]})
        self.assertEqual(options["destination"], "export")
        self.assertEqual(options["method"], "app-store-connect")
        self.assertEqual(options["signingStyle"], "manual")
        self.assertTrue(options["testFlightInternalTestingOnly"])
        self.assertFalse(options["manageAppVersionAndBuildNumber"])
        self.assertEqual(plistlib.loads(plistlib.dumps(options)), options)

    def test_rejects_wrong_team_bundle_and_expiration(self):
        cases = [
            ("TeamIdentifier", ["OTHERTEAM1"]),
            ("ExpirationDate", self.now),
            ("ExpirationDate", None),
            ("UUID", "../../not-a-profile"),
        ]
        for field, value in cases:
            with self.subTest(field=field, value=value):
                profile = deepcopy(self.profile)
                profile[field] = value
                with self.assertRaises(ValueError):
                    export_options(profile, self.team, self.now)
        profile = deepcopy(self.profile)
        profile["Entitlements"]["application-identifier"] = self.team + ".other.app"
        with self.assertRaisesRegex(ValueError, "bundle ID"):
            export_options(profile, self.team, self.now)

    def test_rejects_development_adhoc_enterprise_and_non_ios_profiles(self):
        for kind in ("development", "adhoc", "enterprise", "macOS"):
            with self.subTest(kind=kind):
                profile = deepcopy(self.profile)
                if kind == "development": profile["Entitlements"]["get-task-allow"] = True
                if kind == "adhoc": profile["ProvisionedDevices"] = ["fake-device"]
                if kind == "enterprise": profile["ProvisionsAllDevices"] = True
                if kind == "macOS": profile["Platform"] = ["OSX"]
                with self.assertRaisesRegex(ValueError, "App Store distribution"):
                    export_options(profile, self.team, self.now)

    def test_export_does_not_require_an_upload_key(self):
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            stage_credentials(directory, self.environment)
            self.assertEqual((directory / "certificate.p12").read_bytes(), b"fake certificate")
            self.assertEqual((directory / "certificate.p12").stat().st_mode & 0o777, 0o600)
            self.assertFalse((directory / "private_keys").exists())

    def test_rejects_profile_without_production_app_attest(self):
        for allowed in (None, "development", ["development"], False):
            with self.subTest(allowed=allowed):
                profile = deepcopy(self.profile)
                if allowed is None:
                    del profile["Entitlements"][APP_ATTEST_ENTITLEMENT]
                else:
                    profile["Entitlements"][APP_ATTEST_ENTITLEMENT] = allowed
                with self.assertRaisesRegex(ValueError, "production App Attest"):
                    export_options(profile, self.team, self.now)

    def test_accepts_profile_allowing_production_in_environment_list(self):
        profile = deepcopy(self.profile)
        profile["Entitlements"][APP_ATTEST_ENTITLEMENT] = ["development", "production"]
        self.assertEqual(export_options(profile, self.team, self.now)["teamID"], self.team)

    def test_upload_requires_key_before_writing_any_credentials(self):
        environment = {**self.environment, "UPLOAD_TO_TESTFLIGHT": "true"}
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            with self.assertRaisesRegex(ValueError, "ASC_KEY_ID"):
                stage_credentials(directory, environment)
            self.assertEqual(list(directory.iterdir()), [])

    def test_upload_key_filename_cannot_escape_private_directory(self):
        environment = {
            **self.environment, "UPLOAD_TO_TESTFLIGHT": "true",
            "ASC_KEY_ID": "../bad-key",
        }
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(ValueError, "ASC_KEY_ID"):
                stage_credentials(Path(temp), environment)

    def test_valid_upload_stages_key_privately(self):
        environment = {
            **self.environment, "UPLOAD_TO_TESTFLIGHT": "true",
            "ASC_KEY_ID": "TESTKEY001",
            "ASC_ISSUER_ID": "11111111-2222-3333-4444-555555555555",
            "ASC_PRIVATE_KEY_BASE64": base64.b64encode(b"fake upload key").decode(),
        }
        with tempfile.TemporaryDirectory() as temp:
            directory = Path(temp)
            stage_credentials(directory, environment)
            key = directory / "private_keys/AuthKey_TESTKEY001.p8"
            self.assertEqual(key.read_bytes(), b"fake upload key")
            self.assertEqual(key.stat().st_mode & 0o777, 0o600)

    def test_rejects_corrupt_base64_without_echoing_value(self):
        environment = {**self.environment, "BUILD_CERTIFICATE_BASE64": "do-not-log-this!"}
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaises(ValueError) as error:
                stage_credentials(Path(temp), environment)
            self.assertNotIn(environment["BUILD_CERTIFICATE_BASE64"], str(error.exception))


if __name__ == "__main__":
    unittest.main()
