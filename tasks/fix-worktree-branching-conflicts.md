# Fix: Worktree branching causes massive merge conflicts in exec-eng-tasks

**Status:** [x]
**Affects:** `skills/exec-eng-tasks/SKILL.md`

## Problem

When `exec-eng-tasks` dispatches sub-agents with `isolation: "worktree"`, each worktree branches from the repo's current state — but that state may not include results from prior task groups that were squash-merged into the feature branch.

This causes:

1. **Redundant work**: Every sub-agent re-discovers and re-applies changes from prerequisite tasks (e.g., package renames, interface definitions) because the worktree doesn't have them.
2. **Rename/rename conflicts**: Directory restructuring (e.g., `packages/domains/diagnostics/` vs `packages/provider-diagnostics/`) creates conflicting rename targets during squash-merge.
3. **Import path divergence**: Package renames (e.g., `@cogsworth/domain-diagnostics` → `@cogsworth/rivian-diagnostics`) get applied by every sub-agent independently, causing conflicts in every file that imports the renamed package.
4. **Massive manual conflict resolution**: The eng manager agent spends more time resolving merge conflicts than it does reviewing sub-agent work. Each group requires 5-15 minutes of conflict resolution instead of a quick squash-merge.

### Root cause

The `isolation: "worktree"` parameter creates a git worktree from the current branch HEAD. But "current branch HEAD" for the *worktree* is the commit at the time the worktree is created — it doesn't automatically pick up squash-merge commits that the eng manager makes to the feature branch between groups.

### Observed in

`epic/domain-extensibility` execution — 7 tasks across 6 groups. Every group after Group A required manual conflict resolution. Conflicts were entirely mechanical (path remapping, import fixups) but time-consuming and error-prone.

## Proposed Solutions

### Option A: Push feature branch before each group (recommended)

Before dispatching each new dependency group, commit and push the feature branch so worktrees branch from the latest accumulated state.

**Changes to SKILL.md Step 5:**
> **Before dispatching the next dependency group**, verify the feature branch has all previous group changes merged. **Push the feature branch** (`git push origin epic/<EPIC_NAME>`) so new worktrees branch from the updated state.

This is the simplest fix and matches git's natural workflow. The worktree will branch from the feature branch tip, which includes all prior squash-merges.

### Option B: Tell sub-agents what changed (complementary)

Include a "Prior task results" section in each sub-agent prompt that lists concrete changes from prior tasks:
- Package renames that occurred
- Directories that were moved
- Interface changes already applied
- Import paths that changed

This prevents sub-agents from re-applying prerequisite changes, reducing conflicts even if worktrees are slightly stale.

### Option C: Use `git worktree add --track` with explicit base

Instead of relying on the default worktree base, explicitly specify the feature branch as the base:
```bash
git worktree add <path> -b <branch> epic/<EPIC_NAME>
```

This requires changes to the Agent tool's `isolation: "worktree"` implementation, which may not be feasible.

## Acceptance criteria

- [x] SKILL.md Step 5 includes instruction to push the feature branch before dispatching each new dependency group
- [x] SKILL.md Step 4 sub-agent prompt construction includes a "Prior task results" section summarizing what earlier groups changed
- [x] Conflict resolution guidance added to Step 5 for when conflicts do occur (path remapping, import fixup patterns)
