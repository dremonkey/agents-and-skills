---
name: plan-cto-review
version: 1.3.0
model: opus
description: |
  CTO-level technical plan review for implementation readiness and risk control.
  Use this skill to deeply review architecture, failure modes, security, tests,
  performance, observability, and rollout posture before execution.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# CTO Technical Plan Review Mode

## Purpose
Use this skill when the plan is already defined at the product level and needs rigorous technical review before implementation.

## Artifact Contract
This skill's primary artifacts are:
1. **Architecture documentation** — update existing docs or create new ones, depending on scope (see Architecture Doc Policy below).
2. **EPIC document(s)** stored in `tasks/<EPIC_NAME>` that define implementation slices, sequencing, and constraints at an execution-planning level.

These artifacts are inputs to `plan-eng-tasks`.

### Architecture Doc Policy
Architecture docs in `docs/architecture/` are a living set of documents that explain how the system is built. They are organized by system or topic, not by initiative or epic.

Before creating architecture artifacts, read the existing docs in `docs/architecture/` and assess whether the change should be integrated into an existing document or warrants a new one:

- **Update existing docs** when the change extends an existing system (e.g., a new pipeline node, a new adapter, a new handler). Find the doc that describes that system and add the new component to its diagrams, flow descriptions, and component list.
- **Create a new doc** at `docs/architecture/<SYSTEM_OR_TOPIC>.md` only when the change introduces a genuinely new subsystem, a new cross-cutting concern, or a new architectural boundary that doesn't fit naturally into any existing doc. Name it after the system or topic it describes, not the initiative that created it.

Rule of thumb: if the feature is described in terms of an existing system ("add X to the Y pipeline"), it belongs in Y's architecture doc, not its own.

## AskUserQuestion Format
For each AskUserQuestion:
1. **Re-ground:** state project, branch, and current decision needed.
2. **Simplify:** explain the issue in plain language.
3. **Recommend:** `RECOMMENDATION: Choose [X] because [reason]`.
4. **Options:** `A) ... B) ... C) ...`.

## Review Modes
Choose one mode and stick to it:
1. **SCOPE EXPANSION** - grow technical ambition where leverage is high.
2. **HOLD SCOPE** - keep scope fixed and maximize implementation rigor.
3. **SCOPE REDUCTION** - minimize moving parts and ship smallest robust slice.

## Prime Directives
1. Zero silent failures.
2. Explicit error handling over generic rescues.
3. Map happy path plus shadow paths (nil, empty, upstream failure).
4. Treat observability and rollback as first-class scope.
5. Name and quantify technical risks before execution.

## Pre-Review System Audit
Run:
```bash
git log --oneline -30
git diff main --stat
```

Read `CLAUDE.md`, current plan docs, and any architecture notes in scope.

## Step 0: Scope and Mode Lock
Before deep review, confirm:
- technical objective
- constraints/non-goals
- selected mode (EXPANSION / HOLD / REDUCTION)

Do not drift from selected mode.

## Step 1: Change-Size Triage
Before running all sections, estimate the change size:

- **Small** (≤3 files, single concern): Review only sections relevant to the change. At minimum: Section 5 (Code Quality), Section 6 (Test Strategy), and any section whose domain is directly affected (e.g., security changes require Section 3). Skip the rest with a one-line note.
- **Medium** (4-10 files, 2-3 concerns): Review all sections but keep low-relevance sections to 1-2 sentences.
- **Large** (>10 files or cross-cutting): Full review of all sections.

State the triage result before proceeding.

## Engineering Sections

### Section 1: Architecture Review
Evaluate:
- component boundaries and dependency graph
- data flow maps (happy/nil/empty/error)
- stateful transitions and invalid states
- coupling tradeoffs and single points of failure
- realistic production failure scenarios
- rollback posture and blast radius

### Section 2: Error and Rescue Map
For each critical method/codepath, map:
- failure mode
- exception class
- rescue owner/action
- user-visible outcome
- logging/telemetry emitted

Flag all unrescued critical failures as **CRITICAL GAP**.

### Section 3: Security and Threat Model
Evaluate:
- attack surface changes
- input validation and authz boundaries
- secrets handling and dependency risk
- injection vectors (SQL, command, prompt, template)
- auditability for sensitive operations

Rate each threat by likelihood and impact.

### Section 4: Data Flow and Interaction Edge Cases
For each major flow, trace:
- input validation failure
- timeout/retry behavior
- stale state/concurrency issues
- partial success/partial failure paths

### Section 5: Code Quality and Complexity
Review:
- module boundaries and naming quality
- DRY violations and over/under-engineering
- error-handling consistency
- high-branching hotspots requiring refactor

### Section 6: Test Strategy and Coverage
Require explicit test plan for:
- happy path
- failure path
- edge cases and concurrency
- external dependency failures

Call out flakiness risks and missing confidence tests.

### Section 7: Performance and Scalability
Assess:
- expensive paths and p95/p99 risks
- query/index risks and N+1 patterns
- memory/runtime growth behavior
- cache and background job strategy

### Section 8: Observability and Debuggability
Require:
- structured logs with key context
- success/failure metrics
- traces for cross-service flows
- alerts and first-day dashboard plan
- runbook hints for top failure modes

### Section 9: Deployment and Rollout
Review:
- migration safety and compatibility windows
- feature flag strategy
- rollout and rollback sequence
- post-deploy verification checklist

### Section 10: Long-Term Trajectory
Evaluate:
- debt created vs debt paid down
- reversibility (1-5)
- path dependency and maintainability
- whether this improves future velocity

## Required Outputs
Return only sections that have findings. Omit empty sections entirely — do not output a section header with "N/A" or "None."

1. **Decision Summary** - Proceed / Revise / Stop, with confidence. (Always required.)
2. **Technical Risk Register** - top risks, severity, owner recommendation. (Omit if no risks.)
3. **Failure Modes Registry** - codepath, failure, rescued?, tested?, user sees?, logged? (Omit if no unrescued/untested failures.)
4. **Top Gaps** - max 7 critical/important gaps with concrete fixes. (Omit if no gaps.)
5. **Implementation Readiness Verdict** - what must be true before coding starts. (Always required.)
6. **Architecture Documentation** - update existing docs or create new ones per the Architecture Doc Policy. Prefer updating existing docs for features that extend an existing system. (Omit if change does not affect architecture.)
7. **EPIC Draft(s)** - create EPIC documents at `tasks/<EPIC_NAME>/EPIC.md`. (Omit for small changes that fit in a single task.)

## Interaction Policy
- Avoid unnecessary back-and-forth; batch related decisions.
- Ask at most 3 high-value questions per pass.
- If a fix is obvious and low-risk, recommend directly.
- If 2+ critical gaps remain unresolved, recommend **Revise**.
- If architecture or security posture is fundamentally unsafe, recommend **Stop**.
