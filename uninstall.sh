#!/usr/bin/env bash
# uninstall.sh: Remove OpenLinkHub plugin from Omarchy

set -e

TARGET_DIR="$HOME/.config/omarchy/plugins/hubi.openlinkhub"
CONFIG_FILE="$HOME/.config/omarchy/shell.json"

echo "==> Removing OpenLinkHub plugin..."

if [[ -f "$CONFIG_FILE" ]]; then
  echo "==> Removing bar entry from $CONFIG_FILE..."
  python3 -c "
import json

with open('$CONFIG_FILE', 'r') as f:
    cfg = json.load(f)

bar = cfg.get('bar', {})
layout = bar.get('layout', {})
changed = False
for section in ['left', 'center', 'right']:
    items = layout.get(section, [])
    new_items = [i for i in items if i.get('id') not in ['hubi.openlinkhub', 'omarchy.openlinkhub']]
    if len(items) != len(new_items):
        layout[section] = new_items
        changed = True

if changed:
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('  Removed the widget from the bar configuration.')
"
fi

if [[ -d "$TARGET_DIR" ]]; then
  rm -rf "$TARGET_DIR"
  echo "  Removed $TARGET_DIR"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo "==> OpenLinkHub plugin has been removed."
