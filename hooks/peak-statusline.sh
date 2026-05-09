#!/bin/bash
# Reads ~/.claude/.peak-layer and outputs an ANSI-colored badge for Claude Code statusline.
# Symlink-safe: refuses to read if flag path is a symlink.

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
FLAG_PATH="$CLAUDE_DIR/.peak-layer"

# Refuse symlinks
if [ -L "$FLAG_PATH" ]; then
  exit 0
fi

if [ ! -f "$FLAG_PATH" ]; then
  exit 0
fi

LAYER=$(cat "$FLAG_PATH" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

# Whitelist validation
case "$LAYER" in
  l1) ;;
  l2) ;;
  l3) ;;
  *) exit 0 ;;
esac

# ANSI colors: L1=cyan, L2=yellow, L3=green
case "$LAYER" in
  l1) COLOR="\033[0;36m" ;;  # cyan
  l2) COLOR="\033[0;33m" ;;  # yellow
  l3) COLOR="\033[0;32m" ;;  # green
esac
RESET="\033[0m"

LABEL=$(echo "$LAYER" | tr '[:lower:]' '[:upper:]')
printf "${COLOR}[PEAK:%s]${RESET}" "$LABEL"
