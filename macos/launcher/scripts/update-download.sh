#!/usr/bin/env bash
# Downloads, verifies, and extracts the new package, then replaces the JAR.
# Usage: update-download.sh <download_url> <download_dir> <app_dir> <expected_sha256>
set -u

DOWNLOAD_URL="$1"
DOWNLOAD_DIR="$2"
APP_DIR="$3"
EXPECTED_SHA="${4:-}"

ZIP_PATH="$DOWNLOAD_DIR/jig-update.zip"
EXTRACT_DIR="$DOWNLOAD_DIR/extracted"
JAR_NAME="jig-management-system.jar"
PLACEHOLDER="0000000000000000000000000000000000000000000000000000000000000000"

echo "    Downloading..."
if ! curl -sL -m 120 -o "$ZIP_PATH" "$DOWNLOAD_URL"; then
    echo "[ERROR] Download failed."
    exit 1
fi

if [ ! -f "$ZIP_PATH" ]; then
    echo "[ERROR] Downloaded file not found."
    exit 1
fi

if [ -n "$EXPECTED_SHA" ] && [ "$EXPECTED_SHA" != "$PLACEHOLDER" ]; then
    echo "    Verifying checksum..."
    ACTUAL_SHA="$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')"
    if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
        echo "[ERROR] Checksum mismatch."
        echo "        Expected : $EXPECTED_SHA"
        echo "        Actual   : $ACTUAL_SHA"
        echo "        The downloaded file may be corrupted or tampered."
        exit 1
    fi
    echo "    Checksum OK."
else
    echo "    (Checksum verification skipped — no hash provided)"
fi

echo "    Extracting..."
rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"
if ! unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"; then
    echo "[ERROR] Extraction failed."
    exit 1
fi

JAR_FILE="$(find "$EXTRACT_DIR" -name "$JAR_NAME" | head -n 1)"
if [ -z "$JAR_FILE" ]; then
    echo "[ERROR] $JAR_NAME not found inside the downloaded package."
    echo "        Contents of extracted ZIP:"
    find "$EXTRACT_DIR" -type f
    exit 1
fi

TARGET_JAR="$APP_DIR/$JAR_NAME"
echo "    Replacing: $TARGET_JAR"
if ! cp "$JAR_FILE" "$TARGET_JAR"; then
    echo "[ERROR] Failed to replace JAR."
    echo "        Source : $JAR_FILE"
    echo "        Target : $TARGET_JAR"
    exit 1
fi

rm -f "$ZIP_PATH"
rm -rf "$EXTRACT_DIR"

echo "    Done."
exit 0
