---
name: orchestrate-initiative-planning
version: 1.0.0
description: |
  Orchestrates a multi-stage planning workflow across plan-ceo-review,
  plan-cto-review, draft-technical-architecture, and plan-eng-tasks. Use when
  turning a PRD or initiative into vision docs, architecture docs, EPICs, and
  task files without implementing code.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Task
  - AskUserQuestion
---

# Orchestrate Initiative Planning

## Purpose
Use this skill when the user wants one agent to coordinate the full planning pipeline:

1. Product definition
2. Technical architecture
3. Execution planning

This skill is an orchestrator. It should launch sub-agents, manage handoffs, answer sub-agent questions when possible, and stop before implementation.

## Artifact Contract
The orchestrated workflow should produce:

1. Product artifacts in `vision/<INITIATIVE>/`
   - `VISION.md`
   - `PRD.<TOPIC>.md`
2. Architecture artifacts in `docs/architecture/<INITIATIVE>/`
3. Execution artifacts in `tasks/<EPIC_NAME>/`
   - `EPIC.md`
   - task files

## Core Rule
Do not implement product code in this workflow.

`plan-eng-tasks` normally has an execution phase. In this orchestrated workflow, it must stop after producing planning artifacts:
- updated `EPIC.md`
- task files
- any required architecture doc clarifications

It must not dispatch implementation sub-agents or write code.

## Stage Workflow

### Stage 1: CEO Product Review
Launch a sub-agent that applies `plan-ceo-review`.

Its job:
- review and improve the source PRD or planning doc
- refine ICP, problem, value proposition, positioning, metrics, and launch narrative
- create or update:
  - `vision/<INITIATIVE>/VISION.md`
  - `vision/<INITIATIVE>/PRD.<TOPIC>.md`

Stage 1 is complete only when the required product artifacts exist and are updated.

### Stage 2: CTO Technical Review
After Stage 1 completes, launch a new sub-agent that applies `plan-cto-review`.

Its inputs:
- `vision/<INITIATIVE>/VISION.md`
- relevant `vision/<INITIATIVE>/PRD.<TOPIC>.md`

Its job:
- review the initiative from a technical perspective
- create or update architecture docs in `docs/architecture/<INITIATIVE>/`
- create one or more EPICs in `tasks/<EPIC_NAME>/EPIC.md`

When architecture drafting is needed, instruct the sub-agent to use `draft-technical-architecture`.

Stage 2 is complete only when architecture docs and initial EPICs exist.

### Stage 3: Engineering Task Planning
After Stage 2 completes, launch a separate sub-agent for each newly created EPIC.

Each sub-agent applies `plan-eng-tasks`.

Each sub-agent consumes:
- the relevant docs in `docs/architecture/<INITIATIVE>/`
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

- Vision claim -> PRD requirement -> Architecture decision -> EPIC -> task file

Call out gaps when:
- an EPIC has no PRD anchor
- a task has no EPIC anchor
- architecture work is not justified by product artifacts

## Kickoff Template
Use this structure when the user asks to run the full workflow:

```text
Act as the orchestration agent for a 3-stage planning workflow. Use the installed
skills to move from product definition -> technical architecture -> execution
planning.

STAGE 1: CEO PRODUCT REVIEW
1. Launch a sub-agent and have it apply `/plan-ceo-review` to review and improve
   <SOURCE_DOC>.
2. Produce:
   - `vision/<INITIATIVE>/VISION.md`
   - `vision/<INITIATIVE>/PRD.<TOPIC>.md`
3. Answer the sub-agent's questions when possible.
4. Only escalate to me when genuinely blocked.
5. Do not move to Stage 2 until the product artifacts are updated.

STAGE 2: CTO TECHNICAL REVIEW
1. Launch a new sub-agent and have it apply `/plan-cto-review`.
2. Inputs:
   - `vision/<INITIATIVE>/VISION.md`
   - `vision/<INITIATIVE>/PRD.<TOPIC>.md`
3. Produce:
   - docs in `docs/architecture/<INITIATIVE>/`
   - one or more EPICs in `tasks/<EPIC_NAME>/EPIC.md`
4. Use `/draft-technical-architecture` when helpful.
5. Answer the sub-agent's questions when possible.
6. Do not move to Stage 3 until the architecture docs and EPICs exist.

STAGE 3: ENGINEERING TASK PLANNING
1. Launch a separate sub-agent for each EPIC.
2. Have each sub-agent apply `/plan-eng-tasks`.
3. Inputs:
   - `docs/architecture/<INITIATIVE>/`
   - `tasks/<EPIC_NAME>/EPIC.md`
4. Produce:
   - updated EPICs
   - task files
   - architecture doc clarifications only if needed
5. IMPORTANT: Do not implement anything.
6. Stop after planning artifacts are complete.

ORCHESTRATION RULES
- Maintain path discipline:
  - `vision/<INITIATIVE>/...`
  - `docs/architecture/<INITIATIVE>/...`
  - `tasks/<EPIC_NAME>/...`
- Preserve traceability from product -> architecture -> execution.
- Answer sub-agent questions directly when possible.
- Escalate only when genuinely blocked.
- Run Stage 3 in parallel only when EPICs are independent.
- End with a concise summary of artifacts created, unresolved decisions, EPICs,
  task files, and remaining risks.
```

## Final Output
At the end of the orchestrated workflow, return:

1. Artifacts created or updated
2. EPICs produced
3. Task files produced
4. Unresolved decisions
5. Remaining risks or gaps
