import unittest
from check_toolchain import validate

class ToolchainTests(unittest.TestCase):
    def test_rejects_reported_old_toolchain(self):
        with self.assertRaises(ValueError):
            validate("Xcode 16.4\nBuild version 16F6", "18.5")
    def test_rejects_old_sdk_even_with_new_xcode(self):
        with self.assertRaises(ValueError):
            validate("Xcode 26.3\nBuild version 17C529", "18.5")
    def test_accepts_supported_toolchain(self):
        self.assertEqual(validate("Xcode 26.3\nBuild version 17C529", "26.3\n"), "26.3")
    def test_rejects_unknown_or_prerelease_version(self):
        with self.assertRaises(ValueError):
            validate("Xcode unknown", "26.3")
        with self.assertRaises(ValueError):
            validate("Xcode 26.3 Beta", "26.3")
