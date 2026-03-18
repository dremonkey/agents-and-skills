---
name: exec-eng-tasks
version: 1.0.0
description: |
  Dispatches sub-agents to implement tasks from a plan produced by plan-eng-tasks.
  Reads task files and EPICs from tasks/<EPIC_NAME>/, manages parallel execution
  with worktree isolation, monitors progress, and updates task/epic files on
  completion. Use after plan-eng-tasks has finished planning.
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - Task
  - AskUserQuestion
---

# Execute Engineering Tasks

This skill implements an approved engineering plan by dispatching sub-agents to carry out task files. It is the execution counterpart to `plan-eng-tasks`, which handles planning.

## Input contract

This skill expects artifacts already produced by `plan-eng-tasks`:

- **Epic file:** `tasks/<EPIC_NAME>/EPIC.md` — source of truth for goal, architecture overview, task list, key decisions, and anti-goals.
- **Task files:** `tasks/<EPIC_NAME>/<task>.md` — one per implementable unit, following the task template (title, status, dependencies, goal, context, implementation steps, acceptance criteria).
- **Architecture docs (optional):** `docs/architecture/<INITIATIVE>/` — referenced by tasks when relevant.

If these artifacts do not exist, stop and tell the user to run `plan-eng-tasks` first.

## Engineering preferences (included in sub-agent prompts)

* DRY is important — flag repetition aggressively.
* Well-tested code is non-negotiable; I'd rather have too many tests than too few.
* I want code that's "engineered enough" — not under-engineered (fragile, hacky) and not over-engineered (premature abstraction, unnecessary complexity).
* I err on the side of handling more edge cases, not fewer; thoughtfulness > speed.
* Bias toward explicit over clever.
* Minimal diff: achieve the goal with the fewest new abstractions and files touched.

## Status markers

Task and epic files use these status markers:

- `[ ]` — pending
- `[~]` — in progress
- `[x]` — done
- `[!]` — failed / blocked

## Closed tasks directory

Tasks that are completely done (`[x]`) or cancelled should be moved into a `_closed/` subdirectory within the epic (e.g., `tasks/<EPIC_NAME>/_closed/<task>.md`). This keeps the epic directory clean — only active/pending work is visible at a glance. When reviewing or listing tasks, **ignore everything in `_closed/`** unless the user explicitly asks to check closed tasks.

---

## Step 1: Present the implementation plan

Display a clear execution plan showing:

```
IMPLEMENTATION PLAN
===================

Execution order (respecting dependencies):

  [1] tasks/<EPIC_NAME>/<task-1>.md — <title> (small)
  [2] tasks/<EPIC_NAME>/<task-2>.md — <title> (medium)
      └── blocked by: [1]
  [3] tasks/<EPIC_NAME>/<task-3>.md — <title> (small)
      └── blocked by: [1]
  [4] tasks/<EPIC_NAME>/<task-4>.md — <title> (large)
      └── blocked by: [2], [3]

Parallel execution groups:
  Group A (no dependencies): [1]
  Group B (after [1]):       [2], [3]  ← will run in parallel
  Group C (after [2],[3]):   [4]

Estimated sub-agents: ___
```

Include an ASCII dependency graph if there are more than 3 tasks.

## Step 2: Approval gate

**STOP. Do not proceed without explicit approval.**

Use AskUserQuestion:
> "Implementation plan is ready. How would you like to proceed?"
> **A) Execute all tasks** — dispatch sub-agents for all tasks, respecting dependency order. (Recommended)
> **B) Execute selectively** — choose which tasks to run now and which to defer.
> **C) Review only** — stop here; I'll implement manually using the task files.

If the user chooses C, stop. The task files are the deliverable.

If the user chooses B, use AskUserQuestion to let them select which tasks to execute.

## Step 3: Dispatch sub-agents

For each approved task (respecting dependency order), spawn a sub-agent using the Task tool:

**Sub-agent configuration:**
* **Model:** `sonnet` — use the `model` parameter on the Task tool.
* **Prompt construction:** Read the task file and construct a prompt that includes:
  1. The full task file content (Goal, Context, Implementation sections, Acceptance criteria).
  2. Any relevant context from readiness (constraints, decisions, engineering preferences, ASCII diagrams).
  3. The sub-agent behavioral rules below.
  4. The base branch for the PR: `BASE_BRANCH=<current branch name>` (determine this once at the start of execution via `git branch --show-current`).
* **Parallelism:** Tasks with no unresolved dependencies SHOULD run in parallel. Use `run_in_background: true` for all tasks in a parallel group except the last one, so you can monitor completion. When a group finishes, dispatch the next group.
* **Isolation:** Use `isolation: "worktree"` so each sub-agent works on an isolated copy and can't conflict with others.

**Sub-agent behavioral rules** (include these verbatim in every sub-agent prompt):
```
RULES FOR THIS TASK:
1. You are implementing a single task from an engineering plan. Your eng manager
   (the parent agent) has already reviewed and approved the approach.
2. Follow the "Context" and "Implementation" sections in this task file exactly.
   Do not deviate from the agreed design.
3. Write all tests specified in the "Acceptance criteria" section. Tests are
   non-negotiable.
4. Keep your changes minimal and focused. Only touch files listed in the
   "Implementation" section unless you discover a necessary change — in which
   case, document why.
5. If you get stuck or have a question:
   - First, re-read the task file (especially "Context" and "Implementation").
   - If still stuck, describe the problem clearly in your output. Your eng manager
     will review and provide guidance. Do NOT ask the user directly.
6. When done, output a clear summary:
   - Files created/modified (with brief description of each change)
   - Tests written and whether they pass
   - Any deviations from the task file (with justification)
   - Any unresolved issues or concerns
7. When you are finished, stage and commit ALL your changes in the worktree with
   a descriptive commit message prefixed with the task filename (e.g.,
   "task-03-auth-middleware: implement JWT validation and tests"). This is
   required — uncommitted changes in a worktree are lost when it is cleaned up.
8. After committing, push your branch and create a pull request using
   `gh pr create --base <BASE_BRANCH>` (your eng manager will tell you the
   base branch in the prompt). Use the task title as the PR title and include
   the task's goal and acceptance criteria in the PR body. Do NOT merge the
   PR — your eng manager will review and decide whether to merge.
```

## Step 4: Monitor and manage sub-agents

As sub-agents complete (or get stuck):

**On success:** The sub-agent will have created a PR back to the base branch. Review the sub-agent's output summary and the PR. Check:
- Did it touch only the expected files?
- Did it write the required tests?
- Any deviations — are they justified?

If the work looks good, **merge the PR** using `gh pr merge <number> --merge`.

**After merging each PR in a parallel group:**
1. Pull the updated base branch: `git pull origin <base-branch>`.
2. Check whether the next PR in the group can still merge cleanly: `gh pr view <number> --json mergeable`.
3. If it has conflicts, check out that PR branch, rebase onto the updated base, resolve conflicts, push, then merge.
4. Repeat until all PRs in the group are merged.

**Before dispatching the next dependency group**, always `git pull` so the new worktrees are created from the fully updated base branch.

**On failure or questions:** Act as the engineering manager. Use context from the planning phase to answer the sub-agent's question or unblock it. You have full context on:
- Architecture decisions and their rationale
- Engineering preferences
- The dependency graph and how tasks fit together
- Edge cases and failure modes discussed in the review

**Escalation rule:** Only escalate to the user (via AskUserQuestion) if:
1. The sub-agent hit a problem that wasn't covered in the review, AND
2. You genuinely cannot determine the right answer from the codebase and review context.
When escalating, explain what the sub-agent tried, what went wrong, and present options — don't just pass through a raw error.

## Step 5: Update task files and execution summary

After all sub-agents complete, **update every task file and the epic to reflect the current state:**

**Update each task file's status field** (the `**Status:**` line in the header):
- Completed: change `[ ]` to `[x]`. Check off acceptance criteria that were met. Then **move the task file to `_closed/`** (e.g., `tasks/<EPIC_NAME>/_closed/<task>.md`).
- Cancelled: change `[ ]` to `[x]` and add `**Cancelled:** <reason>` below the status line. Then **move the task file to `_closed/`**.
- Failed/blocked: change `[ ]` to `[!]`. Add a `## Failure notes` section at the bottom with what went wrong and what needs manual attention. Keep in the main epic directory (still active work).
- Not executed (deferred): leave as `[ ]`.

**Update the epic file** (`tasks/<EPIC_NAME>/EPIC.md`):
- Update `**Epic Status:**` — `[x]` if all tasks done, `[~]` if in progress, `[!]` if any task is blocked.
- Update each task's `**Status:**` in the task list section to match the individual task files.
- For tasks moved to `_closed/`, keep their entry in the epic's task list (for historical reference) but mark them with their final status.

**Update architecture docs when implementation changed the shape of the design.**
- If implementation discoveries changed boundaries, data flow, rollout behavior, or key tradeoffs, update the relevant docs in `docs/architecture/<INITIATIVE>` in the same cycle.
- Keep diagrams in `docs/architecture/<INITIATIVE>` consistent with the final implementation and EPIC decisions.
- If no architecture changes were discovered, state that explicitly in the execution summary.

**Reading existing epics:** When scanning an epic's directory to understand current work, **skip the `_closed/` subdirectory entirely.** Only look inside `_closed/` if the user explicitly asks to review closed or cancelled tasks.

Then present the execution summary:

```
EXECUTION COMPLETE
==================

Tasks completed: ___/___
Tasks failed:    ___

Per-task results:
  [1] <task-name> ✓ — <files changed>, <tests written>
  [2] <task-name> ✓ — <files changed>, <tests written>
  [3] <task-name> ✗ — <reason for failure>

Files modified (all tasks combined):
  - path/to/file.rb (tasks 1, 2)
  - path/to/other.js (task 3)

Task files updated: ___
Tasks moved to _closed/: ___
Epic updated: tasks/<EPIC_NAME>/EPIC.md

Tests to run: <command to run the full test suite for changed files>

Unresolved issues:
  - <any issues that need manual attention>
```

**Commit the bookkeeping changes** (task file status updates, moves to `_closed/`, epic updates) to the base branch with a message like `chore: update task/epic status after execution`. Push to the remote.

Then use AskUserQuestion:
> "All tasks are complete. What next?"
> **A) Run the test suite** — verify everything works together.
> **B) Review changes** — I'll walk you through the merged diffs.
> **C) Done** — all PRs are merged; no further action needed.
