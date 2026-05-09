# peak-engine

Personal Claude Code harness. Enforces consistent communication style and
three-layer thinking across all sessions.

## Install

    bash hooks/install.sh

Copies hook files to `~/.claude/hooks/` and wires them into `~/.claude/settings.json`.
Copies `CLAUDE.md` to `~/.claude/CLAUDE.md` (global, applies to all projects).

## Uninstall

    bash hooks/uninstall.sh

## Layers

| Layer | Trigger | Behavior |
|-------|---------|----------|
| L1 | Factual questions, bug fixes | Direct answer |
| L2 | Intent questions, tradeoffs, "should I" | Challenge premise → blind spot check → second opinion → next action |
| L3 | System design, new builds | Superpowers brainstorming + ASCII diagrams required |

## Statusline

Shows `[PEAK:L1]`, `[PEAK:L2]`, or `[PEAK:L3]` in Claude Code statusline.
