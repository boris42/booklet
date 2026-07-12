#!/bin/bash
set -euo pipefail

SUPPORT_DIR="/Library/Application Support/Create Booklet"
QUICKACTION_DEST="/Library/Services/Create Booklet.workflow"
PDFSERVICE_DEST="/Library/PDF Services/Create Booklet.workflow"

if [ "${1:-}" != "--yes" ]; then
    echo "This removes:"
    echo "  $SUPPORT_DIR"
    echo "  $QUICKACTION_DEST"
    echo "  $PDFSERVICE_DEST"
    read -r -p "Continue? [y/N] " answer
    case "$answer" in
        y|Y|yes|YES) ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
fi

sudo rm -rf "$SUPPORT_DIR" "$QUICKACTION_DEST" "$PDFSERVICE_DEST"

echo "Create Booklet was removed."
echo "If the services remain visible, log out and back in."

