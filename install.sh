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

if [[ -e "$CONFIG_FILE" ]]; then
  echo "==> Updating bar configuration in $CONFIG_FILE..."
  python3 -c "
import os
import sys
import json
import fcntl
import stat
import tempfile

CONFIG_PATH = os.path.expanduser('$CONFIG_FILE')
MAX_CONFIG_SIZE = 1024 * 1024  # 1 MB

if not os.path.lexists(CONFIG_PATH):
    sys.exit(0)

if os.path.islink(CONFIG_PATH):
    print(f'Error: {CONFIG_PATH} is a symbolic link.', file=sys.stderr)
    sys.exit(1)

st = os.lstat(CONFIG_PATH)
if not stat.S_ISREG(st.st_mode):
    print(f'Error: {CONFIG_PATH} is not a regular file.', file=sys.stderr)
    sys.exit(1)

if st.st_size > MAX_CONFIG_SIZE:
    print(f'Error: {CONFIG_PATH} exceeds maximum allowed size ({MAX_CONFIG_SIZE} bytes).', file=sys.stderr)
    sys.exit(1)

config_dir = os.path.dirname(os.path.abspath(CONFIG_PATH))
open_flags = os.O_RDWR | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_CLOEXEC', 0)
fd = os.open(CONFIG_PATH, open_flags)
tmp_path = None
try:
    fcntl.flock(fd, fcntl.LOCK_EX)

    st = os.fstat(fd)
    if not stat.S_ISREG(st.st_mode) or st.st_size > MAX_CONFIG_SIZE:
        print(f'Error: Invalid file properties for {CONFIG_PATH}', file=sys.stderr)
        sys.exit(1)

    with os.fdopen(os.dup(fd), 'r', encoding='utf-8') as f:
        content = f.read(MAX_CONFIG_SIZE + 1)
        if len(content) > MAX_CONFIG_SIZE:
            print(f'Error: {CONFIG_PATH} exceeds maximum allowed size.', file=sys.stderr)
            sys.exit(1)
        cfg = json.loads(content) if content.strip() else {}

    bar = cfg.setdefault('bar', {})
    layout = bar.setdefault('layout', {'left': [], 'center': [], 'right': []})
    right_section = layout.setdefault('right', [])

    exists = any(item.get('id') in ['hubi.openlinkhub', 'omarchy.openlinkhub'] for item in right_section if isinstance(item, dict))
    if not exists:
        entry = {'id': 'hubi.openlinkhub', 'displayMetric': 'liquid_temp'}
        right_section.insert(0, entry)

        temp_fd, tmp_path = tempfile.mkstemp(dir=config_dir, prefix='.shell.json.tmp.', text=True)
        os.chmod(tmp_path, 0o600)
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as tf:
            json.dump(cfg, tf, indent=2)
            tf.write('\n')
            tf.flush()
            os.fsync(tf.fileno())

        os.replace(tmp_path, CONFIG_PATH)
        tmp_path = None
        print('  Added hubi.openlinkhub to the right bar section.')
    else:
        print('  hubi.openlinkhub is already present in shell.json.')
finally:
    try:
        fcntl.flock(fd, fcntl.LOCK_UN)
    except Exception:
        pass
    os.close(fd)
    if tmp_path and os.path.exists(tmp_path):
        try:
            os.remove(tmp_path)
        except Exception:
            pass
"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  echo "==> Reloading Omarchy shell plugins..."
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo "==> Success! OpenLinkHub has been installed."
echo "    You can test the CLI with: $TARGET_DIR/bin/openlinkhub-ctl status"
