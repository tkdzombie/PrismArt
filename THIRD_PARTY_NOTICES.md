# Third-party notices

## Primitive

PrismArt bundles the command-line rendering engine from **fogleman/primitive**:
https://github.com/fogleman/primitive

Primitive is MIT-licensed. Copyright © Michael Fogleman and contributors.
The upstream license is available at:
https://github.com/fogleman/primitive/blob/master/LICENSE.md

The release build fetches the upstream source, records the exact Git commit in the app
bundle, and compiles a Universal macOS binary. PrismArt's Swift GUI is a separate work
and keeps the upstream attribution both here and inside the distributed app.

## Apple system frameworks

PrismArt uses AppKit, SwiftUI, Foundation, ImageIO and UniformTypeIdentifiers provided
by macOS. GIF assembly uses ImageIO, so end users do **not** need ImageMagick.
