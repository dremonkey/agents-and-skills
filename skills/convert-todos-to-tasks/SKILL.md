---
name: convert-todos-to-tasks
version: 1.0.0
description: |
  Scans the repo for TODO/FIXME/HACK/XXX comments, creates task files for ones
  that don't already have them, and replaces the original comment with a
  reference to the task file.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# Convert TODOs to Tasks

Scan the codebase for inline debt markers (`TODO`, `FIXME`, `HACK`, `XXX`),
create task files for actionable items, and replace the original comment with a
task reference.

## Step 1: Scan

Search for TODO/FIXME/HACK/XXX comments across the repo:

```bash
rg "TODO|FIXME|HACK|XXX" --glob "!node_modules" --glob "!vendor" --glob "!_closed" --glob "!*.md" -n
```

Collect results into a deduplicated list. Group entries that refer to the same
logical issue (e.g., a TODO and a related FIXME on adjacent lines).

## Step 2: Filter

For each unique item, check whether a task file already exists:

1. Search `tasks/` for files whose `## Goal` or title references the same topic.
2. Search for existing `<!-- task: tasks/.../*.md -->` references in nearby code.

Skip items that already have a corresponding task file. Report them as
"already tracked" in the summary.

## Step 3: Present for approval

Show all new items in a single AskUserQuestion for batch approval:

```
TODO/FIXME items found — N new, M already tracked.

New items:
  [1] TODO  src/foo.rb:42    — "Refactor auth token refresh logic"
  [2] FIXME lib/bar.js:118   — "Race condition on concurrent writes"
  [3] HACK  app/baz.py:7     — "Hardcoded timeout, should use config"
  ...

A) Create task files for all N items.
B) Select which items to convert — list the numbers.
C) Skip — do not create any task files.
```

If the user selects B, let them pick. If C, stop.

## Step 4: Determine epic

Task files live under `tasks/<EPIC_NAME>/`. Before creating files:

1. If there is an existing epic that fits (check `tasks/*/EPIC.md`), assign the
   task there.
2. If multiple items cluster into a theme not covered by an existing epic, ask
   the user whether to create a new epic or assign to an existing one.
3. If no epics exist at all, create `tasks/tech-debt/EPIC.md` as a catch-all.

## Step 5: Create task files

For each approved item, create a task file using the template from
`skills/plan-eng-tasks/TASK_TEMPLATE.md`. Read it before generating files.

Populate the task from what the comment and surrounding code tell you:

- **Title:** Short imperative derived from the comment text.
- **Goal:** What the TODO describes, plus why it matters (infer from context).
- **Context:** The file, line, surrounding code, and any relevant architecture.
- **Implementation:** Best-effort outline. If the fix is unclear, say so.
- **Acceptance criteria:** At minimum: the TODO comment is resolved, and any
  tests that touch the area still pass.

Number tasks sequentially within the epic. If the epic already has tasks,
continue from the highest existing number.

## Step 6: Replace the TODO comment

After creating the task file, edit the source file to replace the original
comment. Keep the comment concise — just a pointer to the task:

**Before:**
```
# TODO: Refactor auth token refresh logic to handle edge case where token
#       expires mid-request and retry queue backs up
```

**After:**
```
# See tasks/tech-debt/task-04-refactor-auth-refresh.md
```

Rules:
- Preserve the comment style of the language (`#`, `//`, `/* */`, etc.).
- If the TODO spans multiple lines, collapse to a single-line reference.
- Do not change any code — only the comment text.

## Step 7: Summary

After all changes, display:

```
CONVERSION COMPLETE
===================

Tasks created: ___
Already tracked (skipped): ___
User-skipped: ___

Created:
  [1] tasks/<epic>/task-NN-<name>.md  ← src/foo.rb:42
  [2] tasks/<epic>/task-NN-<name>.md  ← lib/bar.js:118

Source files modified:
  - src/foo.rb (line 42: TODO → task reference)
  - lib/bar.js (line 118: FIXME → task reference)
```
