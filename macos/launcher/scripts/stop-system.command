#!/usr/bin/env bash
set -u
echo "Stopping Jig & Toolings Management System on port 8080..."
echo

PID="$(lsof -ti:8080 2>/dev/null || true)"
if [ -n "$PID" ]; then
    kill -9 $PID 2>/dev/null
fi

echo "Done."
read -r -p "Press Enter to close..."
