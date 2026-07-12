#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build/local}"
BINARY="$BUILD_DIR/booklet"

SUPPORT_DIR="/Library/Application Support/Create Booklet"
QUICKACTION_DEST="/Library/Services/Create Booklet.workflow"
PDFSERVICE_DEST="/Library/PDF Services/Create Booklet.workflow"

QUICKACTION_SRC="$ROOT/workflows/quick-action/Create Booklet.workflow"
PDFSERVICE_SRC="$ROOT/workflows/pdf-service/Create Booklet.workflow"

BUILD_DIR="$BUILD_DIR" "$ROOT/scripts/build-local.sh"

test -x "$BINARY"
test -d "$QUICKACTION_SRC"
test -d "$PDFSERVICE_SRC"

echo
echo "This installs the locally built, unsigned files at:"
echo "  $SUPPORT_DIR/booklet"
echo "  $QUICKACTION_DEST"
echo "  $PDFSERVICE_DEST"
echo "Administrator access is required."

sudo mkdir -p "$SUPPORT_DIR" "/Library/Services" "/Library/PDF Services"
sudo rm -rf "$QUICKACTION_DEST" "$PDFSERVICE_DEST"
sudo ditto --norsrc --noextattr "$BINARY" "$SUPPORT_DIR/booklet"
sudo ditto --norsrc --noextattr "$QUICKACTION_SRC" "$QUICKACTION_DEST"
sudo ditto --norsrc --noextattr "$PDFSERVICE_SRC" "$PDFSERVICE_DEST"
sudo chmod 755 "$SUPPORT_DIR/booklet"
sudo xattr -cr "$SUPPORT_DIR/booklet" "$QUICKACTION_DEST" "$PDFSERVICE_DEST"

echo
echo "Installed Create Booklet."
echo "If the services do not appear immediately, log out and back in."

