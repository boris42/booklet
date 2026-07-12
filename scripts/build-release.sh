#!/bin/bash
set -euo pipefail

export COPYFILE_DISABLE=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKDIR="${WORKDIR:-$ROOT/build/release}"
OUTDIR="${OUTDIR:-$ROOT/dist}"
ARCHS="${BOOKLET_ARCHS:-arm64 x86_64}"
UNSIGNED="${UNSIGNED:-0}"
KEEP_WORKDIR="${KEEP_WORKDIR:-0}"

case "$UNSIGNED" in
    0|1) ;;
    *) echo "ERROR: UNSIGNED must be 0 or 1." >&2; exit 1 ;;
esac

case "$KEEP_WORKDIR" in
    0|1) ;;
    *) echo "ERROR: KEEP_WORKDIR must be 0 or 1." >&2; exit 1 ;;
esac

if [ "$UNSIGNED" = "0" ]; then
    : "${APP_CERT:?Set APP_CERT to a Developer ID Application certificate name}"
    : "${INSTALLER_CERT:?Set INSTALLER_CERT to a Developer ID Installer certificate name}"
    : "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile}"
fi

case "$WORKDIR" in
    ""|"/")
        echo "ERROR: Unsafe WORKDIR: '$WORKDIR'" >&2
        exit 1
        ;;
esac

case "$OUTDIR" in
    ""|"/")
        echo "ERROR: Unsafe OUTDIR: '$OUTDIR'" >&2
        exit 1
        ;;
esac

for command in codesign ditto hdiutil pkgbuild pkgutil productbuild spctl xcodebuild xcrun; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $command" >&2
        exit 1
    fi
done

QUICKACTION_SRC="$ROOT/workflows/quick-action/Create Booklet.workflow"
PDFSERVICE_SRC="$ROOT/workflows/pdf-service/Create Booklet.workflow"
INSTALLER_DIR="$ROOT/installer"
BACKGROUND_SRC="$INSTALLER_DIR/background.png"
README_SRC="$INSTALLER_DIR/ReadMe.rtf"
LICENSE_SRC="$INSTALLER_DIR/License.rtf"

BINARY_BUILD_DIR="$WORKDIR/binary-build"
BINARY_SRC="$BINARY_BUILD_DIR/booklet"
PKGROOT="$WORKDIR/pkgroot"
RESOURCES_DIR="$WORKDIR/resources"
DMGROOT="$WORKDIR/dmgroot"
EXPANDED_DIR="$WORKDIR/expanded"
VERIFY_DIR="$WORKDIR/verify-zip"

PKG_COMPONENT="$WORKDIR/CreateBooklet-component.pkg"
DISTRIBUTION_XML="$WORKDIR/CreateBooklet.distribution.xml"
PKG_SIGNED="$OUTDIR/CreateBooklet.pkg"
DMG_FINAL="$OUTDIR/CreateBooklet.dmg"
ZIP_FINAL="$OUTDIR/CreateBooklet.zip"
CHECKSUMS_FINAL="$OUTDIR/SHA256SUMS"

clean_intermediates() {
    rm -rf \
        "$BINARY_BUILD_DIR" \
        "$PKGROOT" \
        "$RESOURCES_DIR" \
        "$DMGROOT" \
        "$EXPANDED_DIR" \
        "$VERIFY_DIR"
    rm -f "$PKG_COMPONENT" "$DISTRIBUTION_XML"
}

VOLUME_NAME="Create Booklet Installer"
IDENTIFIER="si.sightandsound.createbooklet"
TITLE="Create Booklet"

SUPPORT_INSTALL_DIR="/Library/Application Support/Create Booklet"
SUPPORT_BIN_INSTALL_PATH="$SUPPORT_INSTALL_DIR/booklet"
QUICKACTION_INSTALL_PATH="/Library/Services/Create Booklet.workflow"
PDFSERVICE_INSTALL_PATH="/Library/PDF Services/Create Booklet.workflow"

SUPPORT_BIN_DST="$PKGROOT$SUPPORT_BIN_INSTALL_PATH"
QUICKACTION_DST="$PKGROOT$QUICKACTION_INSTALL_PATH"
PDFSERVICE_DST="$PKGROOT$PDFSERVICE_INSTALL_PATH"
QUICKACTION_WFLOW="$QUICKACTION_DST/Contents/document.wflow"
PDFSERVICE_WFLOW="$PDFSERVICE_DST/Contents/document.wflow"

echo "Checking source inputs..."
test -d "$QUICKACTION_SRC"
test -d "$PDFSERVICE_SRC"
test -f "$BACKGROUND_SRC"
test -f "$README_SRC"
test -f "$LICENSE_SRC"

echo "Cleaning generated installer products..."
mkdir -p "$WORKDIR" "$OUTDIR"
clean_intermediates
rm -f "$PKG_SIGNED" "$DMG_FINAL" "$ZIP_FINAL" "$CHECKSUMS_FINAL"

echo "Building the helper from the checked-out Swift source..."
BUILD_DIR="$BINARY_BUILD_DIR" BOOKLET_ARCHS="$ARCHS" "$ROOT/scripts/build-local.sh"
test -x "$BINARY_SRC"

VERSION="$("$BINARY_SRC" --version | awk 'NF == 2 && $1 == "booklet" { print $2 }')"
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "ERROR: Could not determine a semantic version from the built helper." >&2
    exit 1
fi
echo "Packaging booklet $VERSION"

echo "Creating the package root..."
mkdir -p "$PKGROOT$SUPPORT_INSTALL_DIR" "$PKGROOT/Library/Services" "$PKGROOT/Library/PDF Services"
ditto --norsrc --noextattr "$BINARY_SRC" "$SUPPORT_BIN_DST"
ditto --norsrc --noextattr "$QUICKACTION_SRC" "$QUICKACTION_DST"
ditto --norsrc --noextattr "$PDFSERVICE_SRC" "$PDFSERVICE_DST"

rm -f "$QUICKACTION_DST/Contents/Resources/booklet"
rm -f "$PDFSERVICE_DST/Contents/Resources/booklet"

test -f "$SUPPORT_BIN_DST"
test -f "$QUICKACTION_WFLOW"
test -f "$PDFSERVICE_WFLOW"

if ! grep -qF "$SUPPORT_BIN_INSTALL_PATH" "$QUICKACTION_WFLOW"; then
    echo "ERROR: Quick Action does not reference $SUPPORT_BIN_INSTALL_PATH" >&2
    exit 1
fi
if ! grep -qF "$SUPPORT_BIN_INSTALL_PATH" "$PDFSERVICE_WFLOW"; then
    echo "ERROR: PDF Service does not reference $SUPPORT_BIN_INSTALL_PATH" >&2
    exit 1
fi

find "$PKGROOT" \( -name '._*' -o -name '.DS_Store' \) -print -delete
xattr -cr "$PKGROOT"
chmod 755 "$SUPPORT_BIN_DST"

if [ "$UNSIGNED" = "0" ]; then
    echo "Signing and verifying the helper..."
    codesign --force --timestamp --options runtime --sign "$APP_CERT" "$SUPPORT_BIN_DST"
    codesign --verify --strict --verbose=4 "$SUPPORT_BIN_DST"

    echo "Signing and verifying the workflow documents and bundles..."
    codesign --force --timestamp --sign "$APP_CERT" "$QUICKACTION_WFLOW"
    codesign --verify --strict --verbose=4 "$QUICKACTION_WFLOW"
    codesign --force --timestamp --sign "$APP_CERT" "$QUICKACTION_DST"
    codesign --verify --strict --verbose=4 "$QUICKACTION_DST"

    codesign --force --timestamp --sign "$APP_CERT" "$PDFSERVICE_WFLOW"
    codesign --verify --strict --verbose=4 "$PDFSERVICE_WFLOW"
    codesign --force --timestamp --sign "$APP_CERT" "$PDFSERVICE_DST"
    codesign --verify --strict --verbose=4 "$PDFSERVICE_DST"
else
    echo "Leaving the helper and workflows unsigned for local auditing."
fi

echo "Building the component package..."
pkgbuild \
    --root "$PKGROOT" \
    --install-location / \
    --identifier "$IDENTIFIER" \
    --version "$VERSION" \
    --ownership recommended \
    "$PKG_COMPONENT"

echo "Preparing installer resources..."
mkdir -p "$RESOURCES_DIR"
ditto --norsrc --noextattr "$BACKGROUND_SRC" "$RESOURCES_DIR/background.png"
ditto --norsrc --noextattr "$README_SRC" "$RESOURCES_DIR/ReadMe.rtf"
ditto --norsrc --noextattr "$LICENSE_SRC" "$RESOURCES_DIR/License.rtf"

productbuild --synthesize --package "$PKG_COMPONENT" "$DISTRIBUTION_XML"
perl -0pi -e "s#(<installer-gui-script[^>]*>)#\$1\n    <title>$TITLE</title>\n    <background file=\"background.png\" mime-type=\"image/png\" alignment=\"center\" scaling=\"proportional\"/>\n    <readme file=\"ReadMe.rtf\"/>\n    <license file=\"License.rtf\"/>#" "$DISTRIBUTION_XML"

echo "Building the product archive..."
PRODUCTBUILD_ARGS=(
    --distribution "$DISTRIBUTION_XML"
    --resources "$RESOURCES_DIR"
    --package-path "$WORKDIR"
)
if [ "$UNSIGNED" = "0" ]; then
    PRODUCTBUILD_ARGS+=(--sign "$INSTALLER_CERT")
fi
productbuild "${PRODUCTBUILD_ARGS[@]}" "$PKG_SIGNED"

pkgutil --expand-full "$PKG_SIGNED" "$EXPANDED_DIR"
test -f "$EXPANDED_DIR/Distribution"

UNWANTED_PAYLOAD_FILE="$(
    find "$EXPANDED_DIR" -path '*/Payload/*' \
        \( -name '.DS_Store' -o -name '._*' \) \
        -print -quit
)"
if [ -n "$UNWANTED_PAYLOAD_FILE" ]; then
    echo "ERROR: Unwanted metadata file found in the decoded package payload:" >&2
    echo "  $UNWANTED_PAYLOAD_FILE" >&2
    exit 1
fi

rm -rf "$EXPANDED_DIR"
if [ "$UNSIGNED" = "0" ]; then
    pkgutil --check-signature "$PKG_SIGNED"

    echo "Notarizing and stapling the package..."
    xcrun notarytool submit "$PKG_SIGNED" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PKG_SIGNED"
    xcrun stapler validate "$PKG_SIGNED"
    spctl --assess --type install --verbose=4 "$PKG_SIGNED"
else
    echo "Skipping package signing and notarization."
fi

echo "Creating the disk image..."
mkdir -p "$DMGROOT"
ditto --norsrc --noextattr "$PKG_SIGNED" "$DMGROOT/CreateBooklet.pkg"
find "$DMGROOT" \( -name '._*' -o -name '.DS_Store' \) -print -delete
xattr -cr "$DMGROOT"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$DMGROOT" \
    -ov \
    -format UDZO \
    "$DMG_FINAL"

if [ "$UNSIGNED" = "0" ]; then
    codesign --force --timestamp --sign "$APP_CERT" "$DMG_FINAL"
    codesign --verify --strict --verbose=4 "$DMG_FINAL"
    xcrun notarytool submit "$DMG_FINAL" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$DMG_FINAL"
    xcrun stapler validate "$DMG_FINAL"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_FINAL"
else
    echo "Skipping disk image signing and notarization."
fi

echo "Creating the ZIP archive..."
ditto -c -k --norsrc --noextattr "$DMG_FINAL" "$ZIP_FINAL"

echo "Re-extracting and validating the final ZIP payload..."
mkdir -p "$VERIFY_DIR"
ditto -x -k "$ZIP_FINAL" "$VERIFY_DIR"
EXTRACTED_DMG="$VERIFY_DIR/CreateBooklet.dmg"
test -f "$EXTRACTED_DMG"
cmp -s "$DMG_FINAL" "$EXTRACTED_DMG"
hdiutil verify "$EXTRACTED_DMG"
if [ "$UNSIGNED" = "0" ]; then
    codesign --verify --strict --verbose=4 "$EXTRACTED_DMG"
    xcrun stapler validate "$EXTRACTED_DMG"
    spctl --assess --type open --context context:primary-signature --verbose=4 "$EXTRACTED_DMG"
fi

(
    cd "$OUTDIR"
    shasum -a 256 \
        "$(basename "$PKG_SIGNED")" \
        "$(basename "$DMG_FINAL")" \
        "$(basename "$ZIP_FINAL")"
) > "$CHECKSUMS_FINAL"

if [ "$KEEP_WORKDIR" = "0" ]; then
    echo "Cleaning intermediate build files..."
    clean_intermediates
    rmdir "$WORKDIR" 2>/dev/null || true
else
    echo "Keeping intermediate build files in: $WORKDIR"
fi

echo
if [ "$UNSIGNED" = "0" ]; then
    echo "Signed release complete:"
else
    echo "Unsigned local installer complete:"
fi
echo "  $PKG_SIGNED"
echo "  $DMG_FINAL"
echo "  $ZIP_FINAL"
echo "  $CHECKSUMS_FINAL"
