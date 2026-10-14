#!/usr/bin/env bash
# Signs latest.json for v2.0+ updaters: writes <latest.json>.sig, the Base64
# SHA256withRSA signature of the file's exact bytes (one line, no newline),
# then checks it the way customers do, with the public keys the program ships.
# Re-run it after ANY change to latest.json — an unsigned or stale signature
# makes every v2.x installation refuse the update.
# Usage: sign-latest-json.sh <latest.json> <core_repo>
#   JIG_UPDATE_SIGNING_KEY=<private.pem>  default ~/.jig-update-signing/update-signing-private.pem
#   (use the offline backup key only when the main key is lost or leaked)
set -euo pipefail
JSON="$1"
PUB_DIR="$2/src/main/resources/update-signing"
KEY="${JIG_UPDATE_SIGNING_KEY:-$HOME/.jig-update-signing/update-signing-private.pem}"
[ -f "$KEY" ] || { echo "[ERROR] Signing key not found: $KEY" >&2; exit 1; }

SIG_BIN="$(mktemp)"
trap 'rm -f "$SIG_BIN"' EXIT
openssl dgst -sha256 -sign "$KEY" -out "$SIG_BIN" "$JSON"
openssl base64 -A -in "$SIG_BIN" | tr -d '\n' > "$JSON.sig"

tr -d ' \r\n' < "$JSON.sig" | /usr/bin/openssl base64 -d -A > "$SIG_BIN"
for pub in "$PUB_DIR/update-signing-public.pem" "$PUB_DIR/update-signing-backup-public.pem"; do
    if /usr/bin/openssl dgst -sha256 -verify "$pub" -signature "$SIG_BIN" "$JSON" > /dev/null 2>&1; then
        echo "  Signed: $JSON.sig (checked with $(basename "$pub"))"
        exit 0
    fi
done
rm -f "$JSON.sig"
echo "[ERROR] The signature does not match the public keys in $PUB_DIR." >&2
exit 1
