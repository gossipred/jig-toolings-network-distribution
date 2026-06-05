#!/usr/bin/env bash
# Build the Windows customer release ZIP for Jig & Toolings Network App.
# Run this script on Mac after finalising source code changes.
#
# Usage:
#   bash windows/installer/release-windows.sh
#   bash windows/installer/release-windows.sh /path/to/core-repo
#
# Output:
#   windows/installer/dist/jig-toolings-network-windows-<VERSION>.zip
#   shared/latest.json               ← windows sha256 + packageUrl updated
#   releases/<VERSION>/manifest.json ← same update

set -euo pipefail

DIST_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CORE_REPO="${1:-/Users/gossipredm4/Documents/Codex/jig-and-toolings-management-system}"
PACKAGE_DIR="$CORE_REPO/customer-package/windows-network-app"
MYSQL_PACKAGE_DIR="$CORE_REPO/customer-package/mysql-windows"
LAUNCHER_DIR="$DIST_REPO/windows/launcher"

# ── Read version ─────────────────────────────────────────────────────────────
PROPS="$PACKAGE_DIR/app/application.properties"
if [ ! -f "$PROPS" ]; then
    echo "[ERROR] application.properties not found: $PROPS"
    exit 1
fi
VERSION=$(grep -E '^app\.version=' "$PROPS" | cut -d= -f2 | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
    echo "[ERROR] app.version not found in $PROPS"
    exit 1
fi

ZIP_NAME="jig-toolings-network-windows-${VERSION}.zip"
DIST_DIR="$DIST_REPO/windows/installer/dist"
OUTPUT="$DIST_DIR/$ZIP_NAME"
PACKAGE_URL="https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v${VERSION}/${ZIP_NAME}"

echo "============================================================"
echo " Jig & Toolings Network — Windows Release Builder"
echo " Core repo  : $CORE_REPO"
echo " Version    : $VERSION"
echo " Output     : $OUTPUT"
echo "============================================================"
echo ""

# ── Step 0: Stop running Spring Boot to avoid JVM classloader corruption ─────
echo "[0/5] Stopping Spring Boot (if running)..."
SPRING_PID=$(lsof -t -iTCP:8080 2>/dev/null || true)
if [ -n "$SPRING_PID" ]; then
    kill "$SPRING_PID" 2>/dev/null || true
    sleep 3
    echo "[0/5] Spring Boot stopped (PID $SPRING_PID)."
else
    echo "[0/5] Spring Boot not running, skipping."
fi

# ── Step 1: Maven build ───────────────────────────────────────────────────────
echo "[1/5] Building JAR with Maven..."
cd "$CORE_REPO"
/opt/homebrew/bin/mvn -Dmaven.repo.local=.m2/repository package -q
echo "[1/5] Maven build OK."
echo ""

# ── Step 2: Assemble package directory ───────────────────────────────────────
echo "[2/5] Assembling package directory..."
bash "$PACKAGE_DIR/scripts/build-windows-network-app-package.sh"
echo "[2/5] Assembly OK."
echo ""

# ── Step 3: Sync launcher scripts from distribution repo ─────────────────────
echo "[3/5] Syncing launcher scripts from distribution repo..."
cp "$LAUNCHER_DIR/START-JIG-NETWORK-APP.bat" "$PACKAGE_DIR/START-JIG-NETWORK-APP.bat"
for f in "$LAUNCHER_DIR/scripts/"*.bat "$LAUNCHER_DIR/scripts/"*.ps1; do
    [ -f "$f" ] && cp "$f" "$PACKAGE_DIR/scripts/"
done
echo "[3/5] Launcher sync OK."
echo ""

# ── Step 3.5: Copy XAMPP installer and Java runtime ──────────────────────────
echo "[3.5] Copying XAMPP-installer.exe and runtime/ from mysql-windows..."

XAMPP_SRC="$MYSQL_PACKAGE_DIR/XAMPP-installer.exe"
RUNTIME_SRC="$MYSQL_PACKAGE_DIR/runtime"

if [ -f "$XAMPP_SRC" ]; then
    cp "$XAMPP_SRC" "$PACKAGE_DIR/XAMPP-installer.exe"
    echo "      XAMPP-installer.exe copied ($(du -sh "$XAMPP_SRC" | cut -f1))"
else
    echo "      [WARN] XAMPP-installer.exe not found at $XAMPP_SRC — skipped"
fi

if [ -d "$RUNTIME_SRC" ]; then
    rm -rf "$PACKAGE_DIR/runtime"
    cp -R "$RUNTIME_SRC" "$PACKAGE_DIR/runtime"
    echo "      runtime/ copied ($(du -sh "$RUNTIME_SRC" | cut -f1))"
else
    echo "      [WARN] runtime/ not found at $RUNTIME_SRC — skipped"
fi
echo ""

# ── Step 4: Create ZIP ────────────────────────────────────────────────────────
echo "[4/5] Creating ZIP: $ZIP_NAME"
mkdir -p "$DIST_DIR"
rm -f "$OUTPUT"
cd "$PACKAGE_DIR"
zip -r "$OUTPUT" . \
    --exclude "*/.DS_Store" \
    --exclude ".DS_Store" \
    --exclude "*.sh" \
    --exclude ".gitignore" \
    --exclude "backups/*" \
    --exclude "logs/*" \
    --exclude "license/*.lic" \
    --exclude "*/build-*.sh" \
    --exclude "app/jig-toolings-management.jar"

SHA256=$(shasum -a 256 "$OUTPUT" | awk '{print $1}')
ZIP_SIZE=$(du -sh "$OUTPUT" | cut -f1)
echo "[4/5] ZIP created: $ZIP_SIZE"
echo ""

# ── Step 4b: Build NSIS installer EXE ────────────────────────────────────────
EXE_NAME="JigToolingsSetup-${VERSION}.exe"
EXE_OUTPUT="$DIST_DIR/$EXE_NAME"
EXE_URL="https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v${VERSION}/${EXE_NAME}"
EXE_SHA256=""

if ! command -v makensis &>/dev/null; then
    echo "[4b] WARN: makensis not found — skipping EXE build."
    echo "           Install with: brew install makensis"
else
    echo "[4b] Building installer EXE with NSIS..."
    find "$PACKAGE_DIR" -name ".DS_Store" -delete 2>/dev/null || true
    makensis \
        -DVERSION="$VERSION" \
        -DPACKAGE_DIR="$PACKAGE_DIR" \
        -DOUTFILE="$EXE_OUTPUT" \
        "$DIST_REPO/windows/installer/jig-setup.nsi"
    if [ ! -s "$EXE_OUTPUT" ]; then
        echo "[ERROR] EXE output is empty or missing: $EXE_OUTPUT"
        exit 1
    fi
    EXE_SHA256=$(shasum -a 256 "$EXE_OUTPUT" | awk '{print $1}')
    EXE_SIZE=$(du -sh "$EXE_OUTPUT" | cut -f1)
    echo "[4b] EXE created: $EXE_SIZE"
    echo ""
fi

# ── Step 5: Update manifests ──────────────────────────────────────────────────
echo "[5/5] Updating shared/latest.json and releases/${VERSION}/manifest.json..."

# Ensure releases/VERSION folder exists
RELEASE_DIR="$DIST_REPO/releases/$VERSION"
mkdir -p "$RELEASE_DIR"

# If release manifest doesn't exist yet, copy from shared/latest.json
if [ ! -f "$RELEASE_DIR/manifest.json" ]; then
    cp "$DIST_REPO/shared/latest.json" "$RELEASE_DIR/manifest.json"
fi

python3 - <<PYEOF
import json, os

sha256      = "$SHA256"
package_url = "$PACKAGE_URL"
version     = "$VERSION"
exe_sha256  = "$EXE_SHA256"
exe_url     = "$EXE_URL"

paths = [
    "$DIST_REPO/shared/latest.json",
    "$RELEASE_DIR/manifest.json",
]

for path in paths:
    with open(path) as f:
        d = json.load(f)
    d["latestVersion"] = version
    d["platforms"]["windows"]["packageUrl"] = package_url
    d["platforms"]["windows"]["sha256"] = sha256
    if exe_sha256:
        d["platforms"]["windows"]["installerUrl"]    = exe_url
        d["platforms"]["windows"]["installerSha256"] = exe_sha256
    with open(path, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"  Updated: {path}")

checksums_path = "$RELEASE_DIR/checksums.txt"
lines = []
if os.path.exists(checksums_path):
    with open(checksums_path) as f:
        for line in f:
            if "windows" not in line and "JigToolings" not in line:
                lines.append(line.rstrip())
lines.append(f"{sha256}  $ZIP_NAME")
if exe_sha256:
    lines.append(f"{exe_sha256}  $EXE_NAME")
with open(checksums_path, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"  Updated: {checksums_path}")
PYEOF

echo "[5/5] Manifests updated."
echo ""

# ── Step 5b: Upload EXE to GitHub Release ────────────────────────────────────
if [ -n "$EXE_SHA256" ] && [ -f "$EXE_OUTPUT" ]; then
    echo "[5b] Uploading EXE to GitHub Release v${VERSION}..."
    gh release upload "v${VERSION}" "$EXE_OUTPUT" \
        --repo gossipred/jig-toolings-network-distribution \
        --clobber
    echo "[5b] EXE uploaded."
    echo ""
fi

echo "============================================================"
echo " Release complete!"
echo ""
echo " ZIP     : $OUTPUT"
echo " Size    : $ZIP_SIZE"
echo " SHA256  : $SHA256"
if [ -n "$EXE_SHA256" ]; then
echo ""
echo " EXE     : $EXE_OUTPUT"
echo " EXE SHA : $EXE_SHA256"
fi
echo ""
echo " Next steps:"
echo "   1. Test the ZIP on a Windows machine."
echo "   2. cd $DIST_REPO"
echo "   3. git add shared/latest.json releases/$VERSION/"
echo "   4. git commit -m \"Release v${VERSION} — Windows package\""
echo "   5. git push origin main"
echo "   6. Create GitHub Release v${VERSION} and upload:"
echo "      $ZIP_NAME"
echo "============================================================"
