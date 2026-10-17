"""Exercise archive argument handling with a fake xcodebuild, without signing assets."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().with_name("archive-ios.sh")


class ArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        tool = self.directory / "xcodebuild"
        tool.write_text(
            f"#!{sys.executable}\n"
            "import json, os, pathlib, sys\n"
            "pathlib.Path(os.environ['CAPTURED_ARCHIVE_ARGS']).write_text(json.dumps(sys.argv[1:]))\n"
            "sys.exit(int(os.environ.get('SIMULATED_XCODEBUILD_STATUS', '0')))\n"
        )
        tool.chmod(0o700)
        self.capture = self.directory / "arguments.json"
        self.environment = {
            **os.environ,
            "PATH": str(self.directory) + os.pathsep + os.environ["PATH"],
            "CAPTURED_ARCHIVE_ARGS": str(self.capture),
            "APPLE_TEAM_ID": "TESTTEAM01",
            "PROFILE_NAME": "Unifi Test Profile With Spaces",
            "BUILD_NUMBER": "12.2",
            "SIMULATED_XCODEBUILD_STATUS": "0",
        }

    def run_archive(self):
        return subprocess.run(
            ["bash", str(SCRIPT)], cwd=self.directory, env=self.environment,
            capture_output=True, text=True,
        )

    def test_app_profile_is_not_applied_to_dependency_targets(self):
        result = self.run_archive()
        self.assertEqual(result.returncode, 0, result.stderr)
        arguments = json.loads(self.capture.read_text())
        settings = dict(argument.split("=", 1) for argument in arguments if "=" in argument)
        for setting in ("CODE_SIGN_STYLE", "CODE_SIGN_IDENTITY", "DEVELOPMENT_TEAM",
                        "PROVISIONING_PROFILE", "PROVISIONING_PROFILE_SPECIFIER"):
            self.assertNotIn(setting, settings)
        self.assertEqual(settings["UNIFI_SIGNING_TEAM"], "TESTTEAM01")
        self.assertEqual(settings["UNIFI_SIGNING_PROFILE"], "Unifi Test Profile With Spaces")
        self.assertEqual(settings["CURRENT_PROJECT_VERSION"], "12.2")

    def test_failed_archive_retains_xcodebuild_exit_status(self):
        self.environment["SIMULATED_XCODEBUILD_STATUS"] = "65"
        self.assertEqual(self.run_archive().returncode, 65)

    def test_missing_profile_stops_before_xcodebuild(self):
        del self.environment["PROFILE_NAME"]
        result = self.run_archive()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Missing PROFILE_NAME", result.stderr)
        self.assertFalse(self.capture.exists())


if __name__ == "__main__":
    unittest.main()
