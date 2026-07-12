#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="${BUILD_DIR:-$ROOT/build/local}"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
OUTPUT="$BUILD_DIR/booklet"
ARCHS="${BOOKLET_ARCHS:-arm64 x86_64}"

for command in xcodebuild ditto lipo; do
    if ! command -v "$command" >/dev/null 2>&1; then
        echo "ERROR: Required command not found: $command" >&2
        echo "Install Xcode and select it with xcode-select before building." >&2
        exit 1
    fi
done

mkdir -p "$BUILD_DIR"
rm -rf "$DERIVED_DATA_DIR"
rm -f "$OUTPUT"

echo "Building booklet for: $ARCHS"
xcodebuild \
    -project "$ROOT/booklet.xcodeproj" \
    -scheme booklet \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    ONLY_ACTIVE_ARCH=NO \
    ARCHS="$ARCHS" \
    build

PRODUCT="$DERIVED_DATA_DIR/Build/Products/Release/booklet"
if [ ! -x "$PRODUCT" ]; then
    echo "ERROR: Xcode did not create the expected executable: $PRODUCT" >&2
    exit 1
fi

ditto --norsrc --noextattr "$PRODUCT" "$OUTPUT"
chmod 755 "$OUTPUT"

echo
echo "Built: $OUTPUT"
"$OUTPUT" --version
lipo -info "$OUTPUT"

