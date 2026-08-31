#!/usr/bin/env bash
# install.sh: Install and enable OpenLinkHub plugin for Omarchy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/omarchy/plugins/hubi.openlinkhub"
CONFIG_FILE="$HOME/.config/omarchy/shell.json"

echo "==> Instalowanie dodatku OpenLinkHub dla Omarchy..."

# 1. Create target plugin directory
mkdir -p "$TARGET_DIR"

# 2. Copy plugin files (excluding .git)
cp -r "$SCRIPT_DIR/manifest.json" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/BarWidget.qml" "$TARGET_DIR/"
cp -r "$SCRIPT_DIR/OpenLinkHubModel.js" "$TARGET_DIR/"
mkdir -p "$TARGET_DIR/bin"
cp -r "$SCRIPT_DIR/bin/openlinkhub-ctl" "$TARGET_DIR/bin/"
chmod +x "$TARGET_DIR/bin/openlinkhub-ctl"

# 3. Validate plugin
if command -v omarchy >/dev/null 2>&1; then
  echo "==> Walidacja manifestu dodatku..."
  omarchy plugin validate "$TARGET_DIR"
fi

# 4. Enable in shell.json if not already present
if [[ -f "$CONFIG_FILE" ]]; then
  echo "==> Konfiguracja paska zadań w $CONFIG_FILE..."
  python3 -c "
import json

with open('$CONFIG_FILE', 'r') as f:
    cfg = json.load(f)

bar = cfg.setdefault('bar', {})
layout = bar.setdefault('layout', {'left': [], 'center': [], 'right': []})
right_section = layout.setdefault('right', [])

exists = any(item.get('id') in ['hubi.openlinkhub', 'omarchy.openlinkhub'] for item in right_section)
if not exists:
    # Insert right after tray or at the beginning of right section
    entry = {'id': 'hubi.openlinkhub', 'displayMetric': 'liquid_temp'}
    right_section.insert(0, entry)
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(cfg, f, indent=2)
    print('  Dodano hubi.openlinkhub do sekcji right w shell.json')
else:
    print('  hubi.openlinkhub jest już obecny w shell.json')
"
fi

# 5. Reload shell plugins
if command -v omarchy-shell >/dev/null 2>&1; then
  echo "==> Przeładowywanie wtyczek omarchy-shell..."
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo "==> Sukces! Dodatek OpenLinkHub został pomyślnie zainstalowany."
echo "    Możesz przetestować CLI za pomocą: $TARGET_DIR/bin/openlinkhub-ctl status"
