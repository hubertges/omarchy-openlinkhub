#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Testing Omarchy plugin validation on $SCRIPT_DIR..."
omarchy plugin validate "$SCRIPT_DIR"
echo "==> Plugin manifest validation passed successfully!"
