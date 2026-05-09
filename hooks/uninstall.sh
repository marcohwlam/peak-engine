#!/bin/bash
# peak-engine uninstaller. Removes hooks and restores settings.json.
set -e

CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "Uninstalling peak-engine from $CLAUDE_DIR ..."

# Remove hook files
for f in package.json peak-config.js peak-activate.js peak-layer-tracker.js peak-statusline.sh; do
  rm -f "$HOOKS_DIR/$f"
done
echo "  Removed hook files"

# Remove flag file
rm -f "$CLAUDE_DIR/.peak-layer"

# Patch settings.json to remove peak hooks and statusline
if [ -f "$SETTINGS" ]; then
  node - "$SETTINGS" <<'EOF'
const fs = require('fs');
const [,, settingsPath] = process.argv;

let settings = {};
try { settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8')); } catch (e) { process.exit(0); }

if (settings.hooks) {
  for (const event of ['SessionStart', 'UserPromptSubmit']) {
    if (Array.isArray(settings.hooks[event])) {
      settings.hooks[event] = settings.hooks[event].filter(e =>
        !(e.hooks && e.hooks.some(h => h.command && h.command.includes('peak-')))
      );
      if (settings.hooks[event].length === 0) delete settings.hooks[event];
    }
  }
  if (Object.keys(settings.hooks).length === 0) delete settings.hooks;
}

if (settings.statusLine && settings.statusLine.command &&
    settings.statusLine.command.includes('peak-statusline')) {
  delete settings.statusLine;
}

fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
console.log('  Patched ' + settingsPath);
EOF
fi

echo "peak-engine uninstalled."
