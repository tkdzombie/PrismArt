# QA status

## Verified in the authoring environment

The source bundle was checked on Linux with Swift 6.2.1:

- `swift test` passes all platform-neutral unit tests.
- debug tests and a production `swift build -c release` both build successfully on Linux (macOS UI is conditionally compiled);
- every Swift source/test file passes `swiftc -parse` syntax parsing;
- every shell script passes `bash -n`;
- `scripts/audit-source.sh` confirms no `URLSession`, `UserDefaults`, Application Support,
  LaunchAgent, SMAppService or shell-execution markers exist in application source;
- command construction preserves paths with spaces and explicitly uses all upstream CPU workers;
- Quick Preview settings are bounded and preserve artistic shape/alpha choices;
- preset matching is tested independently of export format;
- settings validation covers shape count, alpha, analysis size and output size.

## macOS release gates

The following gates are intentionally delegated to `.github/workflows/ci.yml` on a real
GitHub-hosted macOS runner because the authoring container does not contain Apple's SDK:

- compile all SwiftUI/AppKit code against the macOS SDK;
- build arm64 and x86_64 GUI executables and combine them with `lipo`;
- fetch/build the upstream Primitive engine for both architectures;
- generate the `.icns`, `.app` and DMG;
- apply and verify an ad-hoc code signature;
- verify both Universal binary architectures;
- validate the DMG with `hdiutil`;
- validate the SHA-256 checksum.

## Hardware acceptance target

Primary target: Apple Silicon MacBook Air (including M-series systems) on current macOS.
The release artifact remains Universal for Intel compatibility.

Recommended manual smoke test before calling a tag stable:

1. launch from `/Applications`;
2. open a HEIC photo and confirm orientation;
3. drag a JPEG and paste a clipboard image;
4. rapidly move the Shapes slider and confirm stale previews never overwrite newer ones;
5. cancel a preview and a full render;
6. export PNG, JPEG, SVG and GIF;
7. verify a 4096/8192 output setting does not alter Quick Preview responsiveness;
8. quit and confirm PrismArt temporary workspaces are removed on the next launch;
9. delete the app and confirm no PrismArt-owned `~/Library` state was created.
