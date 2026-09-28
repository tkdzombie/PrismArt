# PrismArt

**Turn photos into geometric artwork — locally on macOS and Windows.**

PrismArt is a native desktop front-end for [fogleman/primitive](https://github.com/fogleman/primitive).
It is designed to feel like a small Mac app rather than a command-line wrapper: drag in an image,
explore styles with a quick preview, then export a full-quality result.

## Highlights

- Native SwiftUI/AppKit interface for macOS 13+.
- Optimized for Apple Silicon while still shipping as a Universal app for Intel Macs.
- Quick Preview mode: debounced low-cost renders while tuning settings.
- Six presets: Balanced, Portrait, Landscape, Architecture, Abstract and Minimal.
- All nine upstream Primitive modes remain available.
- PNG, JPEG, SVG and animated GIF export.
- HEIC, TIFF and other macOS-readable input formats are normalized automatically.
- Drag/drop, Open dialog, clipboard input, and Finder **Open With PrismArt** support.
- No Homebrew, Go, Git, Python or ImageMagick required by end users.
- No cloud processing and no image uploads.
- No app database, login item, launch agent or PATH modification.

## Windows

Download `PrismArt-<version>-Windows-x64.zip` from the same GitHub Release, extract the
entire archive, and run `PrismArt.exe`. The ZIP includes the self-contained .NET runtime
and `primitive.exe`; no Go, .NET, or developer tools are required. Keep both files in the
same folder. Windows builds support PNG, JPEG, BMP, GIF, TIFF, and SVG export; HEIC and
animated GIF export are currently macOS-only.

## Install from GitHub Releases

Download `PrismArt-<version>.dmg`, open it, and drag **PrismArt.app** into Applications.

This project currently does **not** use a paid Apple Developer ID. Release builds are
ad-hoc signed, so macOS may block the first launch. If you trust the repository and the
published SHA-256 checksum matches your download, first try opening the app, then use:

**System Settings → Privacy & Security → Open Anyway**

See [`docs/GATEKEEPER.md`](docs/GATEKEEPER.md) for the exact first-launch steps and the
security trade-off.

## Build on a Mac

Developer requirements:

- macOS with Xcode Command Line Tools or Xcode
- Swift toolchain included with Xcode
- Go
- Git

Build a Universal DMG:

```bash
VERSION=1.0.0 BUILD_NUMBER=1 scripts/package.sh
```

Artifacts:

```text
dist/PrismArt.app
dist/PrismArt-1.0.0.dmg
dist/PrismArt-1.0.0.dmg.sha256
```

On an Apple Silicon Mac such as an M-series MacBook Air, the resulting app contains both
`arm64` and `x86_64` slices. The bundled Primitive engine is built the same way.

## Development

Run the platform-neutral tests:

```bash
swift test
```

Run the full local source checks:

```bash
make check
```

On macOS, package a local DMG:

```bash
make package
```

## Rendering model

PrismArt uses two render levels:

```text
Parameter change
      │
      └── Quick Preview
          ≤ 180 shapes
          ≤ 256 px analysis resolution
          ≤ 1536 px preview output

Generate Full Quality
      │
      └── Your selected settings
          up to 20,000 shapes in the UI
          up to 1024 px analysis resolution
          up to 8192 px output
```

The upstream engine uses `-j 0`, which means it uses all available CPU workers. The app
first creates a small, orientation-correct PNG working image so a very large HEIC/JPEG
does not have to be handed to Primitive at full camera resolution.

## Privacy and uninstall behavior

All rendering happens locally. PrismArt intentionally does not create an Application
Support database, preferences file, login item, launch agent or shell/PATH entry.
Render intermediates and pasted-image imports live below the macOS temporary directory
and are removed on normal lifecycle boundaries or the next launch after an abnormal exit.

To uninstall PrismArt, delete `PrismArt.app`. User-exported artwork is not removed.
macOS itself can retain system-managed metadata such as LaunchServices records,
quarantine history, recent items or crash diagnostics; those are not app-owned payloads.

## GitHub Releases without an Apple Developer account

Pushing a tag such as `v1.0.0` triggers `.github/workflows/release.yml`. GitHub Actions:

1. tests the Swift package;
2. builds the Swift GUI for arm64 and x86_64;
3. builds the Primitive engine for both architectures;
4. creates Universal binaries with `lipo`;
5. ad-hoc signs the app;
6. verifies the bundle and DMG;
7. generates a SHA-256 checksum;
8. publishes the DMG and checksum to GitHub Releases.

For an optional future Developer ID + notarization path, see [`docs/RELEASING.md`](docs/RELEASING.md).

## Architecture

```text
SwiftUI / AppKit UI
        │
        ├── AppViewModel
        │     ├── debounced Quick Preview
        │     ├── render replacement tokens
        │     └── save / copy / cancellation
        │
        ├── ImageTranscoder ── ImageIO downsample + orientation normalization
        ├── PrimitiveRunner ── direct Process launch, bounded log capture
        ├── GIFEncoder ─────── ImageIO, no ImageMagick
        │
        └── PrimitiveCore
              ├── RenderSettings
              ├── ArtPreset
              ├── ShapeMode
              └── PrimitiveCommandBuilder

Bundled engine: fogleman/primitive
```

More detail: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Upstream and license

PrismArt bundles the rendering engine from
[fogleman/primitive](https://github.com/fogleman/primitive), licensed under MIT.
PrismArt is not the upstream author's official Mac application. The exact upstream Git
revision used in each packaged build is recorded inside the app bundle.

PrismArt GUI: MIT. See [`LICENSE`](LICENSE) and [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Browser-only build (no local developer tools)

You can build PrismArt entirely on GitHub without installing Xcode, Go, Homebrew, or Git locally:

1. Create a GitHub repository and upload the contents of this project to the repository root, including the hidden `.github` directory.
2. Open **Actions → CI**. The first push automatically runs tests and produces an ad-hoc signed DMG as a workflow artifact.
3. For a permanent release, open **Actions → Release macOS + Windows → Run workflow**, enter a version such as `1.0.0`, and run it.
4. When the workflow is green, download the DMG or Windows ZIP from **Releases** (or from the workflow's **Artifacts** section).

The workflow uses GitHub-hosted macOS and Windows runners, builds both macOS and Windows packages, verifies their SHA-256 checksums, and publishes both assets.
