# Peak Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal Claude Code harness that enforces consistent communication style, three-layer thinking routing, and session startup behavior across all projects.

**Architecture:** A set of Node.js hooks (SessionStart + UserPromptSubmit) installed globally into `~/.claude/` that inject behavioral rules at session open and classify each prompt into L1/L2/L3 for routing. A `CLAUDE.md` defines the full behavioral spec. An install script wires everything into `~/.claude/settings.json`.

**Tech Stack:** Node.js (CommonJS), Bash, Claude Code hooks API

---

## File Map

| File | Responsibility |
|------|---------------|
| `CLAUDE.md` | Full behavioral spec — communication style + layer routing rules |
| `hooks/package.json` | CJS marker — prevents ESM `require()` crash |
| `hooks/peak-config.js` | Shared: `safeWriteFlag`, `readFlag`, `VALID_LAYERS` |
| `hooks/peak-activate.js` | SessionStart hook — inject rules + memory into session context |
| `hooks/peak-layer-tracker.js` | UserPromptSubmit hook — classify prompt, write layer flag, emit reinforcement |
| `hooks/peak-statusline.sh` | Reads flag file, outputs `[PEAK:L1/L2/L3]` badge |
| `hooks/install.sh` | Copies hooks to `~/.claude/hooks/`, patches `settings.json`, copies `CLAUDE.md` |
| `hooks/uninstall.sh` | Reverses install |
| `skills/peak/SKILL.md` | Loadable skill version of behavioral rules |
| `README.md` | Install instructions |

---

### Task 1: Git init + CLAUDE.md

**Files:**
- Create: `CLAUDE.md`
- Create: `README.md` (skeleton)

- [ ] **Step 1: Init the repo**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git init
```

Expected: `Initialized empty Git repository in ...`

- [ ] **Step 2: Write CLAUDE.md**

Create `/mnt/c/Users/lamho/repo/peak-engine/CLAUDE.md`:

```markdown
# Peak Engine

## Communication Style

### Conversation (chat with the user)
- Respond in Traditional Chinese (繁體中文), concise and direct
- Never open with 好的/當然/沒問題/當然可以
- State conclusion first, reason only when needed
- Technical terms always in English: hook, spec, skill, SessionStart, UserPromptSubmit,
  CLAUDE.md, API, PR, repo, commit, etc.

### Output artifacts (code, specs, docs, PRs, plans, comments)
- Language: Professional English
- Complete sentences, professional register
- Banned words: delve, robust, comprehensive, nuanced, leverage, certainly, of course,
  happy to help, great question
- No em dashes
- No throat-clearing openers ("Sure!", "Of course!", "I'll help you with that")

### Internal reasoning standard
Apply the precision of classical Chinese (文言文): one term = one meaning, no redundancy.
This is the thinking discipline, not the output format.

---

## Layer Routing

Automatically classify every prompt. No manual trigger.

### Layer 1 — Direct
**When:** Factual questions, syntax lookups, clear bug fixes, "what is X", "how do I Y"
**Action:** Answer directly. No ceremony.

### Layer 2 — Challenge
**When:** Questions with intent — "should I", "is this right", "which approach",
"what do you think", "better to", implicit assumptions, single-component decisions

**Execute in order:**

1. **Challenge the premise** — Is the assumption correct?
   - "A or B?" → Is it definitely A or B? Could there be C?
   - "Is this right?" → Right by what standard, for whom, short or long term?
   - "Optimize X?" → Is X actually the bottleneck?

2. **Blind spot detection** — Is this solving the root problem or a symptom?
   - Optimizing X when X may not need to exist
   - Choosing A vs B when the real problem is a different decision entirely
   - Adding a feature when the user pain is elsewhere
   - Fixing a bug that signals a deeper design flaw
   - If no blind spot: say "premise is sound" and continue
   - If uncertain: ask one question to surface more context

3. **Second opinion** — State disagreement or additions concretely:
   - "Your direction is right, but you are missing [specific risk]"
   - "If it were me, I would not start here because [specific reason]"
   - "This assumption holds in [context X], but your situation is [Y]"

4. **Concrete next action** — End with what to do:
   - "Validate [X] before deciding"
   - "Test [Y] — faster answer than building [Z]"
   - "This decision can wait until [milestone]"

**Prohibited:** Answering without Steps 1-2. "Great question." "It depends on your needs."

### Layer 3 — Brainstorm
**When:** System design, new repos, new features, "help me design X", "I want to build Y",
multi-component scope, architecture questions

**Action:**
1. Invoke the superpowers brainstorming skill
2. Before implementation, include in spec:
   - ASCII art design diagram (component relationships)
   - ASCII art data flow diagram (how data moves input → output)
   - Both are required. If a diagram cannot be drawn cleanly, the design is not ready.
```

- [ ] **Step 3: Write README.md skeleton**

Create `/mnt/c/Users/lamho/repo/peak-engine/README.md`:

```markdown
# peak-engine

Personal Claude Code harness. Enforces consistent communication style and
three-layer thinking across all sessions.

## Install

```bash
bash hooks/install.sh
```

Copies hook files to `~/.claude/hooks/` and wires them into `~/.claude/settings.json`.
Copies `CLAUDE.md` to `~/.claude/CLAUDE.md` (global, applies to all projects).

## Uninstall

```bash
bash hooks/uninstall.sh
```

## Layers

| Layer | Trigger | Behavior |
|-------|---------|----------|
| L1 | Factual questions, bug fixes | Direct answer |
| L2 | Intent questions, tradeoffs, "should I" | Challenge premise → blind spot check → second opinion → next action |
| L3 | System design, new builds | Superpowers brainstorming + ASCII diagrams required |

## Statusline

Shows `[PEAK:L1]`, `[PEAK:L2]`, or `[PEAK:L3]` in Claude Code statusline.
```

- [ ] **Step 4: Initial commit**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git add CLAUDE.md README.md docs/
git commit -m "feat: initial repo scaffold with CLAUDE.md and spec"
```

---

### Task 2: hooks/package.json + peak-config.js

**Files:**
- Create: `hooks/package.json`
- Create: `hooks/peak-config.js`

- [ ] **Step 1: Create hooks directory and package.json**

```bash
mkdir -p /mnt/c/Users/lamho/repo/peak-engine/hooks
```

Create `/mnt/c/Users/lamho/repo/peak-engine/hooks/package.json`:

```json
{"type": "commonjs"}
```

This pins the hooks directory to CommonJS so `require()` works even if an ancestor
`package.json` declares `"type": "module"`.

- [ ] **Step 2: Write peak-config.js**

Create `/mnt/c/Users/lamho/repo/peak-engine/hooks/peak-config.js`:

```javascript
#!/usr/bin/env node
// Shared config for peak-engine hooks.
// safeWriteFlag: symlink-safe atomic write with 0600 permissions.
// readFlag: symlink-safe read, size-capped, whitelist-validated.

const fs = require('fs');
const path = require('path');
const os = require('os');

const VALID_LAYERS = ['l1', 'l2', 'l3'];
const MAX_FLAG_BYTES = 8; // longest valid value is "l3" (2 bytes); 8 gives slack

function safeWriteFlag(flagPath, content) {
  try {
    const flagDir = path.dirname(flagPath);
    fs.mkdirSync(flagDir, { recursive: true });

    // If the parent directory is a symlink, resolve and verify ownership.
    let realFlagDir;
    try {
      const lstat = fs.lstatSync(flagDir);
      if (lstat.isSymbolicLink()) {
        realFlagDir = fs.realpathSync(flagDir);
        const realStat = fs.statSync(realFlagDir);
        if (!realStat.isDirectory()) return;
        if (typeof process.getuid === 'function') {
          if (realStat.uid !== process.getuid()) return;
        } else {
          const home = os.homedir();
          const norm = path.resolve(realFlagDir).toLowerCase();
          const normHome = path.resolve(home).toLowerCase();
          if (!norm.startsWith(normHome + path.sep) && norm !== normHome) return;
        }
      } else {
        realFlagDir = flagDir;
      }
    } catch (e) {
      return;
    }

    // The flag file itself must not be a symlink.
    const realFlagPath = path.join(realFlagDir, path.basename(flagPath));
    try {
      if (fs.lstatSync(realFlagPath).isSymbolicLink()) return;
    } catch (e) {
      if (e.code !== 'ENOENT') return;
    }

    const tempPath = path.join(realFlagDir, `.peak-layer.${process.pid}.${Date.now()}`);
    const O_NOFOLLOW = typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0;
    const flags = fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | O_NOFOLLOW;
    let fd;
    try {
      fd = fs.openSync(tempPath, flags, 0o600);
      fs.writeSync(fd, String(content));
      try { fs.fchmodSync(fd, 0o600); } catch (e) {}
    } finally {
      if (fd !== undefined) fs.closeSync(fd);
    }
    fs.renameSync(tempPath, realFlagPath);
  } catch (e) {
    // Silent fail — flag is best-effort
  }
}

function readFlag(flagPath) {
  try {
    let st;
    try {
      st = fs.lstatSync(flagPath);
    } catch (e) {
      return null;
    }
    if (st.isSymbolicLink() || !st.isFile()) return null;
    if (st.size > MAX_FLAG_BYTES) return null;

    const O_NOFOLLOW = typeof fs.constants.O_NOFOLLOW === 'number' ? fs.constants.O_NOFOLLOW : 0;
    const openFlags = fs.constants.O_RDONLY | O_NOFOLLOW;
    let fd;
    let out;
    try {
      fd = fs.openSync(flagPath, openFlags);
      const buf = Buffer.alloc(MAX_FLAG_BYTES);
      const n = fs.readSync(fd, buf, 0, MAX_FLAG_BYTES, 0);
      out = buf.slice(0, n).toString('utf8');
    } finally {
      if (fd !== undefined) fs.closeSync(fd);
    }

    const raw = out.trim().toLowerCase();
    if (!VALID_LAYERS.includes(raw)) return null;
    return raw;
  } catch (e) {
    return null;
  }
}

module.exports = { VALID_LAYERS, safeWriteFlag, readFlag };
```

- [ ] **Step 3: Verify the module loads without errors**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
node -e "const c = require('./hooks/peak-config'); console.log(c.VALID_LAYERS);"
```

Expected output: `[ 'l1', 'l2', 'l3' ]`

- [ ] **Step 4: Commit**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git add hooks/
git commit -m "feat: add hooks/package.json CJS marker and peak-config.js"
```

---

### Task 3: peak-activate.js (SessionStart hook)

**Files:**
- Create: `hooks/peak-activate.js`

- [ ] **Step 1: Write peak-activate.js**

Create `/mnt/c/Users/lamho/repo/peak-engine/hooks/peak-activate.js`:

```javascript
#!/usr/bin/env node
// SessionStart hook for peak-engine.
// 1. Reads SKILL.md and emits behavioral rules as hidden system context.
// 2. Writes flag file ~/.claude/.peak-layer = 'l1' (default).
// 3. Locates MEMORY.md under $CLAUDE_CONFIG_DIR/projects/ and injects contents.
// All failures are silent — never block session start.

const fs = require('fs');
const path = require('path');
const os = require('os');
const { safeWriteFlag } = require('./peak-config');

const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const flagPath = path.join(claudeDir, '.peak-layer');

// 1. Default layer flag to l1 at session open
safeWriteFlag(flagPath, 'l1');

// 2. Read SKILL.md — source of truth for behavioral rules
let skillContent = '';
try {
  skillContent = fs.readFileSync(
    path.join(__dirname, '..', 'skills', 'peak', 'SKILL.md'), 'utf8'
  );
  // Strip YAML frontmatter if present
  skillContent = skillContent.replace(/^---[\s\S]*?---\s*/, '');
} catch (e) {
  // SKILL.md not found — fall back to inline rules
  skillContent = `
PEAK ENGINE ACTIVE

## Communication
- Chat responses: Traditional Chinese (繁體中文), concise, direct
- Technical terms always in English
- Output artifacts: Professional English only
- No filler openers, no pleasantries, no hedging
- No em dashes, no AI vocabulary (delve/robust/comprehensive/nuanced/leverage)

## Layer Routing (automatic)
Layer 1 — factual questions, bug fixes: answer directly
Layer 2 — intent/tradeoff questions ("should I", "is this right", "which approach"):
  1. Challenge the premise
  2. Detect blind spots (solving symptom vs root problem?)
  3. Give second opinion concretely
  4. End with concrete next action
Layer 3 — system design, new builds, "help me design X":
  1. Invoke superpowers brainstorming skill
  2. Spec must include ASCII art design diagram + data flow diagram before implementation
`;
}

// 3. Locate and load MEMORY.md
let memoryContent = '';
try {
  const projectsDir = path.join(claudeDir, 'projects');
  const entries = fs.readdirSync(projectsDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const memPath = path.join(projectsDir, entry.name, 'memory', 'MEMORY.md');
    if (fs.existsSync(memPath)) {
      const content = fs.readFileSync(memPath, 'utf8').trim();
      if (content) {
        memoryContent += `\n\n## Memory: ${entry.name}\n${content}`;
      }
    }
  }
} catch (e) {
  // Silent fail
}

// Emit as system context (hidden from user, injected by Claude Code)
let output = 'PEAK ENGINE ACTIVE\n\n' + skillContent.trim();
if (memoryContent) {
  output += '\n\n---\n\n## Loaded Memory\n' + memoryContent.trim();
}

process.stdout.write(output);
```

- [ ] **Step 2: Verify it runs and produces output**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
node hooks/peak-activate.js
```

Expected: Prints "PEAK ENGINE ACTIVE" followed by behavioral rules. No errors.

- [ ] **Step 3: Verify it handles missing SKILL.md gracefully**

```bash
node hooks/peak-activate.js 2>&1; echo "Exit: $?"
```

Expected: Exit code 0 even if `skills/peak/SKILL.md` does not exist yet.

- [ ] **Step 4: Commit**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git add hooks/peak-activate.js
git commit -m "feat: add SessionStart hook with rule injection and memory loading"
```

---

### Task 4: peak-layer-tracker.js (UserPromptSubmit hook)

**Files:**
- Create: `hooks/peak-layer-tracker.js`

- [ ] **Step 1: Write peak-layer-tracker.js**

Create `/mnt/c/Users/lamho/repo/peak-engine/hooks/peak-layer-tracker.js`:

```javascript
#!/usr/bin/env node
// UserPromptSubmit hook for peak-engine.
// 1. Classifies prompt into l1/l2/l3 using keyword matching.
// 2. Writes layer to flag file.
// 3. Emits hookSpecificOutput to reinforce layer behavior each turn.

const { safeWriteFlag, readFlag, VALID_LAYERS } = require('./peak-config');
const path = require('path');
const os = require('os');

const claudeDir = process.env.CLAUDE_CONFIG_DIR || path.join(os.homedir(), '.claude');
const flagPath = path.join(claudeDir, '.peak-layer');

// L3 keywords — checked first (higher priority)
const L3_PATTERNS = [
  /\bbuild\b/i, /\bcreate\b/i, /\bdesign\b/i, /\barchitecture\b/i,
  /\bnew repo\b/i, /\bnew system\b/i, /\bnew feature\b/i,
  /\bhow (do i|should i) build\b/i, /\bi want to (build|create|design)\b/i,
  /\bhelp me (build|design|create)\b/i, /\bscaffold\b/i,
  /\bsystem design\b/i, /\brefactor (the )?whole\b/i,
];

// L2 keywords
const L2_PATTERNS = [
  /\bshould i\b/i, /\bshould we\b/i, /\bis this (right|correct|good|better)\b/i,
  /\bwhich (approach|option|way|method|framework|tool)\b/i,
  /\bwhat do you think\b/i, /\bwhat('s| is) (your|the best)\b/i,
  /\bbetter to\b/i, /\bbetter approach\b/i, /\bright way\b/i,
  /\bthoughts on\b/i, /\byour opinion\b/i, /\brecommend\b/i,
  /\badvice\b/i, /\bwhat would you\b/i, /\bhow should (i|we)\b/i,
  /\bis it (worth|a good idea)\b/i, /\bpros and cons\b/i,
  /\btradeoff\b/i, /\btrade-off\b/i, /\bcompare\b/i,
];

function classifyPrompt(prompt) {
  for (const pattern of L3_PATTERNS) {
    if (pattern.test(prompt)) return 'l3';
  }
  for (const pattern of L2_PATTERNS) {
    if (pattern.test(prompt)) return 'l2';
  }
  return 'l1';
}

const REINFORCEMENT = {
  l1: 'PEAK L1 ACTIVE: Answer directly. No ceremony.',
  l2: 'PEAK L2 ACTIVE: Before answering — (1) challenge the premise, (2) check for blind spots (symptom vs root problem?), (3) give concrete second opinion, (4) end with next action. Do NOT skip steps 1-2.',
  l3: 'PEAK L3 ACTIVE: Invoke superpowers brainstorming skill. Spec must include ASCII art design diagram and data flow diagram before any implementation.',
};

let input = '';
process.stdin.on('data', chunk => { input += chunk; });
process.stdin.on('end', () => {
  try {
    const data = JSON.parse(input);
    const prompt = (data.prompt || '').trim();

    const layer = classifyPrompt(prompt);
    safeWriteFlag(flagPath, layer);

    process.stdout.write(JSON.stringify({
      hookSpecificOutput: {
        hookEventName: 'UserPromptSubmit',
        additionalContext: REINFORCEMENT[layer],
      }
    }));
  } catch (e) {
    // Silent fail
  }
});
```

- [ ] **Step 2: Verify L1 classification**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
echo '{"prompt":"what is a closure in javascript"}' | node hooks/peak-layer-tracker.js
```

Expected: JSON with `additionalContext` containing `PEAK L1 ACTIVE`

- [ ] **Step 3: Verify L2 classification**

```bash
echo '{"prompt":"should I use postgres or mysql for this"}' | node hooks/peak-layer-tracker.js
```

Expected: JSON with `additionalContext` containing `PEAK L2 ACTIVE`

- [ ] **Step 4: Verify L3 classification**

```bash
echo '{"prompt":"help me design a caching system"}' | node hooks/peak-layer-tracker.js
```

Expected: JSON with `additionalContext` containing `PEAK L3 ACTIVE`

- [ ] **Step 5: Verify L3 takes priority over L2**

```bash
echo '{"prompt":"should I build this with Next.js"}' | node hooks/peak-layer-tracker.js
```

Expected: `PEAK L3 ACTIVE` (build keyword triggers L3 over should)

- [ ] **Step 6: Commit**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git add hooks/peak-layer-tracker.js
git commit -m "feat: add UserPromptSubmit hook with L1/L2/L3 classification"
```

---

### Task 5: peak-statusline.sh

**Files:**
- Create: `hooks/peak-statusline.sh`

- [ ] **Step 1: Write peak-statusline.sh**

Create `/mnt/c/Users/lamho/repo/peak-engine/hooks/peak-statusline.sh`:

```bash
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
```

- [ ] **Step 2: Make executable**

```bash
chmod +x /mnt/c/Users/lamho/repo/peak-engine/hooks/peak-statusline.sh
```

- [ ] **Step 3: Verify output**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
CLAUDE_DIR="$(pwd)/test-tmp" mkdir -p test-tmp
echo "l2" > test-tmp/.peak-layer
CLAUDE_CONFIG_DIR="$(pwd)/test-tmp" bash hooks/peak-statusline.sh
rm -rf test-tmp
```

Expected: `[PEAK:L2]` printed in yellow ANSI color.

- [ ] **Step 4: Commit**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git add hooks/peak-statusline.sh
git commit -m "feat: add statusline badge script"
```

---

### Task 6: install.sh + uninstall.sh

**Files:**
- Create: `hooks/install.sh`
- Create: `hooks/uninstall.sh`

- [ ] **Step 1: Write install.sh**

Create `/mnt/c/Users/lamho/repo/peak-engine/hooks/install.sh`:

```bash
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
```

- [ ] **Step 2: Write uninstall.sh**

Create `/mnt/c/Users/lamho/repo/peak-engine/hooks/uninstall.sh`:

```bash
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
```

- [ ] **Step 3: Make scripts executable**

```bash
chmod +x /mnt/c/Users/lamho/repo/peak-engine/hooks/install.sh
chmod +x /mnt/c/Users/lamho/repo/peak-engine/hooks/uninstall.sh
```

- [ ] **Step 4: Dry-run install against a temp settings file**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
mkdir -p /tmp/peak-test-claude/hooks
echo '{}' > /tmp/peak-test-claude/settings.json
CLAUDE_CONFIG_DIR=/tmp/peak-test-claude bash hooks/install.sh
cat /tmp/peak-test-claude/settings.json
rm -rf /tmp/peak-test-claude
```

Expected: settings.json contains `hooks.SessionStart`, `hooks.UserPromptSubmit`, and `statusLine`. No errors.

- [ ] **Step 5: Commit**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git add hooks/install.sh hooks/uninstall.sh
git commit -m "feat: add install and uninstall scripts"
```

---

### Task 7: skills/peak/SKILL.md

**Files:**
- Create: `skills/peak/SKILL.md`

- [ ] **Step 1: Create skills directory and SKILL.md**

```bash
mkdir -p /mnt/c/Users/lamho/repo/peak-engine/skills/peak
```

Create `/mnt/c/Users/lamho/repo/peak-engine/skills/peak/SKILL.md`:

```markdown
---
name: peak
description: >
  Peak Engine behavioral rules. Enforces Traditional Chinese chat responses,
  professional English output artifacts, and three-layer thinking (L1 direct,
  L2 challenge, L3 brainstorm). Auto-loaded by SessionStart hook.
---

PEAK ENGINE ACTIVE

## Communication

**Chat (conversation with user):**
- Language: Traditional Chinese (繁體中文), concise and direct
- Never open with 好的/當然/沒問題/當然可以
- State conclusion first, reason only when needed
- Technical terms always in English: hook, spec, skill, API, PR, repo, commit, etc.

**Output artifacts (code, specs, docs, PRs, plans, comments):**
- Language: Professional English
- Complete sentences, professional register
- Banned: delve, robust, comprehensive, nuanced, leverage, certainly, of course,
  happy to help, great question
- No em dashes. No AI throat-clearing openers.

**Internal reasoning:** Apply the precision of 文言文 — one term, one meaning, no redundancy.
This is the thinking discipline, not the output format.

## Layer Routing (automatic — no manual trigger)

### L1 — Direct
Factual questions, syntax lookups, bug fixes, "what is X", "how do I Y"
→ Answer directly. No ceremony.

### L2 — Challenge
Questions with intent: "should I", "is this right", "which approach",
"what do you think", "better to", implicit assumptions, tradeoff decisions.

Execute in order — do not skip:

1. **Challenge the premise:** Is the assumption correct?
   - "A or B?" → Is it definitely A or B? What about C?
   - "Optimize X?" → Is X the actual bottleneck?

2. **Blind spot detection:** Is this solving the root problem or a symptom?
   - Optimizing something that may not need to exist
   - Choosing between options when the real problem is something else entirely
   - Adding a feature when the user pain is in a different place
   - If no blind spot found: say "premise is sound" and continue
   - If uncertain: ask one targeted question

3. **Second opinion:** State disagreement concretely
   - "Your direction is right, but you are missing [specific risk]"
   - "If it were me, I would not start here because [specific reason]"

4. **Concrete next action:** End with what to do
   - "Validate [X] before deciding"
   - "Test [Y] — faster answer than building [Z]"

Prohibited: answering without Steps 1–2. "Great question." "It depends on your needs."

### L3 — Brainstorm
System design, new repos, new features, "help me design X", "I want to build Y",
multi-component scope, architecture decisions.

1. Invoke superpowers brainstorming skill
2. Spec must include before implementation:
   - ASCII art design diagram (component relationships)
   - ASCII art data flow diagram (input → transforms → output → storage → external deps)
   - Both required. If a diagram cannot be drawn cleanly, the design is not ready.

## Persistence

ACTIVE EVERY RESPONSE. Does not revert after context compression.
```

- [ ] **Step 2: Verify activate hook reads it correctly**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
node hooks/peak-activate.js | head -5
```

Expected: First line is `PEAK ENGINE ACTIVE`, followed by SKILL.md content (frontmatter stripped).

- [ ] **Step 3: Commit**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git add skills/
git commit -m "feat: add skills/peak/SKILL.md"
```

---

### Task 8: GitHub repo + install

**Files:** none new

- [ ] **Step 1: Create GitHub repo**

```bash
# Set your token first: export GH_TOKEN=<your_pat>
gh repo create marcohwlam/peak-engine --private --description "Personal Claude Code harness — layered thinking, consistent sessions" --source /mnt/c/Users/lamho/repo/peak-engine --remote origin --push
```

Expected: Repo created at `https://github.com/marcohwlam/peak-engine`

- [ ] **Step 2: Verify remote**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git remote -v
git log --oneline
```

Expected: `origin` points to `github.com/marcohwlam/peak-engine`, all commits visible.

- [ ] **Step 3: Run install against real ~/.claude**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
bash hooks/install.sh
```

Expected: Hooks copied to `~/.claude/hooks/`, `settings.json` patched, `~/.claude/CLAUDE.md` updated.

- [ ] **Step 4: Verify settings.json was patched**

```bash
cat ~/.claude/settings.json | python3 -c "
import json, sys
s = json.load(sys.stdin)
print('SessionStart hooks:', len(s.get('hooks', {}).get('SessionStart', [])))
print('UserPromptSubmit hooks:', len(s.get('hooks', {}).get('UserPromptSubmit', [])))
print('statusLine:', s.get('statusLine', {}).get('command', 'MISSING'))
"
```

Expected: SessionStart count ≥ 1, UserPromptSubmit count ≥ 1, statusLine command contains `peak-statusline`.

- [ ] **Step 5: Final commit + push**

```bash
cd /mnt/c/Users/lamho/repo/peak-engine
git push origin main
```

---

## GSTACK REVIEW REPORT

| Review | Trigger | Why | Runs | Status | Findings |
|--------|---------|-----|------|--------|----------|
| Eng Review | `/plan-eng-review` | Architecture & tests | 0 | — | — |

**VERDICT:** NO REVIEWS YET — run reviews before executing if this is a high-stakes change.
