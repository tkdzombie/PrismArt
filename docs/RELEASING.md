# Releasing

## GitHub release path used today

No Apple Developer account is required.

Push a SemVer tag:

```bash
git tag v1.0.0
git push origin v1.0.0
```

`.github/workflows/release.yml` runs on GitHub-hosted macOS and Windows runners and publishes:

```text
PrismArt-1.0.0.dmg
PrismArt-1.0.0.dmg.sha256
PrismArt-1.0.0-Windows-x64.zip
PrismArt-1.0.0-Windows-x64.zip.sha256
```

The app and bundled Primitive engine are Universal (`arm64` + `x86_64`) and the app is
ad-hoc signed. See `docs/GATEKEEPER.md` for the resulting first-launch behavior.

## Local ad-hoc release build

On macOS with Xcode Command Line Tools, Go and Git installed:

```bash
VERSION=1.0.0 BUILD_NUMBER=1 scripts/package.sh
```

Ad-hoc signing is the default when `SIGNING_IDENTITY` is not set.

## Optional Developer ID build in the future

If a Developer ID Application identity becomes available:

```bash
export SIGNING_IDENTITY="Developer ID Application: Your Name (TEAMID)"
VERSION=1.0.0 BUILD_NUMBER=1 scripts/package.sh
```

Then configure:

```bash
export APPLE_ID="you@example.com"
export APPLE_TEAM_ID="TEAMID"
export APPLE_APP_PASSWORD="xxxx-xxxx-xxxx-xxxx"
scripts/notarize.sh dist/PrismArt-1.0.0.dmg
```

Do not describe ad-hoc releases as notarized or Apple-verified.

The Windows ZIP is self-contained and includes `PrismArt.exe` and `primitive.exe`.
Windows users extract the complete archive and launch `PrismArt.exe`.
