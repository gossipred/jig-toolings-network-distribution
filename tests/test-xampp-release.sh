#!/usr/bin/env bash
# Exercise the release guard without building or uploading a package.
set -eu
DIST="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'trash "$WORK"' EXIT
fn="$(sed -n '/^check_no_xampp_installer() {/,/^}/p' "$DIST/tools/check-xampp-installers.sh")"
if [ -z "$fn" ]; then
    echo 'FAIL: release builder has no XAMPP installer guard'
    exit 1
fi
count=0
for kind in clean exe dmg nested directory symlink; do
    pkg="$WORK/$kind"
    mkdir -p "$pkg/subfolder"
    expected=1
    case "$kind" in
        clean) touch "$pkg/subfolder/JigToolingsSetup.exe"; expected=0 ;;
        exe) touch "$pkg/XAMPP-installer.exe" ;;
        dmg) touch "$pkg/XAMPP-installer.dmg" ;;
        nested) touch "$pkg/subfolder/XAMPP-installer-old.dmg" ;;
        directory) mkdir "$pkg/XAMPP-installer-backup" ;;
        symlink) ln -s nonexistent "$pkg/XAMPP-installer.dmg" ;;
    esac
    rc=0
    bash -c "$fn
check_no_xampp_installer \"\$1\"" check "$pkg" > "$WORK/output" 2>&1 || rc=$?
    if [ "$rc" -ne "$expected" ]; then
        echo "FAIL: $kind expected exit $expected, got $rc"
        cat "$WORK/output"
        exit 1
    fi
    if [ "$expected" -eq 1 ]; then
        grep -q 'XAMPP installers must not be packaged or uploaded' "$WORK/output"
    fi
    count=$((count + 1))
done
# A contaminated package must stop before any build or manifest mutation.
for platform in macos windows; do
    package=mac-network-app
    [ "$platform" = windows ] && package=windows-network-app
    mkdir -p "$WORK/core/customer-package/$package"
    touch "$WORK/core/customer-package/$package/XAMPP-installer.dmg"
    rc=0
    bash "$DIST/$platform/installer/release-$platform.sh" "$WORK/core" > "$WORK/output" 2>&1 || rc=$?
    [ "$rc" -eq 1 ]
    if ! grep -q 'XAMPP installers must not be packaged or uploaded' "$WORK/output"; then
        echo "FAIL: $platform builder did not reject the installer before building"
        cat "$WORK/output"
        exit 1
    fi
    count=$((count + 1))
done
# Run only the real upload block against a gh stub, never a live release.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2" = 'release view' ]; then exit 0; fi
printf '%s\n' "$@" > "$XAMPP_TEST_UPLOAD_LOG"
STUB
chmod +x "$WORK/bin/gh"
for platform in macos windows; do
    block="$(awk '/^if \[.*JIG_UPLOAD/ { capture=1 } capture { print } capture && /^fi$/ { exit }' "$DIST/$platform/installer/release-$platform.sh")"
    [ -n "$block" ]
    for upload in 0 1; do
        logfile="$WORK/$platform-$upload-upload.log"
        PATH="$WORK/bin:$PATH" XAMPP_TEST_UPLOAD_LOG="$logfile" JIG_UPLOAD="$upload" \
        bash -c 'VERSION=9.9.9; OUTPUT=jig.zip; EXE_OUTPUT="$1/jig.exe"; EXE_SHA256=hash
PACKAGE_DIR="$1"; XAMPP_SRC="$1/XAMPP-installer.exe"; XAMPP_DMG="$1/XAMPP-installer.dmg"
touch "$EXE_OUTPUT"
eval "$2"' upload "$WORK/exe" "$block" > "$WORK/output" 2>&1
        if [ "$upload" -eq 0 ]; then
            [ ! -e "$logfile" ]
        else
            grep -qx 'jig.zip' "$logfile"
            if grep -q 'XAMPP' "$logfile"; then echo "FAIL: $platform uploads XAMPP"; exit 1; fi
            if [ "$platform" = windows ]; then grep -q '/jig.exe$' "$logfile"; fi
        fi
        count=$((count + 1))
    done
done
echo "$count XAMPP release checks, 0 failed"
