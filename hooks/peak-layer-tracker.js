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

// L2 keywords — design decisions only (architecture, approach, stack, data model).
// General opinion phrasing ("should i", "what do you think", "recommend") is
// intentionally excluded so routine choices are not challenged.
const L2_PATTERNS = [
  /\bwhich (approach|architecture|pattern|framework|library|database|stack|design)\b/i,
  /\b(better|best|right) (approach|architecture|pattern|design)\b/i,
  /\bdesign (decision|choice|tradeoff|trade-off)\b/i,
  /\b(architecture|architectural) (decision|choice|tradeoff|trade-off)\b/i,
  /\bpros and cons\b/i, /\btradeoffs?\b/i, /\btrade-offs?\b/i,
  /\b(monolith|microservices?)\b.*\b(or|vs\.?)\b/i,
  /\b(sql|nosql|postgres|mongo\w*)\b.*\b(or|vs\.?)\b/i,
  /\bshould (i|we) (use|adopt|split|separate|migrate to|model|structure)\b/i,
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
  l1: 'PEAK L1 ACTIVE: Answer directly. No ceremony. Do not challenge the premise or add second opinions unless a design decision is at stake.',
  l2: 'PEAK L2 ACTIVE (design decision): Before answering, (1) challenge the premise, (2) check for blind spots (symptom vs root problem?), (3) give concrete second opinion, (4) end with next action. Do NOT skip steps 1-2.',
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
