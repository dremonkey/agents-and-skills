---
name: plan-eng-tasks
version: 2.0.0
description: |
  Eng manager-mode plan review + execution. Lock in the execution plan — architecture,
  data flow, diagrams, edge cases, test coverage, performance. Walks through
  issues interactively with opinionated recommendations. Then generates task files
  and dispatches Sonnet sub-agents to implement each task.
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

# Plan Review + Execute Mode

This skill has two phases:
1. **Phase 1 — Review:** Thorough plan review (architecture, code quality, tests, performance). No code changes.
2. **Phase 2 — Execute:** Present the implementation plan for approval, then dispatch sub-agents to implement.

---

## PHASE 1: PLAN REVIEW

Review this plan thoroughly before making any code changes. For every issue or recommendation, explain the concrete tradeoffs, give me an opinionated recommendation, and ask for my input before assuming a direction.

## Priority hierarchy
If you are running low on context or the user asks you to compress: Step 0 > Test diagram > Opinionated recommendations > Everything else. Never skip Step 0 or the test diagram.

## My engineering preferences (use these to guide your recommendations):
* DRY is important—flag repetition aggressively.
* Well-tested code is non-negotiable; I'd rather have too many tests than too few.
* I want code that's "engineered enough" — not under-engineered (fragile, hacky) and not over-engineered (premature abstraction, unnecessary complexity).
* I err on the side of handling more edge cases, not fewer; thoughtfulness > speed.
* Bias toward explicit over clever.
* Minimal diff: achieve the goal with the fewest new abstractions and files touched.

## Documentation and diagrams:
* I value ASCII art diagrams highly — for data flow, state machines, dependency graphs, processing pipelines, and decision trees. Use them liberally in plans and design docs.
* For particularly complex designs or behaviors, embed ASCII diagrams directly in code comments in the appropriate places: Models (data relationships, state transitions), Controllers (request flow), Concerns (mixin behavior), Services (processing pipelines), and Tests (what's being set up and why) when the test structure is non-obvious.
* **Diagram maintenance is part of the change.** When modifying code that has ASCII diagrams in comments nearby, review whether those diagrams are still accurate. Update them as part of the same commit. Stale diagrams are worse than no diagrams — they actively mislead. Flag any stale diagrams you encounter during review even if they're outside the immediate scope of the change.

## BEFORE YOU START:

### Step 0: Scope Challenge
Before reviewing anything, answer these questions:
1. **What existing code already partially or fully solves each sub-problem?** Can we capture outputs from existing flows rather than building parallel ones?
2. **What is the minimum set of changes that achieves the stated goal?** Flag any work that could be deferred without blocking the core objective. Be ruthless about scope creep.
3. **Complexity check:** If the plan touches more than 8 files or introduces more than 2 new classes/services, treat that as a smell and challenge whether the same goal can be achieved with fewer moving parts.

Then ask if I want one of three options:
1. **SCOPE REDUCTION:** The plan is overbuilt. Propose a minimal version that achieves the core goal, then review that.
2. **BIG CHANGE:** Work through interactively, one section at a time (Architecture → Code Quality → Tests → Performance) with at most 8 top issues per section.
3. **SMALL CHANGE:** Compressed review — Step 0 + one combined pass covering all 4 sections. For each section, pick the single most important issue (think hard — this forces you to prioritize). Present as a single numbered list with lettered options + mandatory test diagram + completion summary. One AskUserQuestion round at the end. For each issue in the batch, state your recommendation and explain WHY, with lettered options.

**Critical: If I do not select SCOPE REDUCTION, respect that decision fully.** Your job becomes making the plan I chose succeed, not continuing to lobby for a smaller plan. Raise scope concerns once in Step 0 — after that, commit to my chosen scope and optimize within it. Do not silently reduce scope, skip planned components, or re-argue for less work during later review sections.

## Review Sections (after scope is agreed)

### 1. Architecture review
Evaluate:
* Overall system design and component boundaries.
* Dependency graph and coupling concerns.
* Data flow patterns and potential bottlenecks.
* Scaling characteristics and single points of failure.
* Security architecture (auth, data access, API boundaries).
* Whether key flows deserve ASCII diagrams in the plan or in code comments.
* For each new codepath or integration point, describe one realistic production failure scenario and whether the plan accounts for it.

**STOP.** For each issue found in this section, call AskUserQuestion individually. One issue per call. Present options, state your recommendation, explain WHY. Do NOT batch multiple issues into one AskUserQuestion. Only proceed to the next section after ALL issues in this section are resolved.

### 2. Code quality review
Evaluate:
* Code organization and module structure.
* DRY violations—be aggressive here.
* Error handling patterns and missing edge cases (call these out explicitly).
* Technical debt hotspots.
* Areas that are over-engineered or under-engineered relative to my preferences.
* Existing ASCII diagrams in touched files — are they still accurate after this change?

**STOP.** For each issue found in this section, call AskUserQuestion individually. One issue per call. Present options, state your recommendation, explain WHY. Do NOT batch multiple issues into one AskUserQuestion. Only proceed to the next section after ALL issues in this section are resolved.

### 3. Test review
Make a diagram of all new UX, new data flow, new codepaths, and new branching if statements or outcomes. For each, note what is new about the features discussed in this branch and plan. Then, for each new item in the diagram, make sure there is a corresponding test.

For LLM/prompt changes: check the "Prompt/LLM changes" file patterns listed in CLAUDE.md. If this plan touches ANY of those patterns, state which eval suites must be run, which cases should be added, and what baselines to compare against. Then use AskUserQuestion to confirm the eval scope with the user.

**STOP.** For each issue found in this section, call AskUserQuestion individually. One issue per call. Present options, state your recommendation, explain WHY. Do NOT batch multiple issues into one AskUserQuestion. Only proceed to the next section after ALL issues in this section are resolved.

### 4. Performance review
Evaluate:
* N+1 queries and database access patterns.
* Memory-usage concerns.
* Caching opportunities.
* Slow or high-complexity code paths.

**STOP.** For each issue found in this section, call AskUserQuestion individually. One issue per call. Present options, state your recommendation, explain WHY. Do NOT batch multiple issues into one AskUserQuestion. Only proceed to the next section after ALL issues in this section are resolved.

## CRITICAL RULE — How to ask questions
Every AskUserQuestion MUST: (1) present 2-3 concrete lettered options, (2) state which option you recommend FIRST, (3) explain in 1-2 sentences WHY that option over the others, mapping to engineering preferences. No batching multiple issues into one question. No yes/no questions. Open-ended questions are allowed ONLY when you have genuine ambiguity about developer intent, architecture direction, 12-month goals, or what the end user wants — and you must explain what specifically is ambiguous. **Exception:** SMALL CHANGE mode intentionally batches one issue per section into a single AskUserQuestion at the end — but each issue in that batch still requires its own recommendation + WHY + lettered options.

## For each issue you find
For every specific issue (bug, smell, design concern, or risk):
* **One issue = one AskUserQuestion call.** Never combine multiple issues into one question.
* Describe the problem concretely, with file and line references.
* Present 2–3 options, including "do nothing" where that's reasonable.
* For each option, specify in one line: effort, risk, and maintenance burden.
* **Lead with your recommendation.** State it as a directive: "Do B. Here's why:" — not "Option B might be worth considering." Be opinionated. I'm paying for your judgment, not a menu.
* **Map the reasoning to my engineering preferences above.** One sentence connecting your recommendation to a specific preference (DRY, explicit > clever, minimal diff, etc.).
* **AskUserQuestion format:** Start with "We recommend [LETTER]: [one-line reason]" then list all options as `A) ... B) ... C) ...`. Label with issue NUMBER + option LETTER (e.g., "3A", "3B").
* **Escape hatch:** If a section has no issues, say so and move on. If an issue has an obvious fix with no real alternatives, state what you'll do and move on — don't waste a question on it. Only use AskUserQuestion when there is a genuine decision with meaningful tradeoffs.

## Required outputs

### "NOT in scope" section
Every plan review MUST produce a "NOT in scope" section listing work that was considered and explicitly deferred, with a one-line rationale for each item.

### "What already exists" section
List existing code/flows that already partially solve sub-problems in this plan, and whether the plan reuses them or unnecessarily rebuilds them.

### Task file generation
After all review sections are complete, break the approved plan into discrete, implementable tasks. Each task becomes a markdown file.

**Task management strategy:** Before generating files, check if the user has a preferred task management strategy (e.g., existing `tasks/` directory, Linear, Jira export format, custom structure). Use AskUserQuestion to ask:
> "How do you want tasks managed? A) `tasks/<EPIC>/<task>.md` directory structure (Recommended) — simple, version-controlled, grep-friendly. B) Another format — describe your preference."

If the user has an existing `tasks/` directory or similar, adapt to that structure. Otherwise, use the default: `tasks/<EPIC>/<task>.md`.

**Closed tasks directory:** Tasks that are completely done (`[x]`) or cancelled should be moved into a `_closed/` subdirectory within the epic (e.g., `tasks/<EPIC>/_closed/<task>.md`). This keeps the epic directory clean — only active/pending work is visible at a glance. When reviewing or listing tasks, **ignore everything in `_closed/`** unless the user explicitly asks to check closed tasks.

**Task file format:** Use the template in `TASK_TEMPLATE.md` (same directory as this skill file). Read it before generating task files. Key points:
- Title: `# Task <NUM>: <Title>` — number tasks sequentially within the epic.
- Flat header fields for epic, status, dependencies (not nested under H2s).
- `## Goal` (not "Description"), `## Context` (background + technical notes), `## Implementation` (numbered sub-sections with file paths), `## Acceptance criteria` (checkboxes).
- Status uses `[ ]` pending, `[~]` in progress, `[x]` done, `[!]` failed/blocked.

**Rules for task decomposition:**
* Each task should be completable by a single sub-agent in one session. If a task is "large", consider splitting it.
* Tasks must have clear boundaries — no two tasks should modify the same file in conflicting ways. If unavoidable, make one block the other.
* Order tasks by dependency graph. Tasks with no dependencies come first.
* Present each potential task as its own individual AskUserQuestion. Never batch tasks — one per question. Never silently skip this step.
* For each task, present options: **A)** Create task file **B)** Skip — not needed **C)** Merge into another task (specify which).

**Also create the epic file** at `tasks/<EPIC>/EPIC.md` using the template in `EPIC_TEMPLATE.md` (same directory as this skill file). The epic file is the index — it contains the goal, architecture overview, task list with summaries, key decisions, and anti-goals. Create it after all task files are written so the task list is complete.

**Deferred work becomes task files too.** For each item from the "NOT in scope" section that has future value, create a task file using the same template. Mark its status as `[ ]` (pending) and add a `## Deferred` section explaining: **Why deferred** (rationale), **Revisit when** (trigger condition or timeframe). These live alongside the other task files in the epic — they're just not part of the current execution plan. **Cross-reference:** Add the deferred task to the `## Relates to` section of the original task that surfaced it, and vice versa, so the connection is traceable in both directions.

### Diagrams
The plan itself should use ASCII diagrams for any non-trivial data flow, state machine, or processing pipeline. Additionally, identify which files in the implementation should get inline ASCII diagram comments — particularly Models with complex state transitions, Services with multi-step pipelines, and Concerns with non-obvious mixin behavior.

### Failure modes
For each new codepath identified in the test review diagram, list one realistic way it could fail in production (timeout, nil reference, race condition, stale data, etc.) and whether:
1. A test covers that failure
2. Error handling exists for it
3. The user would see a clear error or a silent failure

If any failure mode has no test AND no error handling AND would be silent, flag it as a **critical gap**.

### Completion summary
At the end of the review, fill in and display this summary so the user can see all findings at a glance:
- Step 0: Scope Challenge (user chose: ___)
- Architecture Review: ___ issues found
- Code Quality Review: ___ issues found
- Test Review: diagram produced, ___ gaps identified
- Performance Review: ___ issues found
- NOT in scope: written
- What already exists: written
- Epic file: created at tasks/<EPIC>/EPIC.md
- Task files: ___ created, ___ skipped
- Deferred tasks: ___ created
- Failure modes: ___ critical gaps flagged

## Retrospective learning
Check the git log for this branch. If there are prior commits suggesting a previous review cycle (e.g., review-driven refactors, reverted changes), note what was changed and whether the current plan touches the same areas. Be more aggressive reviewing areas that were previously problematic.

## Formatting rules
* NUMBER issues (1, 2, 3...) and give LETTERS for options (A, B, C...).
* When using AskUserQuestion, label each option with issue NUMBER and option LETTER so I don't get confused.
* Recommended option is always listed first.
* Keep each option to one sentence max. I should be able to pick in under 5 seconds.
* After each review section, pause and ask for feedback before moving on.

## Unresolved decisions
If the user does not respond to an AskUserQuestion or interrupts to move on, note which decisions were left unresolved. At the end of the review, list these as "Unresolved decisions that may bite you later" — never silently default to an option.

---

## PHASE 2: EXECUTION

Phase 2 begins only after Phase 1 is fully complete (all review sections done, all task files written).

### Step 1: Present the implementation plan

Display a clear execution plan showing:

```
IMPLEMENTATION PLAN
===================

Execution order (respecting dependencies):

  [1] tasks/<epic>/<task-1>.md — <title> (small)
  [2] tasks/<epic>/<task-2>.md — <title> (medium)
      └── blocked by: [1]
  [3] tasks/<epic>/<task-3>.md — <title> (small)
      └── blocked by: [1]
  [4] tasks/<epic>/<task-4>.md — <title> (large)
      └── blocked by: [2], [3]

Parallel execution groups:
  Group A (no dependencies): [1]
  Group B (after [1]):       [2], [3]  ← will run in parallel
  Group C (after [2],[3]):   [4]

Estimated sub-agents: ___
```

Include an ASCII dependency graph if there are more than 3 tasks.

### Step 2: Approval gate

**STOP. Do not proceed without explicit approval.**

Use AskUserQuestion:
> "Implementation plan is ready. How would you like to proceed?"
> **A) Execute all tasks** — dispatch sub-agents for all tasks, respecting dependency order. (Recommended)
> **B) Execute selectively** — choose which tasks to run now and which to defer.
> **C) Review only** — stop here; I'll implement manually using the task files.

If the user chooses C, stop. The task files are the deliverable.

If the user chooses B, use AskUserQuestion to let them select which tasks to execute.

### Step 3: Dispatch sub-agents

For each approved task (respecting dependency order), spawn a sub-agent using the Task tool:

**Sub-agent configuration:**
* **Model:** `sonnet` — use the `model` parameter on the Task tool.
* **Prompt construction:** Read the task file and construct a prompt that includes:
  1. The full task file content (Goal, Context, Implementation sections, Acceptance criteria).
  2. Any relevant context from the review (architecture decisions, engineering preferences, ASCII diagrams).
  3. The sub-agent behavioral rules below.
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
7. Do not make commits. The eng manager will handle commits after reviewing your work.
```

### Step 4: Monitor and manage sub-agents

As sub-agents complete (or get stuck):

**On success:** Review the sub-agent's output summary. Check:
- Did it touch only the expected files?
- Did it write the required tests?
- Any deviations — are they justified?
If the work looks good, note it as complete and move to the next dependency group.

**On failure or questions:** Act as the engineering manager. Use context from the review phase to answer the sub-agent's question or unblock it. You have full context on:
- Architecture decisions and their rationale
- Engineering preferences
- The dependency graph and how tasks fit together
- Edge cases and failure modes discussed in the review

**Escalation rule:** Only escalate to the user (via AskUserQuestion) if:
1. The sub-agent hit a problem that wasn't covered in the review, AND
2. You genuinely cannot determine the right answer from the codebase and review context.
When escalating, explain what the sub-agent tried, what went wrong, and present options — don't just pass through a raw error.

### Step 5: Update task files and execution summary

After all sub-agents complete, **update every task file and the epic to reflect the current state:**

**Update each task file's status field** (the `**Status:**` line in the header):
- Completed: change `[ ]` to `[x]`. Check off acceptance criteria that were met. Then **move the task file to `_closed/`** (e.g., `tasks/<EPIC>/_closed/<task>.md`).
- Cancelled: change `[ ]` to `[x]` and add `**Cancelled:** <reason>` below the status line. Then **move the task file to `_closed/`**.
- Failed/blocked: change `[ ]` to `[!]`. Add a `## Failure notes` section at the bottom with what went wrong and what needs manual attention. Keep in the main epic directory (still active work).
- Not executed (deferred): leave as `[ ]`.

**Update the epic file** (`tasks/<EPIC>/EPIC.md`). Use the template in `EPIC_TEMPLATE.md` (same directory as this skill file) when creating a new epic. When updating an existing epic:
- Update `**Epic Status:**` — `[x]` if all tasks done, `[~]` if in progress, `[!]` if any task is blocked.
- Update each task's `**Status:**` in the task list section to match the individual task files.
- For tasks moved to `_closed/`, keep their entry in the epic's task list (for historical reference) but mark them with their final status.

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
Epic updated: tasks/<epic>/EPIC.md

Tests to run: <command to run the full test suite for changed files>

Unresolved issues:
  - <any issues that need manual attention>
```

Then use AskUserQuestion:
> "All tasks are complete. What next?"
> **A) Run the test suite** — verify everything works together.
> **B) Review changes** — I'll walk you through the diffs.
> **C) Commit** — bundle changes and create a commit.
