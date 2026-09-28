# Security policy

Please do not open a public issue for a vulnerability that could put users at risk.
Use GitHub's private vulnerability reporting feature when enabled for the repository.

PrismArt processes images locally. It does not upload images, install privileged helpers,
launch agents, browser extensions, kernel/system extensions or login items. The bundled
Primitive engine is launched directly with `Process` and an argument array; user paths
are never interpolated into a shell command.

GitHub release artifacts include a SHA-256 checksum. Because the project currently has
no paid Apple Developer ID, public releases are ad-hoc signed rather than notarized;
see `docs/GATEKEEPER.md` for the security implications and first-launch steps.
