"""Fail before building with an App Store-incompatible Apple toolchain."""
import re
import subprocess

def validate(xcode_output, sdk_output):
    match = re.search(r"^Xcode (\d+)(?:\.\d+)*\s*$", xcode_output, re.M)
    if not match or int(match.group(1)) < 26:
        raise ValueError("Xcode 26 or later is required. Check DEVELOPER_DIR.")
    sdk = sdk_output.strip()
    if not re.fullmatch(r"\d+(?:\.\d+)*", sdk) or int(sdk.split(".")[0]) < 26:
        raise ValueError("iPhoneOS SDK 26 or later is required. Rebuild with Xcode 26+.")
    return sdk

def main():
    try:
        xcode = subprocess.check_output(["xcodebuild", "-version"], text=True)
        sdk = subprocess.check_output(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], text=True)
        validate(xcode, sdk)
        print(xcode.strip())
        print("iPhoneOS SDK:", sdk.strip())
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None

if __name__ == "__main__":
    main()
