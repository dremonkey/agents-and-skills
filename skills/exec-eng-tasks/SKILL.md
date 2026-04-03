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
- **Architecture docs (optional):** relevant docs in `docs/architecture/` — organized by system or topic, referenced by tasks when relevant.

If these artifacts do not exist, stop and tell the user to run `plan-eng-tasks` first.

## Engineering preferences (included in sub-agent prompts)

Read `skills/shared/ENGINEERING_PREFERENCES.md` and include its contents in every sub-agent prompt.

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

## Step 3: Create feature branch

Before dispatching any work, create a single feature branch that will collect all task results:

1. Record the current branch as the **target branch** (usually `main`): `git branch --show-current`.
2. Create and check out the feature branch: `git checkout -b epic/<EPIC_NAME>`.
3. Push the branch so it exists on the remote: `git push -u origin epic/<EPIC_NAME>`.

All sub-agent worktrees will branch off this feature branch. All completed work merges back into it.

## Step 4: Dispatch sub-agents

For each approved task (respecting dependency order), spawn a sub-agent using the Agent tool:

**Sub-agent configuration:**
* **Model:** `sonnet` — use the `model` parameter on the Agent tool.
* **Prompt construction:** Read the task file and construct a prompt that includes:
  1. The full task file content (Goal, Context, Implementation sections, Acceptance criteria).
  2. Any relevant context from readiness (constraints, decisions, engineering preferences, ASCII diagrams).
  3. The sub-agent behavioral rules below.
* **Parallelism:** Tasks with no unresolved dependencies SHOULD run in parallel. Use `run_in_background: true` for all tasks in a parallel group except the last one, so you can monitor completion. When a group finishes, dispatch the next group.
* **Isolation:** Use `isolation: "worktree"` so each sub-agent works on an isolated copy and can't conflict with others.

**Sub-agent behavioral rules:** Read `skills/shared/SUB_AGENT_RULES.md` and include its contents verbatim in every sub-agent prompt.

## Step 5: Monitor and merge into feature branch

As sub-agents complete (or get stuck):

**On success:** The sub-agent will have committed its changes in the worktree. The agent result includes the **worktree path** and **branch name**. Review the sub-agent's output summary. Check:
- Did it touch only the expected files?
- Did it write the required tests?
- Any deviations — are they justified?

If the work looks good, **squash-merge the worktree branch into the feature branch:**

```bash
git merge --squash <worktree-branch> && git commit -m "<task-filename>: <brief summary of changes>"
```

**Minimize approval prompts — avoid `cd <path> && git` patterns.**
Compound commands that combine `cd` with `git` trigger a security approval ("bare repository attacks"). To avoid this:
- **Use `git -C <path>` instead of `cd <path> && git ...`** for all git operations in worktrees or other directories. For example: `git -C <worktree> log --oneline -5` instead of `cd <worktree> && git log --oneline -5`.
- **Chain related `git -C` commands** with `&&` to reduce the total number of Bash calls.
- For non-git commands that must run in a specific directory (e.g. test runners), use a subshell: `(cd <path> && bun test ...)`.

**After squash-merging each worktree branch in a parallel group:**
1. Squash-merge: `git merge --squash <worktree-branch> && git commit -m "<task-filename>: <summary>"`.
2. If there are merge conflicts, resolve them using context from both task files, then complete the commit.
3. Repeat until all branches in the group are merged into the feature branch.

**Before dispatching the next dependency group**, verify the feature branch has all previous group changes merged. The new worktrees will branch from the current state of the feature branch.

**On failure or questions:** Act as the engineering manager. Use context from the planning phase to answer the sub-agent's question or unblock it. You have full context on:
- Architecture decisions and their rationale
- Engineering preferences
- The dependency graph and how tasks fit together
- Edge cases and failure modes discussed in the review

**Escalation rule:** Only escalate to the user (via AskUserQuestion) if:
1. The sub-agent hit a problem that wasn't covered in the review, AND
2. You genuinely cannot determine the right answer from the codebase and review context.
When escalating, explain what the sub-agent tried, what went wrong, and present options — don't just pass through a raw error.

## Step 6: Push feature branch and open pull request

After all sub-agents have completed and their branches are merged into the feature branch:

1. Push the feature branch: `git push origin epic/<EPIC_NAME>`.
2. Create a single pull request against the target branch (recorded in Step 3):

```bash
gh pr create --base <target-branch> --title "<Epic title>" --body "$(cat <<'EOF'
## Summary
<1-3 sentence summary of the epic's goal>

## Tasks completed
- [x] <task-1> — <brief description>
- [x] <task-2> — <brief description>
- [!] <task-3> — <failure reason, if any>

## Files modified
- path/to/file.rb (tasks 1, 2)
- path/to/other.js (task 3)

## Test plan
- [ ] <commands to run the test suite for changed files>
- [ ] <any manual verification steps>
EOF
)"
```

## Step 7: Update task files and execution summary

After the PR is created, **update every task file and the epic to reflect the current state:**

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
- If implementation discoveries changed boundaries, data flow, rollout behavior, or key tradeoffs, update the relevant docs in `docs/architecture/` in the same cycle.
- Keep diagrams in `docs/architecture/` consistent with the final implementation and EPIC decisions.
- If no architecture changes were discovered, state that explicitly in the execution summary.

**Reading existing epics:** When scanning an epic's directory to understand current work, **skip the `_closed/` subdirectory entirely.** Only look inside `_closed/` if the user explicitly asks to review closed or cancelled tasks.

Then present the execution summary:

```
EXECUTION COMPLETE
==================

Feature branch: epic/<EPIC_NAME>
Pull request:   <PR URL>

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

**Commit and push the bookkeeping changes** on the feature branch: `git add tasks/ docs/ && git commit -m 'chore: update task/epic status after execution' && git push origin epic/<EPIC_NAME>`.

Then use AskUserQuestion:
> "All tasks are complete. The PR is ready for review. What next?"
> **A) Run the test suite** — verify everything works together.
> **B) Review changes** — I'll walk you through the combined diff.
> **C) Done** — PR is open; no further action needed.
