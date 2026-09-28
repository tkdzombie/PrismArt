# Gatekeeper and first launch

PrismArt's public GitHub builds are currently **ad-hoc signed** because the project does
not use a paid Apple Developer ID certificate. Ad-hoc signing verifies bundle integrity
locally but does not identify the developer to Apple and cannot be notarized.

As a result, a DMG downloaded from GitHub can be blocked by macOS on first launch.

## Recommended verification

1. Download both the `.dmg` and matching `.dmg.sha256` file from the same GitHub Release.
2. In Terminal, verify the checksum:

```bash
shasum -a 256 -c PrismArt-1.0.0.dmg.sha256
```

3. Open the DMG and drag PrismArt to Applications.
4. Try to open PrismArt once.
5. If macOS blocks it and you trust the source/checksum, open **System Settings → Privacy & Security**.
6. Scroll to the Security section and choose **Open Anyway**, then confirm.

Apple documents this override for apps from unidentified developers. Do not use it for
software you do not trust.

## Why PrismArt does not remove quarantine attributes

The project deliberately does not tell users to run commands such as
`xattr -dr com.apple.quarantine ...` as the normal installation path. That bypasses a
macOS safety signal more broadly than the system's per-app Open Anyway flow.

## Future path

If the project later gets a Developer ID Application certificate, `scripts/package.sh`
can sign with that identity and `scripts/notarize.sh` can submit the DMG for notarization.
