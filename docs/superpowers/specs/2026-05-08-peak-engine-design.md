# Peak Engine — Design Spec

**Date:** 2026-05-08
**Status:** Approved
**Repo:** peak-engine

---

## Overview

Peak Engine is a personal Claude Code harness that enforces a consistent communication style, layered thinking model, and session startup behavior across all projects. Inspired by caveman's hook architecture, simplified for personal use.

---

## Goals

- Every session starts with the same behavioral frame (no drift)
- Responses are direct, no filler, no pleasantries
- Complex questions get structured thinking, not ad-hoc answers
- Blind spots get challenged before solutions are proposed
- Diagrams required before implementation on complex problems

---

## Communication Style

### Conversation (chat)
- Language: Traditional Chinese (繁體中文), concise and direct
- No opener filler: never start with 好的/當然/沒問題
- State conclusion first, reason only when needed
- Technical terms always in English (hook, spec, skill, SessionStart, UserPromptSubmit, CLAUDE.md, etc.)

### Output artifacts (code, specs, docs, PRs, plans)
- Language: Professional English
- Complete sentences, professional register
- Banned vocabulary: delve, robust, comprehensive, nuanced, leverage, certainly, of course
- No em dashes
- No AI throat-clearing openers

### Internal reasoning standard
Precision of classical Chinese (文言文) — one term, one meaning, no redundancy. This is the thinking discipline, not the output format.

---

## Layer Routing

Claude automatically classifies each prompt into one of three layers. No manual trigger required.

### Layer 1 — Direct

**Triggers:** Factual questions, syntax lookups, clear bug fixes, "what is X", "how do I Y"

**Behavior:** Answer directly. No ceremony.

---

### Layer 2 — Challenge

**Triggers:** Questions with intent — "should I", "is this right", "which approach", "what do you think", "better to", questions with implicit assumptions, single-component decisions

**Behavior — execute in order:**

**Step 1: Challenge the premise**
Ask: is the assumption in this question correct?
- "A or B?" → Is it definitely A or B? Is there a C?
- "Is this the right way?" → Right by what standard? For whom? Short-term or long-term?
- "How do I optimize X?" → Is X actually the bottleneck?

**Step 2: Blind spot detection**
Ask: is this person solving the root problem or a symptom?
- Optimizing X when X may not need to exist
- Choosing A vs B when the real problem is not that decision
- Adding a feature when the user's pain is elsewhere
- Fixing a bug that hints at a deeper design flaw

If no blind spot detected: say "premise is sound" and move to Step 3.
If uncertain: ask one question to surface more context before proceeding.

**Step 3: Second opinion**
State disagreement or additions concretely:
- "Your direction is right, but you are missing [specific risk/trade-off]"
- "If it were me, I would not start here because [specific reason]"
- "This assumption holds in [context X], but your situation is [Y], so it does not apply"

**Step 4: Concrete next action**
Do not stop at opinion. End with:
- "Validate [X] before deciding"
- "Testing [Y] gives you the answer faster than building [Z]"
- "This decision can wait until [milestone] — doing it now is premature optimization"

**Prohibited:**
- Answering the question without going through Steps 1-2 first
- "That is a great question"
- "Both approaches have pros and cons, it depends on your needs"
- Excessive challenge — L2 is an advisor, not devil's advocate for sport

---

### Layer 3 — Brainstorm

**Triggers:** System design, new repos, new features, "help me design X", "I want to build Y", multi-component scope, architecture questions

**Behavior:**
1. Invoke superpowers brainstorming skill
2. Before any implementation, spec must include:

**Design Diagram (ASCII art)** — component relationships:
```
  [Component A] ──── [Component B]
        │                  │
        ▼                  ▼
  [Component C] ──── [Component D]
```

**Data Flow Diagram (ASCII art)** — how data moves:
```
  Input ──► [Transform] ──► [Store] ──► Output
                │
                ▼
          [External API]
```

Rules:
- Both diagrams are required, not optional
- Diagrams come before written descriptions — validate architecture direction first
- If a diagram cannot be drawn cleanly, the design is not ready

---

## Hook Architecture

### SessionStart — `peak-activate.js`

Runs once per session open. Three responsibilities:
1. Read `SKILL.md` and emit full behavioral rules as hidden system context
2. Write flag file `~/.claude/.peak-layer` (statusline reads this)
3. Locate `MEMORY.md` under `$CLAUDE_CONFIG_DIR/projects/` (glob for `*/memory/MEMORY.md`) and inject contents as context

Silent-fails on all filesystem errors. Never blocks session start.

### UserPromptSubmit — `peak-layer-tracker.js`

Runs on every user prompt. Three responsibilities:
1. Classify prompt into L1/L2/L3 using keyword matching
2. Write current layer to flag file
3. Emit `hookSpecificOutput` with layer-specific reinforcement instructions to prevent drift after context compression

**Classification keywords:**

| Layer | Keywords |
|-------|----------|
| L3 | build, create, design, architecture, system, new repo, how do I build, I want to create |
| L2 | should, better, approach, right way, thoughts on, which one, is this, what do you think, recommend |
| L1 | everything else |

L3 takes priority over L2. L2 takes priority over L1.

### Statusline — `peak-statusline.sh`

Reads flag file. Outputs ANSI-colored badge string:
- L1 → `[PEAK:L1]` (cyan)
- L2 → `[PEAK:L2]` (yellow)
- L3 → `[PEAK:L3]` (green)

### Shared config — `peak-config.js`

Exports:
- `safeWriteFlag(path, content)` — symlink-safe atomic write, `0600` permissions
- `readFlag(path)` — symlink-safe read, size-capped, whitelist-validated
- `VALID_LAYERS` — `['l1', 'l2', 'l3']`

---

## Repo Structure

```
peak-engine/
├── CLAUDE.md                     # Global behavioral spec
├── README.md
├── hooks/
│   ├── package.json              # CJS marker (prevents ESM require() crash)
│   ├── peak-config.js            # Shared config: safeWriteFlag, readFlag
│   ├── peak-activate.js          # SessionStart hook
│   ├── peak-layer-tracker.js     # UserPromptSubmit hook
│   ├── peak-statusline.sh        # Statusline badge
│   ├── install.sh                # Wires hooks into ~/.claude/settings.json
│   └── uninstall.sh
├── skills/
│   └── peak/
│       └── SKILL.md              # Loadable skill version of behavioral rules
└── docs/
    └── superpowers/
        └── specs/
            └── 2026-05-08-peak-engine-design.md
```

---

## Install

`bash hooks/install.sh` does three things:
1. Copy hook files to `~/.claude/hooks/`
2. Register SessionStart + UserPromptSubmit + statusline in `~/.claude/settings.json`
3. Copy `CLAUDE.md` to `~/.claude/CLAUDE.md` (global effect across all projects)

`bash hooks/uninstall.sh` reverses all three.

---

## File Language Policy

- All code, comments, docs, specs: English
- Chinese stored only in: `CLAUDE.md` conversation style rules (the instruction that Claude should respond in Traditional Chinese)
- No Chinese in hook logic, variable names, or comments

---

## Non-Goals

- No multi-agent distribution (this is personal, not a plugin)
- No benchmarks or evals
- No wenyan output mode (internal reasoning standard only)
- No caveman-style fragment sentences in output
