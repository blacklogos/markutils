#!/bin/bash
# Builds Clip.app (Sparkle + bundled clip CLI) and its DMG through the shared release path
# (tools/release-mac.sh). Dry run by default: build, bundle, sign with the best local identity,
# DMG. Notarization only via `tools/release-mac.sh apps/clip <version> --apply` on the Pro.
# Piece settings: release.env; extra Info.plist keys: packaging/info-extra.plist.
# Usage: scripts/build_dmg.sh [version]   (default 1.6.0, the last released version)
set -euo pipefail
cd "$(dirname "$0")/.."

../../tools/release-mac.sh . "${1:-1.6.0}"
