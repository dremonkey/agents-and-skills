---
name: orchestrate-initiative-planning
version: 1.0.0
description: |
  Orchestrates a multi-stage planning workflow across plan-ceo-review,
  plan-cto-review, draft-technical-architecture, and plan-eng-tasks. Use when
  turning a PRD or initiative into vision docs, architecture docs, EPICs, and
  task files without implementing code. After planning, use exec-eng-tasks to
  dispatch implementation.
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
  - Bash
  - Task
  - AskUserQuestion
  - EnterWorktree
---

# Orchestrate Initiative Planning

## Purpose
Use this skill when the user wants one agent to coordinate the full planning pipeline:

1. Product definition
2. Technical architecture
3. Execution planning

This skill is an orchestrator. It should launch sub-agents, manage handoffs, answer sub-agent questions when possible, and stop before implementation.

## Workspace Isolation

**All work MUST happen in a git worktree.**

Before doing anything else — before reading source docs, before launching sub-agents — enter a worktree:

1. Use `EnterWorktree` with a name derived from the initiative (e.g., `plan-<INITIATIVE>`).
2. All subsequent file creation and sub-agent work happens inside the worktree.
3. Do **not** write any planning artifacts to the main working tree.

If `EnterWorktree` fails (e.g., already in a worktree), halt and ask the user how to proceed.

## Artifact Contract
The orchestrated workflow should produce:

1. Product artifacts in `tasks/<EPIC_NAME>/`
   - `VISION.md` (large initiatives only)
   - `PRD.<TOPIC>.md`
2. Top-level `VISION.md` update — high-level entry capturing the initiative's intent (large initiatives only)
3. Architecture docs in `docs/architecture/` — organized by system or topic, not by initiative
4. Execution artifacts in `tasks/<EPIC_NAME>/`
   - `EPIC.md`
   - task files

## Core Rule
Do not implement product code in this workflow.

`plan-eng-tasks` is planning-only — it produces task files but does not implement them. When execution is needed after planning, use `exec-eng-tasks` to dispatch sub-agents for implementation.

In this orchestrated workflow, `plan-eng-tasks` produces:
- updated `EPIC.md`
- task files
- any required architecture doc clarifications

It does not dispatch implementation sub-agents or write code. If the user wants to proceed to execution after the planning PR is merged, invoke `exec-eng-tasks` separately.

## Stage Workflow

### Stage 1: CEO Product Review
Launch a sub-agent that applies `plan-ceo-review`.

Its job:
- review and improve the source PRD or planning doc
- refine ICP, problem, value proposition, positioning, metrics, and launch narrative
- create or update:
  - `tasks/<EPIC_NAME>/VISION.md` (large initiatives)
  - `tasks/<EPIC_NAME>/PRD.<TOPIC>.md`
  - top-level `VISION.md` with a high-level entry for the initiative (large initiatives)

Stage 1 is complete only when the required product artifacts exist and are updated.

### Stage 2: CTO Technical Review
After Stage 1 completes, launch a new sub-agent that applies `plan-cto-review`.

Its inputs:
- `tasks/<EPIC_NAME>/VISION.md` (if exists)
- relevant `tasks/<EPIC_NAME>/PRD.<TOPIC>.md`

Its job:
- review the initiative from a technical perspective
- update or create architecture docs in `docs/architecture/` (organized by system or topic, not by initiative)
- create one or more EPICs in `tasks/<EPIC_NAME>/EPIC.md`

When architecture drafting is needed, instruct the sub-agent to use `draft-technical-architecture`.

Stage 2 is complete only when architecture docs and initial EPICs exist.

### Stage 3: Engineering Task Planning
After Stage 2 completes, launch a separate sub-agent for each newly created EPIC.

Each sub-agent applies `plan-eng-tasks`.

**Scope is already locked.** The orchestrator confirmed scope in Stages 1-2. Instruct each sub-agent to skip Step 0 (Scope Challenge) and begin directly at the readiness sections. Include this directive in the sub-agent prompt: `SKIP_STEP_0=true — scope was locked by the orchestrator during initiative planning. Do not re-challenge scope.`

Each sub-agent consumes:
- the relevant docs in `docs/architecture/`
- the relevant `tasks/<EPIC_NAME>/EPIC.md`

Its job:
- review the EPIC for execution readiness
- update the EPIC if needed
- create or refine task files under `tasks/<EPIC_NAME>/`
- update architecture docs only when execution-planning discoveries require clarification

Stop condition:
- no code changes
- no implementation sub-agents
- no execution approval step
- planning artifacts only

Run these EPIC-planning sub-agents in parallel only when the EPICs are independent and will not create conflicting task boundaries.

### Stage 4: Push and Open PR

After all planning stages complete, deliver the artifacts:

1. Stage all new and modified files in the worktree.
2. Create a commit with a clear message summarizing the planning artifacts produced (e.g., `plan(<INITIATIVE>): add vision, architecture, and task artifacts`).
3. Push the worktree branch to the remote with `git push -u origin <branch>`.
4. Open a pull request using `gh pr create`:
   - Title: `plan(<INITIATIVE>): initiative planning artifacts`
   - Body must include:
     - Summary of artifacts created (vision docs, architecture docs, EPICs, task files)
     - List of unresolved decisions or remaining risks
     - Note that this is a **planning-only** PR — no product code changes
5. Return the PR URL to the user.

If the push or PR creation fails, report the error and the branch name so the user can recover manually.

## Orchestrator Behavior

### Answering Questions
You should answer sub-agent questions directly when possible.

Escalate to the user only when:
- the sub-agent is genuinely blocked
- the answer cannot be resolved from existing artifacts or repository context
- the decision is strategic or high-impact enough to require user input

When escalating, summarize:
- what stage is blocked
- what the sub-agent is deciding
- your recommended option

### Handoff Discipline
Before starting each stage:
1. Verify the previous stage's required artifacts exist.
2. Summarize the prior stage in 3-5 bullets.
3. Pass those artifacts explicitly into the next sub-agent's prompt.

### Traceability
Maintain this chain:

- PRD requirement -> Architecture decision -> EPIC -> task file

Call out gaps when:
- an EPIC has no PRD anchor
- a task has no EPIC anchor
- architecture work is not justified by product artifacts

## Kickoff Template
Use this structure when the user asks to run the full workflow:

```text
Act as the orchestration agent for a 4-stage planning workflow. Use the installed
skills to move from product definition -> technical architecture -> execution
planning -> delivery.

STAGE 0: WORKTREE SETUP
1. Use EnterWorktree with name `plan-<INITIATIVE>` to create an isolated worktree.
2. All subsequent work happens inside the worktree.
3. If worktree creation fails, stop and ask me how to proceed.

STAGE 1: CEO PRODUCT REVIEW
1. Launch a sub-agent and have it apply `/plan-ceo-review` to review and improve
   <SOURCE_DOC>.
2. Produce:
   - `tasks/<EPIC_NAME>/VISION.md` (large initiatives)
   - `tasks/<EPIC_NAME>/PRD.<TOPIC>.md`
   - Update top-level `VISION.md` with high-level intent (large initiatives)
3. Answer the sub-agent's questions when possible.
4. Only escalate to me when genuinely blocked.
5. Do not move to Stage 2 until the product artifacts are updated.

STAGE 2: CTO TECHNICAL REVIEW
1. Launch a new sub-agent and have it apply `/plan-cto-review`.
2. Inputs:
   - `tasks/<EPIC_NAME>/VISION.md` (if exists)
   - `tasks/<EPIC_NAME>/PRD.<TOPIC>.md`
3. Produce:
   - updated or new docs in `docs/architecture/` (by system/topic, not initiative)
   - one or more EPICs in `tasks/<EPIC_NAME>/EPIC.md`
4. Use `/draft-technical-architecture` when helpful.
5. Answer the sub-agent's questions when possible.
6. Do not move to Stage 3 until the architecture docs and EPICs exist.

STAGE 3: ENGINEERING TASK PLANNING
1. Launch a separate sub-agent for each EPIC.
2. Have each sub-agent apply `/plan-eng-tasks`.
3. Tell each sub-agent: `SKIP_STEP_0=true — scope was locked by the orchestrator. Do not re-challenge scope.`
4. Inputs:
   - relevant docs in `docs/architecture/`
   - `tasks/<EPIC_NAME>/EPIC.md`
5. Produce:
   - updated EPICs
   - task files
   - architecture doc clarifications only if needed
6. IMPORTANT: Do not implement anything.
7. Stop after planning artifacts are complete.

STAGE 4: PUSH AND OPEN PR
1. Stage and commit all planning artifacts.
2. Push the worktree branch to origin.
3. Open a PR with `gh pr create`.
4. Include in the PR body: artifacts created, unresolved decisions, and a note
   that this is a planning-only PR with no product code.
5. Return the PR URL to me.

ORCHESTRATION RULES
- Maintain path discipline:
  - Product artifacts in `tasks/<EPIC_NAME>/` (VISION.md, PRDs)
  - Architecture docs in `docs/architecture/` (by system/topic)
  - Execution artifacts in `tasks/<EPIC_NAME>/` (EPIC, task files)
- Preserve traceability from product -> architecture -> execution.
- Answer sub-agent questions directly when possible.
- Escalate only when genuinely blocked.
- Run Stage 3 in parallel only when EPICs are independent.
- End with a concise summary of artifacts created, unresolved decisions, EPICs,
  task files, and remaining risks.
```

## Final Output
At the end of the orchestrated workflow, return:

1. PR URL
2. Branch name
3. Artifacts created or updated
4. EPICs produced
5. Task files produced
6. Unresolved decisions
7. Remaining risks or gaps
