#!/bin/bash
# peak-engine installer.
# 1. Copies hook files to $CLAUDE_CONFIG_DIR/hooks/
# 2. Registers hooks + statusline in $CLAUDE_CONFIG_DIR/settings.json
# 3. Copies CLAUDE.md to $CLAUDE_CONFIG_DIR/CLAUDE.md
set -e

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

if ! command -v node >/dev/null 2>&1; then
  echo "ERROR: node is required. Install from https://nodejs.org"
  exit 1
fi

echo "Installing peak-engine to $CLAUDE_DIR ..."

# 1. Copy hook files
mkdir -p "$HOOKS_DIR"
cp "$SCRIPT_DIR/package.json" "$HOOKS_DIR/package.json"
cp "$SCRIPT_DIR/peak-config.js" "$HOOKS_DIR/peak-config.js"
cp "$SCRIPT_DIR/peak-activate.js" "$HOOKS_DIR/peak-activate.js"
cp "$SCRIPT_DIR/peak-layer-tracker.js" "$HOOKS_DIR/peak-layer-tracker.js"
cp "$SCRIPT_DIR/peak-statusline.sh" "$HOOKS_DIR/peak-statusline.sh"
chmod +x "$HOOKS_DIR/peak-statusline.sh"
echo "  Copied hooks to $HOOKS_DIR"

# 2. Patch settings.json using Node
ACTIVATE_CMD="node \"$HOOKS_DIR/peak-activate.js\""
TRACKER_CMD="node \"$HOOKS_DIR/peak-layer-tracker.js\""
STATUSLINE_CMD="bash \"$HOOKS_DIR/peak-statusline.sh\""

node - "$SETTINGS" "$ACTIVATE_CMD" "$TRACKER_CMD" "$STATUSLINE_CMD" <<'EOF'
const fs = require('fs');
const [,, settingsPath, activateCmd, trackerCmd, statuslineCmd] = process.argv;

let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); } catch (e) {}

if (!settings.hooks) settings.hooks = {};

// SessionStart
if (!Array.isArray(settings.hooks.SessionStart)) settings.hooks.SessionStart = [];
const hasActivate = settings.hooks.SessionStart.some(e =>
  e.hooks && e.hooks.some(h => h.command && h.command.includes('peak-activate'))
);
if (!hasActivate) {
  settings.hooks.SessionStart.push({
    matcher: '',
    hooks: [{ type: 'command', command: activateCmd }]
  });
}

// UserPromptSubmit
if (!Array.isArray(settings.hooks.UserPromptSubmit)) settings.hooks.UserPromptSubmit = [];
const hasTracker = settings.hooks.UserPromptSubmit.some(e =>
  e.hooks && e.hooks.some(h => h.command && h.command.includes('peak-layer-tracker'))
);
if (!hasTracker) {
  settings.hooks.UserPromptSubmit.push({
    matcher: '',
    hooks: [{ type: 'command', command: trackerCmd }]
  });
}

// Statusline
if (!settings.statusLine) {
  settings.statusLine = { type: 'command', command: statuslineCmd };
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
console.log('  Patched ' + settingsPath);
EOF

# 3. Copy CLAUDE.md globally
if [ -f "$CLAUDE_DIR/CLAUDE.md" ]; then
  cp "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md.peak-backup-$(date +%Y%m%d%H%M%S)"
  echo "  Backed up existing CLAUDE.md"
fi
cp "$REPO_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo "  Copied CLAUDE.md to $CLAUDE_DIR/CLAUDE.md"

echo ""
echo "peak-engine installed. Restart Claude Code to activate."
