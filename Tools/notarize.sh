#!/bin/bash
# Notarize an already Developer ID-signed app using an existing Keychain profile.
set -euo pipefail
app_path="${1:?Usage: Tools/notarize.sh path/to/Auspex.app keychain-profile}"
notary_profile="${2:?Provide a saved notarytool Keychain profile}"
signature_details="$(codesign -dv --verbose=4 "$app_path" 2>&1)"
if [[ "$signature_details" != *"Authority=Developer ID Application:"* ]]; then
    echo "error: Notarization requires a Developer ID Application signature." >&2
    exit 1
fi
if [[ "$signature_details" != *"runtime"* || "$signature_details" != *"Timestamp="* ]]; then
    echo "error: Sign with hardened runtime and a secure timestamp before notarizing." >&2
    exit 1
fi
codesign --verify --deep --strict "$app_path"
notary_work="$(mktemp -d "${TMPDIR:-/tmp}/auspex-notary.XXXXXX")"
trap 'rm -rf "$notary_work"' EXIT
ditto -c -k --keepParent "$app_path" "$notary_work/Auspex.zip"
xcrun notarytool submit "$notary_work/Auspex.zip" --keychain-profile "$notary_profile" \
    --wait --output-format json > "$notary_work/result.json"
python3 - "$notary_work/result.json" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    result = json.load(stream)
if result.get('status') != 'Accepted':
    raise SystemExit('Notarization was not accepted; inspect the submission with notarytool log. ID: ' + str(result.get('id', 'unknown')))
print('Notarization accepted. Submission:', result.get('id'))
PY
xcrun stapler staple "$app_path"
xcrun stapler validate "$app_path"
codesign --verify --deep --strict "$app_path"
spctl --assess --type execute --verbose=2 "$app_path"
