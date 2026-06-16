---
name: review-mr
version: 2.0.0
model: opus
description: |
  Review a merge/pull request and publish the review as comments. Works on
  both GitLab (MR, via glab) and GitHub (PR, via gh) — Step 1a detects the
  platform and loads the matching provider file. Triage then selects one of
  three modes: PLAN (diff is planning prose — EPICs, PRDs, architecture docs),
  IMPL-FIRST (first-pass review of a source/tests/config change), or FOLLOWUP
  (re-review of a change the user already reviewed — audits prior feedback,
  reviews only the delta). Replaces review-plan, review-impl-start, and
  review-impl-followup.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# Change Review — GitLab MR / GitHub PR

One skill, two providers, three modes. The platform-neutral pipeline
(preflight → mode analysis → verification → briefing → forks → sanity gate →
publish) lives here. Two layers plug into it:

- **Provider** — *how* to talk to the host. All `glab`/`gh` mechanics live in
  `provider-gitlab.md` / `provider-github.md`. This file never names a CLI; it
  calls **operations** by name (e.g. `view-change`, `post-line-comment`), and
  the provider file you load in Step 1a defines those operations.
- **Mode** — *what* to analyze. Mode-specific analysis lives in one of three
  mode files. Step 1c/1d selects one.

Throughout this skill and its mode files, **"the change"** (and the shorthand
**"MR/PR"**) means the GitLab MR or GitHub PR under review. Operation names
appear in `code font` and always resolve to a section in the loaded provider
file.

| Mode | When | Mode file |
|---|---|---|
| **PLAN** | Diff is predominantly planning prose: `EPIC.md`, PRDs, VISION docs, architecture docs, task files | `mode-plan.md` |
| **IMPL-FIRST** | Diff is predominantly source/tests/config and the user has no prior review notes on the change | `mode-impl-first.md` |
| **FOLLOWUP** | Diff is source/tests/config and the user has already posted review comments in a prior pass | `mode-followup.md` |

## When NOT to use — bail early

- **Trivial diffs** (one-line fix, typo, version bump, lockfile churn) — just
  eyeball and tell the user. Don't run the full discipline on something with
  no decisions in it.
- **Neither GitLab nor GitHub.** This skill only knows `glab` and `gh`. For any
  other host, stop and tell the user.

## Provider operations (the shared contract)

Both provider files implement this same catalog. Read the loaded provider file
for the exact commands; reference operations by name everywhere else.

| Operation | Purpose |
|---|---|
| `view-change` | Fetch metadata (title, branch, description, commits) and capture the identifiers + anchoring SHAs every later operation needs |
| `list-files` | List changed files for the plan-vs-code classification |
| `my-prior-notes` | The current user's own prior review comments (IMPL-FIRST vs FOLLOWUP triage) |
| `raw-file` | A file's full contents at a SHA |
| `post-top-level` | The framing/narrative comment |
| `post-line-comment` | A comment pinned to a specific diff line (+ verify it attached) |
| `list-prior-threads` | All prior review threads by the current user, with positions + resolution state |
| `prior-review-head` | The head SHA at the time of the last review (delta boundary) |
| `delta-files` | Files changed between two SHAs |
| `reply-thread` | Append a note to an existing thread |
| `resolve-thread` | Mark a thread resolved |
| `delete-note` | Remove a mis-posted comment (recovery) |

## Prime directives (all modes)

1. **Verify before you critique.** Every "this matches the spec / this already
   exists / this follows pattern X" claim gets confirmed empirically before it
   becomes part of the review. See Step 3.
2. **Over-report during discovery; filter at the gates.** While analyzing,
   record every issue you find — including ones you are uncertain about or
   consider low-severity — with an estimated severity and confidence. Do not
   self-filter for importance while reviewing: the fork questions (Step 5) and
   sanity check (Step 6) are the filter, and the user is part of it. A finding
   filtered out at the gate costs nothing; a finding silently dropped during
   analysis is recall lost.
3. **Ground the user before asking.** They have not read what you just read.
   The one-shot briefing (Step 4) comes before any `AskUserQuestion`.
4. **Ask-don't-decide on forks.** When an issue has multiple viable
   resolutions with different team costs, present ranked options. The user
   picks; you publish their pick.
5. **Sanity-check before publishing.** List the resolutions chosen and preview
   every comment in one message before any publish operation runs.
6. **Publish as one top-level + line-tied.** Top-level carries the framing
   narrative; line-tied carries tactical specifics. (Some providers batch both
   into a single atomic submission — follow the provider file.)

## Step 1 — Preflight and triage

### 1a. Select the provider and view the change

Determine the host: a GitLab URL / `glab` mention / a GitLab remote
(`git remote -v`) → **GitLab**; a GitHub URL / `gh` mention / a GitHub remote →
**GitHub**. If it's genuinely ambiguous, ask the user. State the selected
provider in one line, then **read the matching provider file now**
(`provider-gitlab.md` or `provider-github.md` in this skill's directory).

Run the provider's `view-change` operation and record the identifiers and
anchoring SHAs it returns — every later operation needs them.

### 1b. Classify the diff — plan vs. implementation

Run `list-files`.

**Plan paths:** `tasks/**/EPIC.md`, `tasks/**/PRD*.md`, `tasks/**/VISION.md`,
`tasks/**/task-*.md`, `docs/architecture/**.md`, top-level `VISION.md`.

**Code paths:** `.ts`, `.tsx`, `.py`, `.rs`, `.go`, `.sh`, helm/CI yaml,
`package.json`, migration files, `biome.json`, `CLAUDE.md`.

**Skill/instruction paths:** `skills/**` (SKILL.md, MODE/playbook `.md`,
`shared/*.md`). These are behavioral instructions, not planning artifacts —
treat them as **implementation** (the IMPL-FIRST/FOLLOWUP axis applies: a
re-review of a skills change is a FOLLOWUP). They are *not* PLAN-mode docs;
PLAN is for `tasks/**` and `docs/architecture/**`. Skip the test-coverage
dimension of the impl rubric — skills carry no code — and review the logic,
internal consistency, and whether each instruction is followable.

A mostly-plan change with a one-line code tweak is a plan change. A multi-file
source change — or a `skills/**`-only change — is implementation. **When
genuinely mixed, ask the user which lens they want rather than guessing.**

**Precedence — this classification gates 1c.** If 1b resolves to a plan
change, the mode is **PLAN**: skip 1c entirely and go to 1d. 1c runs *only*
after an implementation classification — never run the prior-notes fetch on a
plan change, or it can misclassify a plan change as FOLLOWUP and load the wrong
mode file.

### 1c. First pass vs. follow-up (implementation changes only — skip if 1b chose PLAN)

Run `my-prior-notes`.

- Empty result → **IMPL-FIRST**.
- Substantive review content → **FOLLOWUP**.
- Only questions or chitchat (no actual review content) → ambiguous; surface
  via `AskUserQuestion`: first review with prior unrelated chatter, or
  re-review of an earlier pass?

### 1d. Lock the mode and read the mode file

The mode is now determined: PLAN if 1b classified the diff as plan; otherwise
the IMPL-FIRST/FOLLOWUP result from 1c. State the selected mode in one line,
then **read the mode file now** (`mode-plan.md`, `mode-impl-first.md`, or
`mode-followup.md` in this skill's directory). Do not proceed to Step 2
without it.

### 1e. Pull raw files at HEAD

For each file the mode's analysis needs (planning docs in PLAN mode, non-trivial
source files otherwise), run `raw-file` at the head SHA — needed for
full-context reading and for mapping review targets to line numbers. Skip files
with trivial diffs (e.g., a single import added).

## Step 2 — Mode analysis

Run the **Analysis** section of the selected mode file. Capture findings as
working notes (with severity + confidence per Prime Directive 2) — they feed
the briefing in Step 4 and the comments in Step 7.

## Step 3 — Verify before you critique

For each claim — in the plan, the change description, or the code itself — that
could be wrong, confirm empirically:

- **File:line citations** — read the file, check the line. Note drift (wrong
  line number) once as a small note; don't chase every instance.
- **"Plumbing / pattern already exists"** — grep for *callers*, not just the
  handler. A handler with no callers is dead code that shouldn't count as
  existing plumbing. Confirm the pattern is used the way the text describes.
- **SDK/schema references** — confirm against the pinned schema on disk
  (e.g., `node_modules/<sdk>/schema/schema.json`), never web docs or memory.
- **"Already covered by tests"** — open the named tests and confirm they
  actually exercise the changed path. Tests that pass against a stale mock are
  not coverage.
- **"This is dead code" / "this will break X"** — grep for callers across the
  workspace / find X and confirm the breakage path before raising.
- **Architecture-doc references** — read the cited doc before accepting the
  summary.

Keep the evidence (grep command + output, file:line, test name) in your working
notes — it's what makes the comment land.

## Step 4 — Ground the user before asking anything

**Do this once, before any `AskUserQuestion` call.** Treat it as a briefing for
someone walking into the room cold — even the author may not have looked at it
in days. Common sections for every mode:

1. **What this change is.** One sentence, plain language, sanity-checked
   against the actual files you read.
2. **Scope inventory.** Every file in the change with a one-line "what it
   covers", grouped sensibly (code / tests / docs / config where that applies).
   Mark generated / vendored / lockfile entries separately.
3. **Architecture at play — ASCII diagram.** The slice of the system this
   change introduces or changes, < ~15 lines, boxes labeled with file, symbol,
   or task references. Draw the shape that matters for the decisions you're
   about to ask about, not a complete system map.
4. **Decision context — what's in flight.** The specific forks you're about to
   ask about, concretely stated. "Task said X, change delivered Y — accept Y or
   push back?" is useful; "there are some tradeoffs" is not.

Then add the mode file's **Briefing additions** sections. Only after this
message is sent do you proceed to fork questions.

## Step 5 — Ask-don't-decide on forks

If an issue has multiple viable resolutions with different costs, use
`AskUserQuestion`:

1. **Re-ground:** the change reference + the decision point (one line — the
   Step 4 briefing did the heavy lift).
2. **Simplify:** the issue in plain language.
3. **Recommendation:** `RECOMMENDATION: Choose [X] because [reason]`.
4. **Options:** `A) … B) … C) …` with one-line tradeoffs each.

Do not publish comments that pre-decide these forks.

## Step 6 — Sanity-check before publishing

Before any publish operation runs, send the user a single message listing:

1. The resolutions they've picked on forks.
2. Any remaining yes/no questions before comments go out.
3. A one-line preview of each action you plan to take — top-level comment, each
   line-tied target (file:line + topic), and any mode-specific actions (e.g.
   FOLLOWUP thread resolutions).

Wait for confirmation. Do not batch-publish without it.

## Step 7 — Publish mechanics

### 7a. Top-level comment

Carries the narrative and framing, shaped per the mode file's **Publishing**
section. Run `post-top-level`.

### 7b. Line-tied comments

Run `post-line-comment` for each tactical target, then verify each one actually
attached per the provider file (providers differ: GitLab can silently drop a
position, GitHub rejects a bad line loudly). The raw file at HEAD (`raw-file`)
is the source of truth for the target line — grep it for the target phrase
before constructing the position.

*Some providers (GitHub) batch 7a and 7b into one atomic submission — the
provider file says how. Build the payload once in that case.*

### 7c. Mode-specific publish actions

Run any additional actions from the mode file's **Publishing** section
(FOLLOWUP mode resolves and appends to existing threads here, via
`reply-thread` / `resolve-thread`).

### 7d. Post-publish report

Send the user a summary using the provider's **post-publish report fields**:
top-level comment URL; each line-tied comment (`file:line` + one-line topic +
id); mode-specific actions taken (threads resolved / replied); any open threads
(forks deferred, follow-ups explicitly punted).

## Anti-patterns (all modes)

- **Don't hardcode a provider.** Detect it in Step 1a and route every host call
  through the loaded provider file's operations. Mixing `glab` and `gh`, or
  using `WebFetch` for either, is wrong.
- **Don't publish before the Step 6 sanity check.** Re-shapes during the fork
  pass make tactical comments stale.
- **Don't quote the diff or the plan's own words back at the reader.** They've
  read it. Say what's wrong or what to weigh, not what it says.
- **Don't rely on memory or the web for SDK/schema shape.** Read the pinned
  schema on disk.
- **Don't publish comments with wrong line numbers.** Grep the raw HEAD file
  for the target phrase first.

Mode-specific anti-patterns are in each mode file. Provider-specific
anti-patterns are in each provider file.
