#!/usr/bin/env bash
# Build the macOS customer release ZIP for Jig & Toolings Network App.
# Run this script on Mac after finalising source code changes.
#
# Usage:
#   bash macos/installer/release-macos.sh
#   bash macos/installer/release-macos.sh /path/to/core-repo
#
# Output:
#   macos/installer/dist/jig-toolings-network-macos-<VERSION>.zip
#   shared/latest.json                     ← macos sha256 + packageUrl updated
#   releases/<VERSION>/manifest.json       ← same update
#
# Prerequisites: the bundled runtime/ (jlink custom JRE) must already exist
# in $CORE_REPO/customer-package/mac-network-app/runtime/ — this script does
# NOT build it. See docs/superpowers/specs/2026-09-18-mac-network-app-and-updater-design.md
# for the jlink command.

set -euo pipefail

DIST_REPO="$(cd "$(dirname "$0")/../.." && pwd)"
CORE_REPO="${1:-/Users/gossipredm4/Documents/Codex/jig-and-toolings-management-system}"
PACKAGE_DIR="$CORE_REPO/customer-package/mac-network-app"
LAUNCHER_DIR="$DIST_REPO/macos/launcher"

# ── Read version ─────────────────────────────────────────────────────────────
PROPS="$PACKAGE_DIR/app/application.properties"
if [ ! -f "$PROPS" ]; then
    echo "[ERROR] application.properties not found: $PROPS"
    echo "        Run scripts/build-mac-network-app-package.sh in the core repo first."
    exit 1
fi
VERSION=$(grep -E '^app\.version=' "$PROPS" | cut -d= -f2 | tr -d '[:space:]')
if [ -z "$VERSION" ]; then
    echo "[ERROR] app.version not found in $PROPS"
    exit 1
fi

if [ ! -x "$PACKAGE_DIR/runtime/bin/java" ]; then
    echo "[ERROR] Bundled runtime not found: $PACKAGE_DIR/runtime/bin/java"
    echo "        Build it with jlink first (see the design doc)."
    exit 1
fi

ZIP_NAME="jig-toolings-network-macos-${VERSION}.zip"
DIST_DIR="$DIST_REPO/macos/installer/dist"
OUTPUT="$DIST_DIR/$ZIP_NAME"
PACKAGE_URL="https://github.com/gossipred/jig-toolings-network-distribution/releases/download/v${VERSION}/${ZIP_NAME}"

echo "============================================================"
echo " Jig & Toolings Network — macOS Release Builder"
echo " Core repo  : $CORE_REPO"
echo " Version    : $VERSION"
echo " Output     : $OUTPUT"
echo "============================================================"
echo ""

# ── Step 0: Do NOT touch port 8080 here ───────────────────────────────────────
# Unlike the Windows script, this step is intentionally skipped: on the dev
# Mac, port 8080 is the live jig.aurastudio.studio production server managed
# by the com.jj.jig-spring LaunchAgent. Stop it yourself first if you need a
# clean rebuild, then `launchctl kickstart -k gui/501/com.jj.jig-spring`
# afterwards to bring production back up on the freshly built jar.

# ── Step 1: Maven build ───────────────────────────────────────────────────────
echo "[1/4] Building JAR with Maven..."
cd "$CORE_REPO"
/opt/homebrew/bin/mvn -Dmaven.repo.local=.m2/repository package -q
echo "[1/4] Maven build OK."
echo ""

# ── Step 2: Assemble package directory ───────────────────────────────────────
echo "[2/4] Assembling package directory..."
bash "$PACKAGE_DIR/scripts/build-mac-network-app-package.sh"
echo "[2/4] Assembly OK."
echo ""

# ── Step 2.5: Sync launcher scripts from distribution repo ───────────────────
echo "[2.5] Syncing launcher scripts from distribution repo..."
cp "$LAUNCHER_DIR/START-JIG-NETWORK-APP.command" "$PACKAGE_DIR/START-JIG-NETWORK-APP.command"
for f in "$LAUNCHER_DIR/scripts/"*; do
    [ -f "$f" ] && cp "$f" "$PACKAGE_DIR/scripts/"
done
chmod +x "$PACKAGE_DIR/START-JIG-NETWORK-APP.command" "$PACKAGE_DIR"/scripts/*.command "$PACKAGE_DIR"/scripts/*.sh
echo "[2.5] Launcher sync OK."
echo ""

# ── Step 3: Create ZIP ────────────────────────────────────────────────────────
echo "[3/4] Creating ZIP: $ZIP_NAME"
mkdir -p "$DIST_DIR"
rm -f "$OUTPUT"
cd "$PACKAGE_DIR"
find . -name ".DS_Store" -delete 2>/dev/null || true
zip -r "$OUTPUT" . \
    --exclude "*/.DS_Store" \
    --exclude ".DS_Store" \
    --exclude "*.sh" \
    --exclude ".gitignore" \
    --exclude "backups/*" \
    --exclude "logs/*" \
    --exclude "license/*.lic"

SHA256=$(shasum -a 256 "$OUTPUT" | awk '{print $1}')
ZIP_SIZE=$(du -sh "$OUTPUT" | cut -f1)
echo "[3/4] ZIP created: $ZIP_SIZE"
echo ""

# ── Step 4: Update manifests ──────────────────────────────────────────────────
echo "[4/4] Updating shared/latest.json and releases/${VERSION}/manifest.json..."

RELEASE_DIR="$DIST_REPO/releases/$VERSION"
mkdir -p "$RELEASE_DIR"

if [ ! -f "$RELEASE_DIR/manifest.json" ]; then
    cp "$DIST_REPO/shared/latest.json" "$RELEASE_DIR/manifest.json"
fi

python3 - <<PYEOF
import json, os
from datetime import date

sha256      = "$SHA256"
package_url = "$PACKAGE_URL"
version     = "$VERSION"

paths = [
    "$DIST_REPO/shared/latest.json",
    "$RELEASE_DIR/manifest.json",
]

for path in paths:
    with open(path) as f:
        d = json.load(f)
    d["platforms"]["macos"]["packageUrl"] = package_url
    d["platforms"]["macos"]["sha256"] = sha256
    # releaseDate/notesUrl used to only get updated by hand after every release
    # (see jig-license-automation session notes) — fixed here so it can't be forgotten again.
    d["releaseDate"] = date.today().isoformat()
    d["notesUrl"] = f"https://github.com/gossipred/jig-toolings-network-distribution/releases/tag/v{version}"
    with open(path, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.write("\n")
    print(f"  Updated: {path}")

checksums_path = "$RELEASE_DIR/checksums.txt"
lines = []
if os.path.exists(checksums_path):
    with open(checksums_path) as f:
        for line in f:
            if "macos" not in line:
                lines.append(line.rstrip())
lines.append(f"{sha256}  $ZIP_NAME")
with open(checksums_path, "w") as f:
    f.write("\n".join(lines) + "\n")
print(f"  Updated: {checksums_path}")
PYEOF

echo "[4/4] Manifests updated."
echo ""

echo "============================================================"
echo " Release complete!"
echo ""
echo " ZIP     : $OUTPUT"
echo " Size    : $ZIP_SIZE"
echo " SHA256  : $SHA256"
echo ""
echo " Next steps:"
echo "   1. Test the ZIP on a Mac (a real cold start on a machine where"
echo "      port 8080 is free, not this dev Mac — see README-FIRST.md's"
echo "      'Known limitation' note)."
echo "   2. cd $DIST_REPO"
echo "   3. git add shared/latest.json releases/$VERSION/ macos/launcher/"
echo "   4. git commit -m \"Release v${VERSION} — macOS package\""
echo "   5. git push origin main"
echo "   6. gh release create v${VERSION} $OUTPUT --repo gossipred/jig-toolings-network-distribution"
echo "      (or gh release upload if the release tag already exists from a Windows build)"
echo "============================================================"
