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
// When SKILL.md is loaded it already opens with "PEAK ENGINE ACTIVE" — no prefix needed.
// Prefix only applies to the inline fallback content.
let output = skillContent.trim();
if (memoryContent) {
  output += '\n\n---\n\n## Loaded Memory\n' + memoryContent.trim();
}

process.stdout.write(output);
