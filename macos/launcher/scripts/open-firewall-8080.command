#!/usr/bin/env bash
# Kept for older instructions that mention this file name.
# macOS's firewall allows the Java program itself, so the configured port does not matter.
exec bash "$(dirname "$0")/open-firewall.command"
