# Changelog

All notable PrismArt changes are documented here.

## [1.0.1] - 2026-09-28

### Fixed
- Fixed Swift 6 continuation type inference in the macOS Primitive process runner.
- Tightened process cancellation and output synchronization for modern Swift concurrency.
- Silenced drag-and-drop API unused-return warnings.
- Made released SHA-256 files portable by storing the DMG basename instead of a CI absolute path.

### Added
- Added one-click GitHub publisher bundle for zero-install local setup.
- Added browser-based GitHub authentication and automated repository creation/upload.
- Added automatic Release DMG workflow dispatch and DMG download.

## [1.0.0] - 2026-09-28

### Added
- Native SwiftUI/AppKit macOS application around the fogleman/primitive engine.
- Six artist-friendly presets plus full access to all nine upstream shape modes.
- Debounced Quick Preview renders for responsive parameter exploration.
- Full-quality PNG, JPEG, SVG and animated GIF export.
- Native ImageIO GIF encoding; ImageMagick is not required.
- HEIC/TIFF/high-resolution image normalization with orientation-aware downsampling.
- Drag/drop, file picker and clipboard image input.
- Original/artwork comparison, progress, cancellation and clipboard copy.
- Universal Apple Silicon + Intel application and rendering engine.
- Explicit all-core Primitive worker policy (`-j 0`) for Apple Silicon and Intel.
- Ad-hoc code signing by default, allowing GitHub releases without a paid Apple Developer account.
- SHA-256 checksums for DMG artifacts.
- GitHub Actions CI and tag-triggered GitHub Releases on current macOS runners.
- Stateless temporary-workspace design for clean uninstallation.

### Hardened
- Render replacement tokens prevent stale previews from overwriting newer results.
- Large input images are downsampled before the Go engine to reduce peak memory use.
- Engine logs are bounded in memory.
- Shell-free process invocation keeps filenames with spaces/metacharacters safe.
