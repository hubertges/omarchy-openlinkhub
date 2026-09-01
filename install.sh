#!/usr/bin/env bash
# install.sh: Install and enable OpenLinkHub plugin for Omarchy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/omarchy/plugins/hubi.openlinkhub"
CONFIG_FILE="$HOME/.config/omarchy/shell.json"

echo "==> Installing OpenLinkHub plugin for Omarchy..."

mkdir -p "$TARGET_DIR"

cp -r "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/Panel.qml" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/OpenLinkHubModel.js" "$TARGET_DIR/"
rm -f "$TARGET_DIR/BarWidget.qml"
mkdir -p "$TARGET_DIR/bin"
cp -r "$SCRIPT_DIR/bin/openlinkhub-ctl" "$TARGET_DIR/bin/"
chmod +x "$TARGET_DIR/bin/openlinkhub-ctl"

if command -v omarchy >/dev/null 2>&1; then
  echo "==> Validating plugin manifest..."
  omarchy plugin validate "$TARGET_DIR"
fi

if [[ -f "$CONFIG_FILE" ]]; then
  echo "==> Updating bar configuration in $CONFIG_FILE..."
  python3 -c "
import json

with open('$CONFIG_FILE', 'r') as f:
    cfg = json.load(f)

bar = cfg.setdefault('bar', {})
layout = bar.setdefault('layout', {'left': [], 'center': [], 'right': []})
right_section = layout.setdefault('right', [])

exists = any(item.get('id') in ['hubi.openlinkhub', 'omarchy.openlinkhub'] for item in right_section)
if not exists:
    entry = {'id': 'hubi.openlinkhub', 'displayMetric': 'liquid_temp'}
    right_section.insert(0, entry)
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('  Added hubi.openlinkhub to the right bar section.')
else:
    print('  hubi.openlinkhub is already present in shell.json.')
"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  echo "==> Reloading Omarchy shell plugins..."
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo "==> Success! OpenLinkHub has been installed."
echo "    You can test the CLI with: $TARGET_DIR/bin/openlinkhub-ctl status"
