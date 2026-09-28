# Contributing

1. Fork the repository and create a focused branch.
2. Run `make check` before submitting a pull request.
3. On macOS, run `VERSION=0.0.0-local scripts/package.sh` for packaging changes.
4. Keep PrismArt stateless: do not add persistent files under `~/Library` without a
   strong product reason and an explicit cleanup/migration plan.
5. Preserve Primitive's upstream attribution and license notice.
6. Do not add network calls to image-processing paths without explicit UI and privacy documentation.

Pull requests should explain user-visible changes and include tests for platform-neutral
settings, command construction, validation or preset logic where appropriate.
