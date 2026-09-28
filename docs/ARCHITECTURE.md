# Architecture

## Product goals

1. Native macOS experience with no installer-time runtime dependencies.
2. Fast parameter exploration without pretending the upstream algorithm is instantaneous.
3. Upstream Primitive remains an isolated and replaceable rendering engine.
4. No persistent app-owned state under `~/Library` in the 1.0 release.
5. Export GIF without requiring ImageMagick.
6. Direct GitHub distribution that works without a paid Apple Developer account, while
   documenting Gatekeeper limitations honestly.

## Components

### PrimitiveCore

Platform-neutral Swift code containing:

- `RenderSettings` and validation;
- low-cost Quick Preview derivation;
- `ArtPreset` definitions and preset matching;
- `ShapeMode` and `OutputFormat`;
- shell-free CLI argument construction.

This target is unit-tested on Linux and macOS.

### AppViewModel

Main-actor state coordinator. It owns the current input, preview/final output, settings,
render progress and temporary workspace lifecycle.

Two mechanisms prevent stale output races:

- every render receives a replacement token;
- starting a newer render cancels the previous `Task` and its `Process`.

A result may update UI state only while its token is still current.

### Quick Preview

Settings changes are debounced before preview work begins. Preview settings preserve
shape type and alpha but cap expensive parameters:

- at most 72 shapes;
- 128 px analysis size;
- at most 1024 px output;
- PNG only.

Full-quality output is never replaced by a preview after a newer render has started.

### ImageTranscoder

Uses ImageIO directly rather than `NSImage.tiffRepresentation` for the engine input.
This lets PrismArt:

- honor image orientation metadata;
- decode HEIC/TIFF/etc. supported by macOS;
- downsample large camera originals before the Go engine sees them;
- reduce peak memory and startup latency.

### PrimitiveRunner

Launches the bundled engine with `Process(executableURL:arguments:)`; it never invokes a
shell. This prevents filenames containing spaces or shell metacharacters from becoming
commands. Engine output is streamed for progress and only a bounded log tail is retained
for diagnostics.

### GIFEncoder

Creates animated GIFs with ImageIO from Primitive's PNG frame output. No ImageMagick is
bundled or installed.

### TemporaryWorkspace

All application-created intermediate files live below the system temporary directory:

```text
.../PrismArt/
├── Imports/
└── Renders/
```

Stale data is removed at startup. The active render workspace is replaced when a newer
render starts and removed on normal app termination.

## Performance policy

Primitive's upstream `-j 0` behavior uses all available workers; PrismArt passes this
explicitly. That already scales well across Apple Silicon CPU cores. The UI does not
claim GPU acceleration for the upstream hill-climbing algorithm because the bundled
engine is CPU based.

The largest practical 1.0 speed win comes from avoiding oversized source decoding and
using a deliberately cheap preview render before the user commits to a final render.

## Security boundaries

- no administrator privileges;
- no shell command interpolation;
- no network calls in the image path;
- no persistent database or preference store;
- no login item or background agent;
- no updater that executes downloaded code.
