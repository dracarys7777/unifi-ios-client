"""Stage release credentials and validate App Store provisioning without logging values."""
import argparse
import base64
import binascii
from datetime import datetime, timezone
import os
from pathlib import Path
import plistlib
import re
import uuid

BUNDLE_ID = "com.suhasmallya7.unifi"
APP_ATTEST_ENTITLEMENT = "com.apple.developer.devicecheck.appattest-environment"


def required(environment, name):
    value = environment.get(name, "")
    if not value:
        raise ValueError(f"Missing required setting: {name}")
    return value


def decode(environment, name):
    try:
        result = base64.b64decode(required(environment, name), validate=True)
    except (binascii.Error, ValueError):
        raise ValueError(f"{name} must contain nonempty, single-line base64") from None
    if not result:
        raise ValueError(f"{name} must contain nonempty, single-line base64")
    return result


def stage_credentials(directory, environment):
    if not re.fullmatch(r"[A-Z0-9]{10}", required(environment, "APPLE_TEAM_ID")):
        raise ValueError("APPLE_TEAM_ID must be a 10-character Apple team identifier")
    required(environment, "P12_PASSWORD")
    # Validate Firebase presence before touching the keychain. Its existing helper
    # validates the plist contents before writing the app resource.
    required(environment, "FIREBASE_PLIST_BASE64")
    uploads = environment.get("UPLOAD_TO_TESTFLIGHT", "false")
    if uploads not in ("true", "false"):
        raise ValueError("UPLOAD_TO_TESTFLIGHT must be true or false")
    files = {
        "certificate.p12": decode(environment, "BUILD_CERTIFICATE_BASE64"),
        "profile.mobileprovision": decode(environment, "BUILD_PROVISION_PROFILE_BASE64"),
    }
    if uploads == "true":
        key_id = required(environment, "ASC_KEY_ID")
        if not re.fullmatch(r"[A-Z0-9]{10}", key_id):
            raise ValueError("ASC_KEY_ID must be a 10-character Apple API key identifier")
        try:
            uuid.UUID(required(environment, "ASC_ISSUER_ID"))
        except ValueError:
            raise ValueError("ASC_ISSUER_ID must be an App Store Connect issuer UUID") from None
        files[f"private_keys/AuthKey_{key_id}.p8"] = decode(environment, "ASC_PRIVATE_KEY_BASE64")
    for relative, data in files.items():
        target = directory / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
        target.chmod(0o600)


def export_options(profile, team_id, now=None):
    """Reject expired, development, ad hoc, and mismatched profiles before signing."""
    now = now or datetime.now(timezone.utc)
    expiry = profile.get("ExpirationDate")
    if not isinstance(expiry, datetime) or expiry.replace(tzinfo=timezone.utc) <= now:
        raise ValueError("Provisioning profile is expired or has no valid expiration date")
    if team_id not in profile.get("TeamIdentifier", []):
        raise ValueError("Provisioning profile does not belong to APPLE_TEAM_ID")
    entitlements = profile.get("Entitlements", {})
    if entitlements.get("application-identifier") != f"{team_id}.{BUNDLE_ID}":
        raise ValueError("Provisioning profile does not match the app bundle ID")
    if entitlements.get("com.apple.developer.team-identifier") != team_id:
        raise ValueError("Provisioning profile entitlement does not match APPLE_TEAM_ID")
    if (entitlements.get("get-task-allow") or "ProvisionedDevices" in profile
            or profile.get("ProvisionsAllDevices") or "iOS" not in profile.get("Platform", [])):
        raise ValueError("An iOS App Store distribution provisioning profile is required")
    allowed_attest_environments = entitlements.get(APP_ATTEST_ENTITLEMENT, [])
    if isinstance(allowed_attest_environments, str):
        allowed_attest_environments = [allowed_attest_environments]
    if not isinstance(allowed_attest_environments, list) or "production" not in allowed_attest_environments:
        raise ValueError(
            "Provisioning profile does not allow production App Attest. "
            "Enable App Attest for the app's Apple identifier, regenerate the "
            "App Store distribution profile, and update BUILD_PROVISION_PROFILE_BASE64 "
            "in the testflight environment."
        )
    profile_id = profile.get("UUID", "")
    if not isinstance(profile_id, str) or not re.fullmatch(
            r"[A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12}", profile_id):
        raise ValueError("Provisioning profile UUID is invalid")
    return {
        "method": "app-store-connect",
        "destination": "export",
        "teamID": team_id,
        "signingStyle": "manual",
        "signingCertificate": "Apple Distribution",
        "provisioningProfiles": {BUNDLE_ID: profile_id},
        "manageAppVersionAndBuildNumber": False,
        "testFlightInternalTestingOnly": True,
        "uploadSymbols": True,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=("stage", "profile"))
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    try:
        if args.operation == "stage":
            stage_credentials(args.directory, os.environ)
        else:
            with (args.directory / "profile.plist").open("rb") as stream:
                profile = plistlib.load(stream)
            options = export_options(profile, required(os.environ, "APPLE_TEAM_ID"))
            name = profile.get("Name")
            if not isinstance(name, str) or not name.strip() or any(c in name for c in "\r\n\x00"):
                raise ValueError("Provisioning profile name is missing or invalid")
            (args.directory / "ExportOptions.plist").write_bytes(plistlib.dumps(options))
            (args.directory / "profile-uuid").write_text(options["provisioningProfiles"][BUNDLE_ID])
            (args.directory / "profile-name").write_text(name)
    except (ValueError, OSError, plistlib.InvalidFileException) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
