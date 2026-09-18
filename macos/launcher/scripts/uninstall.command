#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

SCRIPT_DIR="$(pwd)"
PACKAGE_DIR="$SCRIPT_DIR/.."

echo "This will uninstall the Jig & Toolings Management System app files."
echo
echo "Preserved folders:"
echo "- $PACKAGE_DIR/database"
echo "- $PACKAGE_DIR/uploads"
echo "- $PACKAGE_DIR/backups"
echo
echo "To delete all data too, use uninstall-and-delete-data.command instead."
echo
read -r -p "Continue with normal uninstall? (y/N): " CONFIRM
if [ "${CONFIRM,,}" != "y" ]; then
    exit 0
fi

bash "$SCRIPT_DIR/stop-system.command" < /dev/null

[ -f "$PACKAGE_DIR/app/jig-management-system.jar" ] && rm -f "$PACKAGE_DIR/app/jig-management-system.jar"
[ -d "$PACKAGE_DIR/logs" ] && rm -rf "$PACKAGE_DIR/logs"

echo
echo "Normal uninstall completed. Database files, uploads, and backups were preserved."
read -r -p "Press Enter to close..."
