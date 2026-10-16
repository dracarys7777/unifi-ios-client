import base64
import os
import plistlib
from pathlib import Path

raw = base64.b64decode(os.environ['FIREBASE_PLIST_BASE64'], validate=True)
config = plistlib.loads(raw)
if config.get('BUNDLE_ID') != 'com.suhasmallya7.unifi':
    raise SystemExit('Firebase bundle ID must match project.yml and signing configuration')
for field in ('GOOGLE_APP_ID', 'API_KEY', 'PROJECT_ID'):
    if not config.get(field): raise SystemExit('Firebase configuration is incomplete')
Path('App/GoogleService-Info.plist').write_bytes(raw)
print('Firebase configuration validated (values not logged).')
