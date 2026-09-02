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

config_dir = os.path.dirname(os.path.abspath(CONFIG_PATH))
open_flags = os.O_RDWR | getattr(os, 'O_NOFOLLOW', 0) | getattr(os, 'O_CLOEXEC', 0)

max_retries = 5
for attempt in range(max_retries):
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

    fd = os.open(CONFIG_PATH, open_flags)
    tmp_path = None
    temp_fd = None
    try:
        fcntl.flock(fd, fcntl.LOCK_EX)

        st_fd = os.fstat(fd)
        if not stat.S_ISREG(st_fd.st_mode) or st_fd.st_size > MAX_CONFIG_SIZE:
            print(f'Error: Invalid file properties for {CONFIG_PATH}', file=sys.stderr)
            sys.exit(1)

        st_cur = os.lstat(CONFIG_PATH)
        if st_cur.st_ino != st_fd.st_ino or st_cur.st_dev != st_fd.st_dev:
            continue

        with os.fdopen(os.dup(fd), 'r', encoding='utf-8') as f:
            content = f.read(MAX_CONFIG_SIZE + 1)
            if len(content) > MAX_CONFIG_SIZE:
                print(f'Error: {CONFIG_PATH} exceeds maximum size.', file=sys.stderr)
                sys.exit(1)
            cfg = json.loads(content) if content.strip() else {}

        if not isinstance(cfg, dict):
            cfg = {}

        bar = cfg.get('bar')
        if not isinstance(bar, dict):
            bar = {}

        layout = bar.get('layout')
        if not isinstance(layout, dict):
            layout = {}

        changed = False
        for section in ['left', 'center', 'right']:
            items = layout.get(section)
            if isinstance(items, list):
                new_items = [i for i in items if isinstance(i, dict) and i.get('id') not in ['hubi.openlinkhub', 'omarchy.openlinkhub']]
                if len(items) != len(new_items):
                    layout[section] = new_items
                    changed = True

        if changed:
            temp_fd, tmp_path = tempfile.mkstemp(dir=config_dir, prefix='.shell.json.tmp.', text=True)
            os.fchmod(temp_fd, 0o600)
            with os.fdopen(temp_fd, 'w', encoding='utf-8') as tf:
                temp_fd = None
                json.dump(cfg, tf, indent=2)
                tf.write('\n')
                tf.flush()
                os.fsync(tf.fileno())

            os.replace(tmp_path, CONFIG_PATH)
            tmp_path = None
            print('  Removed the widget from the bar configuration.')
        break
    finally:
        if temp_fd is not None:
            try:
                os.close(temp_fd)
            except Exception:
                pass
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

if [[ -L "$TARGET_DIR" ]]; then
  rm -f "$TARGET_DIR"
  echo "  Removed symlink $TARGET_DIR"
elif [[ -d "$TARGET_DIR" ]]; then
  rm -rf "$TARGET_DIR"
  echo "  Removed $TARGET_DIR"
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins 2>/dev/null || true
fi

echo "==> OpenLinkHub plugin has been removed."
