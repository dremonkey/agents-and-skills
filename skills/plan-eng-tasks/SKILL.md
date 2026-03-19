---
name: plan-eng-tasks
version: 3.0.0
description: |
  Eng manager-mode execution planning. Converts approved scope into a
  dependency-aware task plan and generates task files. Uses plan-cto-review
  outputs when available instead of re-running deep technical diligence.
  Planning only — use exec-eng-tasks to dispatch implementation.
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

# Execution Readiness Planning

This skill prepares an approved plan for execution: scope challenge, resolve decisions, and produce executable task decomposition. **No code changes.** When planning is complete, use `exec-eng-tasks` to dispatch implementation.

---

## EXECUTION READINESS

Prepare an approved plan for execution before making any code changes. Focus on dependency-safe task decomposition, owner clarity, and execution sequencing. Do not re-run deep architecture/security/performance diligence if `plan-cto-review` outputs already exist.

## Relationship to `plan-cto-review`
`plan-cto-review` is the technical quality gate. This skill is the execution manager.

When CTO outputs exist, ingest and use them as inputs:
1. Decision Summary
2. Technical Risk Register
3. Failure Modes Registry
4. Top Gaps
5. Implementation Readiness Verdict

Do not duplicate that full review. Only re-open a technical topic if:
- a gap is unresolved,
- scope changed materially after CTO review, or
- a new blocker appears during decomposition.

## Artifact Contract
This skill's primary artifacts are:
1. **Modified EPIC(s)** - update existing EPIC documents in `tasks/<EPIC_NAME>` from CTO review to reflect final execution sequencing and decisions.
2. **Clearly defined task files** - concrete, dependency-aware implementation tasks derived from EPIC scope.
3. **Updated architecture docs (when needed)** - capture implementation details discovered during execution that materially change or clarify architecture in `docs/architecture/<INITIATIVE>`.

## Priority hierarchy
If you are running low on context or the user asks you to compress: Step 0 > dependency/task decomposition > approval-ready execution plan > everything else. Never skip Step 0.

## My engineering preferences (use these to guide your recommendations):
Read `skills/shared/ENGINEERING_PREFERENCES.md` for the full list. Use these preferences to guide all recommendations and map your reasoning to specific preferences when explaining WHY.

## Documentation and diagrams:
* I value ASCII art diagrams highly — for data flow, state machines, dependency graphs, processing pipelines, and decision trees. Use them liberally in plans and design docs.
* For particularly complex designs or behaviors, embed ASCII diagrams directly in code comments in the appropriate places: Models (data relationships, state transitions), Controllers (request flow), Concerns (mixin behavior), Services (processing pipelines), and Tests (what's being set up and why) when the test structure is non-obvious.
* **Diagram maintenance is part of the change.** When modifying code that has ASCII diagrams in comments nearby, review whether those diagrams are still accurate. Update them as part of the same commit. Stale diagrams are worse than no diagrams — they actively mislead. Flag any stale diagrams you encounter during review even if they're outside the immediate scope of the change.

## BEFORE YOU START:

### Step 0: Scope Challenge
**If `SKIP_STEP_0=true` was set by the orchestrator, skip this entire step and proceed to the readiness sections.** Scope was already locked during initiative planning.

Before reviewing anything, answer these questions:
1. **What existing code already partially or fully solves each sub-problem?** Can we capture outputs from existing flows rather than building parallel ones?
2. **What is the minimum set of changes that achieves the stated goal?** Flag any work that could be deferred without blocking the core objective. Be ruthless about scope creep.
3. **Complexity check:** If the plan touches more than 8 files or introduces more than 2 new classes/services, treat that as a smell and challenge whether the same goal can be achieved with fewer moving parts.

Then ask if I want one of three options:
1. **SCOPE REDUCTION:** The plan is overbuilt. Propose a minimal version that achieves the core goal, then review that.
2. **BIG CHANGE:** Work through interactively, one section at a time (CTO handoff alignment → decomposition and dependencies → test/rollout readiness) with at most 8 top issues per section.
3. **SMALL CHANGE:** Compressed pass — Step 0 + one combined pass across the 3 sections above. Pick the single highest-leverage issue per section and finish with a completion summary. One AskUserQuestion round at the end.

**Critical: If I do not select SCOPE REDUCTION, respect that decision fully.** Your job becomes making the plan I chose succeed, not continuing to lobby for a smaller plan. Raise scope concerns once in Step 0 — after that, commit to my chosen scope and optimize within it. Do not silently reduce scope, skip planned components, or re-argue for less work during later review sections.

## Readiness Sections (after scope is agreed)

### 1. CTO handoff alignment
If a CTO review exists, map its outputs into execution constraints:
* Convert each **Top Gap** into either: (a) required precondition, (b) dedicated task, or (c) explicit deferral.
* Ensure each high-severity risk in the **Technical Risk Register** has a named mitigation task or acceptance decision.
* Ensure each critical entry in the **Failure Modes Registry** is covered by tests, handling work, or a clear non-goal.
* If no CTO review exists, run only a lightweight sanity pass to identify blockers for decomposition (do not do a full technical diligence pass).

**STOP.** Batch issues from this section into AskUserQuestion calls — up to 3-5 issues per call, grouped by theme. Each issue still needs its own numbered entry with lettered options, a recommendation, and a WHY. Only proceed to the next section after ALL issues in this section are resolved.

### 2. Task decomposition and dependency graph
Evaluate:
* Is every work item atomic enough for one sub-agent session?
* Are dependencies explicit and acyclic?
* Do tasks avoid conflicting edits to the same files?
* Are there hidden cross-cutting tasks (migrations, feature flags, data backfills, docs)?
* Is each task scoped to minimal diff while still satisfying acceptance criteria?
* Are existing ASCII diagrams in touched files still accurate after proposed changes?

**STOP.** Batch issues from this section into AskUserQuestion calls — up to 3-5 issues per call, grouped by theme. Each issue still needs its own numbered entry with lettered options, a recommendation, and a WHY. Only proceed to the next section after ALL issues in this section are resolved.

### 3. Test and rollout readiness
Build an execution-readiness checklist:
* Make a diagram of all new UX, new data flow, new codepaths, and new branching outcomes.
* Ensure each new path has explicit test ownership in one task file.
* Map rollout controls (flags, migrations, sequencing, rollback checks) into tasks.
* Ensure observability essentials (logs/metrics/alerts) are assigned to specific tasks if required by CTO outputs.

For LLM/prompt changes: check the "Prompt/LLM changes" file patterns listed in CLAUDE.md. If this plan touches ANY of those patterns, state which eval suites must be run, which cases should be added, and what baselines to compare against. Then use AskUserQuestion to confirm the eval scope with the user.

**STOP.** Batch issues from this section into AskUserQuestion calls — up to 3-5 issues per call, grouped by theme. Each issue still needs its own numbered entry with lettered options, a recommendation, and a WHY. Only proceed to the next section after ALL issues in this section are resolved.

## CRITICAL RULE — How to ask questions
Batch up to 3-5 related issues into a single AskUserQuestion call, grouped by section or theme. Each issue within the batch MUST: (1) have its own numbered entry, (2) present 2-3 concrete lettered options, (3) state which option you recommend FIRST, (4) explain in 1-2 sentences WHY that option over the others, mapping to engineering preferences. No yes/no questions. Open-ended questions are allowed ONLY when you have genuine ambiguity about developer intent, architecture direction, 12-month goals, or what the end user wants — and you must explain what specifically is ambiguous. **Exception:** SMALL CHANGE mode batches all issues into a single AskUserQuestion at the end — but each issue in that batch still requires its own recommendation + WHY + lettered options.

## For each issue you find
For every specific issue (bug, smell, design concern, or risk):
* **Batch issues into AskUserQuestion calls** — up to 3-5 per call, grouped by theme. Each issue still gets its own numbered entry.
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
After all readiness sections are complete, break the approved plan into discrete, implementable tasks. Each task becomes a markdown file.

**Task management strategy:** Use `tasks/<EPIC_NAME>` as the canonical location for epic and task files. Do not use alternate directory structures unless the user explicitly requests an override.

**Closed tasks directory:** Tasks that are completely done (`[x]`) or cancelled should be moved into a `_closed/` subdirectory within the epic (e.g., `tasks/<EPIC_NAME>/_closed/<task>.md`). This keeps the epic directory clean — only active/pending work is visible at a glance. When reviewing or listing tasks, **ignore everything in `_closed/`** unless the user explicitly asks to check closed tasks.

**Task file format:** Use the template in `TASK_TEMPLATE.md` (same directory as this skill file). Read it before generating task files. Key points:
- Title: `# Task <NUM>: <Title>` — number tasks sequentially within the epic.
- Flat header fields for epic, status, dependencies (not nested under H2s).
- `## Goal` (not "Description"), `## Context` (background + technical notes), `## Implementation` (numbered sub-sections with file paths), `## Acceptance criteria` (checkboxes).
- Status uses `[ ]` pending, `[~]` in progress, `[x]` done, `[!]` failed/blocked.

**Rules for task decomposition:**
* Each task should be completable by a single sub-agent in one session. If a task is "large", consider splitting it.
* Tasks must have clear boundaries — no two tasks should modify the same file in conflicting ways. If unavoidable, make one block the other.
* Order tasks by dependency graph. Tasks with no dependencies come first.
* Present all proposed tasks in a single AskUserQuestion for batch approval. For each task, show: number, title, size estimate, and dependencies. Then offer:
  **A)** Approve all tasks as shown.
  **B)** Select/deselect individual tasks — list the numbers to change.
  **C)** Edit — describe what to merge, split, or re-scope.
  Never silently skip this approval step.

**Update the EPIC file first when it already exists.** If no epic exists yet, create `tasks/<EPIC_NAME>/EPIC.md` using `EPIC_TEMPLATE.md` (same directory as this skill file). The epic is the source of truth for goal, architecture overview, task list summaries, key decisions, and anti-goals. Finalize/update it after task files are written so the task list is complete.

**Deferred work becomes task files too.** For each item from the "NOT in scope" section that has future value, create a task file using the same template. Mark its status as `[ ]` (pending) and add a `## Deferred` section explaining: **Why deferred** (rationale), **Revisit when** (trigger condition or timeframe). These live alongside the other task files in the epic — they're just not part of the current execution plan. **Cross-reference:** Add the deferred task to the `## Relates to` section of the original task that surfaced it, and vice versa, so the connection is traceable in both directions.

### Diagrams
The plan itself should use ASCII diagrams for any non-trivial data flow, state machine, or processing pipeline. Additionally, identify which files in the implementation should get inline ASCII diagram comments — particularly Models with complex state transitions, Services with multi-step pipelines, and Concerns with non-obvious mixin behavior.

### Failure modes
For each new codepath identified in the test/rollout readiness diagram, list one realistic way it could fail in production (timeout, nil reference, race condition, stale data, etc.) and whether:
1. A test covers that failure
2. Error handling exists for it
3. The user would see a clear error or a silent failure

If any failure mode has no test AND no error handling AND would be silent, flag it as a **critical gap**.

### Commit planning artifacts
After all task files, the epic, and any architecture docs have been written or updated, **commit them** with a descriptive message (e.g., `plan: <EPIC_NAME> — create epic and N task files`). Push to the remote. This ensures planning artifacts are versioned and available to `exec-eng-tasks` sub-agents working in worktrees.

### Completion summary
At the end of readiness, fill in and display this summary so the user can see all findings at a glance:
- Step 0: Scope Challenge (user chose: ___)
- CTO handoff alignment: ___ issues found
- Task decomposition/dependencies: ___ issues found
- Test/rollout readiness: diagram produced, ___ gaps identified
- NOT in scope: written
- What already exists: written
- Epic file: created at tasks/<EPIC_NAME>/EPIC.md
- Task files: ___ created, ___ skipped
- Deferred tasks: ___ created
- Failure modes: ___ critical gaps flagged
- Artifacts committed: yes/no

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

## Next step: Execution

When planning is complete, use `exec-eng-tasks` to dispatch sub-agents and implement the task files produced by this skill.
