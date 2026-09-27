#!/usr/bin/env bash
# Downloads and verifies the new release, then hands over to apply-update.sh
# from the NEW package, so each release brings its own install logic.
# Usage: update-download.sh <url> <download_dir> <package_dir> <backup_dir> [sha256]
# Exit codes: 0 = done, 1 = failed before anything changed, 2 = failed part-way.
# Wrapped in main(): apply-update.sh replaces this file while it runs.

main() {
set -u
DOWNLOAD_URL="$1"
DOWNLOAD_DIR="$2"
PACKAGE_DIR="$3"
BACKUP_DIR="$4"
EXPECTED_SHA="${5:-}"

ZIP_PATH="$DOWNLOAD_DIR/jig-update.zip"
EXTRACT_DIR="$DOWNLOAD_DIR/extracted"
PLACEHOLDER="0000000000000000000000000000000000000000000000000000000000000000"

echo "    Downloading..."
if ! curl -sfL -m 1200 -o "$ZIP_PATH" "$DOWNLOAD_URL" || [ ! -s "$ZIP_PATH" ]; then
    echo "[ERROR] Download failed."
    return 1
fi

if [ -n "$EXPECTED_SHA" ] && [ "$EXPECTED_SHA" != "$PLACEHOLDER" ]; then
    echo "    Verifying checksum..."
    ACTUAL_SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
    if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
        echo "[ERROR] Checksum mismatch. The download may be corrupted."
        echo "        Expected : $EXPECTED_SHA"
        echo "        Actual   : $ACTUAL_SHA"
        return 1
    fi
    echo "    Checksum OK."
fi

echo "    Extracting..."
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
if ! unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"; then
    echo "[ERROR] Extraction failed."
    return 1
fi

if [ ! -f "$EXTRACT_DIR/scripts/apply-update.sh" ]; then
    echo "[ERROR] The downloaded package has no scripts/apply-update.sh."
    return 1
fi

bash "$EXTRACT_DIR/scripts/apply-update.sh" "$EXTRACT_DIR" "$PACKAGE_DIR" "$BACKUP_DIR"
local code=$?
rm -f "$ZIP_PATH"
rm -rf "$EXTRACT_DIR"
return $code
}

main "$@"; exit $?
