#!/usr/bin/env bash
# uninstall.sh: Remove OpenLinkHub plugin from Omarchy

set -e

TARGET_DIR="$HOME/.config/omarchy/plugins/hubi.openlinkhub"
CONFIG_FILE="$HOME/.config/omarchy/shell.json"

echo "==> Removing OpenLinkHub plugin..."

if [[ -e "$CONFIG_FILE" ]]; then
  echo "==> Removing bar entry from $CONFIG_FILE..."
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
            print(f'Error: {CONFIG_PATH} exceeds maximum size.', file=sys.stderr)
            sys.exit(1)
        cfg = json.loads(content) if content.strip() else {}

    bar = cfg.get('bar', {})
    layout = bar.get('layout', {})
    changed = False
    for section in ['left', 'center', 'right']:
        items = layout.get(section, [])
        if isinstance(items, list):
            new_items = [i for i in items if isinstance(i, dict) and i.get('id') not in ['hubi.openlinkhub', 'omarchy.openlinkhub']]
            if len(items) != len(new_items):
                layout[section] = new_items
                changed = True

    if changed:
        temp_fd, tmp_path = tempfile.mkstemp(dir=config_dir, prefix='.shell.json.tmp.', text=True)
        os.chmod(tmp_path, 0o600)
        with os.fdopen(temp_fd, 'w', encoding='utf-8') as tf:
            json.dump(cfg, tf, indent=2)
            tf.write('\n')
            tf.flush()
            os.fsync(tf.fileno())

        os.replace(tmp_path, CONFIG_PATH)
        tmp_path = None
        print('  Removed the widget from the bar configuration.')
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

if [[ -d "$TARGET_DIR" ]]; then
  rm -rf "$TARGET_DIR"
  echo "  Removed $TARGET_DIR"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo "==> OpenLinkHub plugin has been removed."
