# Signing and distribution

The default `make dist` output is **ad-hoc signed, not notarized**. Version 1.3 adds a Developer ID packaging path but does not claim a notarized release. This development Mac currently has no Developer ID Application identity or saved Auspex notarization profile. Development/App Store distribution identities are not substitutes; an unrelated organization's identity must not be used.

## With the app owner's credentials

1. Install the owner's **Developer ID Application** certificate and private key in Keychain. Use the Apple Developer account authorized to distribute Auspex.
2. Save that account's notarization credentials with `xcrun notarytool store-credentials Auspex` using Apple's interactive flow. Keep credentials out of source and logs.
3. Build, sign, notarize and package:

   ```sh
   DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make dist \
     VERSION=1.3.0 \
     SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)' \
     NOTARY_PROFILE=Auspex
   ```

The build signs the completed app with hardened runtime and a secure timestamp. `Tools/notarize.sh` rejects an ad-hoc signature, submits with the saved Keychain profile, requires an Accepted result, staples and validates the ticket, and assesses the app before the final ZIP is created. If any step fails, do not publish an archive from an earlier run as though it passed.

## Release checks

- Keep `project.yml`, the local-build script, `Makefile`, changelog, tag and ZIP version/build consistent.
- Run collector/history/preferences/update regressions and deterministic visual fixtures.
- Extract the exact archive; verify its signature, metadata and assets. For notarized builds, validate the stapled ticket and Gatekeeper assessment.
- Test a fresh downloaded copy on another supported Mac, ideally offline after download. Test both macOS 26 and 27, sensor fallback, preferences migration, menu bar visibility, keyboard/VoiceOver, and system accessibility settings. A local render does not certify these interactive checks.
- Upload both the versioned ZIP and `Auspex.zip` to a release tied to the matching source tag. Confirm the public latest download has the expected checksum and version.
- Clearly state the actual signing/notarization status in release notes. Until notarized releases are available, retain accurate first-launch instructions.

## Updates in the app

Settings checks GitHub's public latest stable release metadata only after the user presses **Check for Updates**. It compares numeric versions and validates the release URL belongs to this repository. Network errors can be retried; older versions are never offered as updates. It opens the release page for manual installation. There is no background check, telemetry, custom installer or automatic update framework.

References: [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution), [packaging Mac software](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution), [GitHub release API](https://docs.github.com/en/rest/releases/releases#get-the-latest-release).
