---
name: review-plan
version: 1.0.0
model: opus
description: |
  Review a GitHub plan/design PR (EPIC.md, PRDs, architecture docs) and publish
  a structured review as PR comments. GitHub-only via gh. Not for code-heavy
  PRs — bail if the diff contains substantial source code changes.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# Plan PR Review (GitHub)

## When to use

The user asks you to review a GitHub pull request whose diff is predominantly
planning prose — EPIC documents, PRDs, architecture docs, VISION docs, design
proposals. The stakes are architectural, and the deliverable is publishable
PR comments tied to specific lines in the planning docs.

## When NOT to use — bail early

- **Code-heavy PRs.** If the diff contains substantial source code, tests, or
  config changes, stop and tell the user this skill is the wrong fit. Code PR
  review has different mechanics (type-check output, test coverage, line-by-line
  diff reasoning) — use the generic review flow instead.
- **Non-GitHub.** This skill uses `gh` exclusively. For GitLab MRs, don't
  use this skill.
- **Trivial doc changes** (typo fixes, small clarifications, link updates)
  that don't warrant the full review discipline.

Triage in Step 1 enforces the code-heavy rule. Do not proceed past Step 1
if the triage fails.

## Prime directives

1. **Verify before you critique.** Every file:line citation, every "already
   exists" claim, every SDK/schema reference, every "existing pattern"
   callout gets confirmed empirically before it becomes part of the review.
   Grep for callers, not just handlers. Plans frequently contain claims that
   look authoritative but have drifted.
2. **Find the seam bugs.** Tasks often pass individual review and fail
   composition. Walk flow ordering across task boundaries; check timing
   (does information arrive early enough?), dedupe (two paths that should be
   one shape?), and fail-open/closed consistency.
3. **Ask-don't-decide on forks.** When an issue has multiple viable
   resolutions with different team costs, present ranked options with
   tradeoffs. Let the user pick.
4. **Sanity-check before publishing.** List the resolutions the user chose
   and ask any unresolved questions in one message, before any comment goes
   out.
5. **Publish as one review (batched).** GitHub's review API attaches a
   top-level body plus all line-tied comments as a single atomic review —
   one notification, one acceptance/dismissal. Prefer this over piecemeal
   issue comments + per-line comments.

## Step 1 — Preflight and triage

### 1a. Fetch the PR

```bash
gh pr view <NUMBER> --repo <OWNER>/<REPO>
gh api "/repos/<OWNER>/<REPO>/pulls/<NUMBER>" \
  -q '{number:.number, head_sha:.head.sha, base_sha:.base.sha, head_ref:.head.ref, base_ref:.base.ref}'
```

Record the **head SHA** — required as `commit_id` for every line-tied review
comment.

### 1b. Triage — plan-only vs. code-heavy

List the files changed:

```bash
gh api "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/files" --paginate \
  -q '.[] | "\(.filename)  (+\(.additions)/-\(.deletions))"'
```

**Plan-only paths** (this skill fits): `tasks/**/EPIC.md`, `tasks/**/PRD*.md`,
`tasks/**/VISION.md`, `docs/architecture/**.md`, top-level `VISION.md`,
`tasks/**/task-*.md`.

**Code paths** (this skill does NOT fit): substantive changes to `.ts`, `.py`,
`.rs`, `.go`, `.tsx`, `.sh`, `.yaml` (helm/CI), `package.json`, migration
files, `biome.json`, `CLAUDE.md`.

A small exports file or a one-line config tweak that accompanies a planning
doc is fine. A multi-file source change is not. **When in doubt, bail and
tell the user.**

### 1c. Pull raw files at HEAD

For each planning document in the PR, pull the full raw file at the HEAD SHA.
Needed both for full-context reading and for mapping review targets to
`line` numbers.

```bash
gh api "/repos/<OWNER>/<REPO>/contents/<path>?ref=<HEAD_SHA>" \
  -H "Accept: application/vnd.github.raw" > /tmp/<basename>.md
```

If the PR is a local checkout, `git show <HEAD_SHA>:<path>` is faster.

## Step 2 — Verify before you critique

For each claim in the plan that could be wrong, confirm empirically:

- **File:line citations** — read the file, check the line. Note drift (wrong
  line number) once as a small note; don't chase every instance.
- **"Plumbing already exists"** claims — grep for *callers*, not just the
  handler. A handler with no callers is dead code that shouldn't count as
  "existing plumbing."
- **SDK/schema references** — confirm against pinned schema on disk
  (e.g., `node_modules/<sdk>/schema/schema.json`), not web docs or memory.
- **"Existing pattern" callouts** — grep for the symbol and confirm the
  pattern is used the way the plan describes.
- **Architecture-doc references** — read the cited doc before accepting
  the summary.

Capture verification results as working notes. If you claim "no caller
exists," you should have the grep command and its empty output on hand —
that's the evidence that makes the critique land in the review.

## Step 3 — Look for the seam bugs

Read the task list as a composed system, not as isolated tasks. Common
failure shapes:

- **Timing gaps.** Task N needs information that Task M+1 produces. Example:
  per-session identity forwarded via `setSessionConfigOption` after
  `newSession()` has already published the session's tool list — too late
  for init-time capability gating.
- **Two paths that should be one shape.** Separate configIds, separate
  stores, or separate validators for data that should share a wire
  contract. Symptoms: `JSON.stringify` appearing in two places;
  "setX then setY" ordering requirements; `if token && roles` guards.
- **Inconsistent fail-open/closed.** One task fails open, another on the
  same flow fails closed, with different reasons given. Either the plan
  has an inconsistency, or the reasons haven't been unified.
- **Orphaned/dead code** that the plan builds on. Handler exists but no
  caller. Type declared but never read. Treat these as cleanup
  opportunities in the same PR.
- **Rollout/ordering hazards.** Task 5 assumes Task 4 has shipped; Task 4
  assumes Task 3. If deploys are independent, verify intermediate states
  are safe.

## Step 4 — Structure the review

Internal working format (doesn't need to be published verbatim):

1. **Strengths** — brief. Signals which moves to leave alone. Always
   include unless the plan is broadly off-track.
2. **Issues to resolve before acceptance** — numbered, concrete, each with
   a suggested fix. This is the bulk.
3. **Smaller notes** — line drift, minor inconsistencies, naming.
4. **Verdict** — brief. Accept / accept-with-changes / reshape / reject.

## Step 5 — Ask-don't-decide on forks

If an issue has multiple viable resolutions with different team costs, use
`AskUserQuestion`:

1. **Re-ground:** PR number, current decision point.
2. **Simplify:** the issue in plain language.
3. **Recommendation:** `RECOMMENDATION: Choose [X] because [reason]`.
4. **Options:** `A) … B) … C) …` with one-line tradeoffs each.

Do not publish comments that pre-decide these forks. The user picks; you
publish their pick.

## Step 6 — Sanity-check before publishing

Before any `gh api .../reviews` or `gh pr comment` call, send the user a
single message that lists:

1. The resolutions they've picked on forks.
2. Any remaining questions requiring a yes/no before comments go out.
3. A one-line preview of each comment you plan to post (top-level body +
   each line-tied target — file:line + one-line topic).

Wait for confirmation. Do not batch-publish without it.

## Step 7 — Publish mechanics

Prefer **a single batched review** via the reviews API: it carries the
top-level body and all line-tied comments atomically, sends one
notification, and shows up in the PR's review history.

### 7a. Build the review payload

Construct a JSON file containing the body, the `event` (`COMMENT`,
`APPROVE`, or `REQUEST_CHANGES`), and the list of line-tied comments.

```bash
cat > /tmp/review.json <<'EOF'
{
  "body": "## <Framing title>\n\n<narrative>\n\n<knock-on / summary>",
  "event": "COMMENT",
  "comments": [
    {
      "path": "tasks/<EPIC>/EPIC.md",
      "line": 42,
      "side": "RIGHT",
      "body": "<comment body — markdown>"
    },
    {
      "path": "docs/architecture/<topic>.md",
      "start_line": 10,
      "line": 14,
      "start_side": "RIGHT",
      "side": "RIGHT",
      "body": "<multi-line comment>"
    }
  ]
}
EOF
```

Find each `line` by grepping the raw file pulled in Step 1c for the target
phrase — never guess from the diff hunk.

### 7b. Post the review

```bash
gh api --method POST "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/reviews" \
  --input /tmp/review.json
```

The response contains the review `id` and a list of comment `id`s — capture
these so the user can reference them.

### 7c. Fallback — separate top-level + per-line comments

Use this only if the batched review fails (e.g., a comment targets a line
not in the diff and the whole review rejects). Post the top-level
narrative as a regular PR comment, then post each line-tied note
individually:

```bash
# Top-level narrative
gh pr comment <NUMBER> --repo <OWNER>/<REPO> --body-file /tmp/top-level.md

# Each line-tied comment
gh api --method POST "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/comments" \
  -f body="<comment body>" \
  -f commit_id="<HEAD_SHA>" \
  -f path="path/to/file.md" \
  -F line=42 \
  -f side="RIGHT"
```

Gotchas:

- **`side` must be `RIGHT`** for comments on the new version of the file
  (the typical case). Use `LEFT` only when commenting on a line that was
  removed.
- **`line` must be a line that appears in the PR's diff.** Comments on
  unchanged context lines are rejected. If you must reference an
  unchanged line, anchor the comment to the nearest changed line and
  describe the target in the body.
- **Multi-line comments** require both `start_line` and `line`, plus
  `start_side` and `side`. Both sides should be `RIGHT` for the typical
  case.
- **Single-quoted heredoc (`<<'EOF'`)** prevents shell interpolation of
  backticks, dollars, and quotes inside the markdown. Use unquoted
  `<<EOF` only when you need shell variable expansion inside.
- **`commit_id` must be the current HEAD SHA.** If the PR receives a new
  push between Step 1 and Step 7, refetch the head SHA before posting.

### 7d. Post-publish report

After the review is up, send the user a summary listing:

- Review URL (e.g., `https://github.com/<OWNER>/<REPO>/pull/<NUMBER>#pullrequestreview-<ID>`).
- Each line-tied comment: `file:line` + one-line topic + comment ID.
- Any open threads (forks they deferred, follow-ups explicitly punted).

## Anti-patterns

- **Don't publish before the reshape is agreed.** Tactical comments tied
  to lines the user is about to rewrite are noise.
- **Don't chase line-number drift as a top-level issue.** Note it once in
  "Smaller notes"; move on.
- **Don't quote the plan's own words back at it** in the comment. The
  reviewer already read that line — say what's wrong, not what it says.
- **Don't duplicate `plan-tech-spec`.** This skill covers the
  verify-and-publish loop for a specific PR. For a first-principles
  technical critique of a spec the user is holding (not in a PR), use
  `plan-tech-spec`.
- **Don't rely on memory or the web for SDK/schema shape.** Read the
  pinned schema on disk.
- **Don't publish comments with wrong line numbers.** The raw file at
  HEAD is the source of truth — grep it for the target phrase before
  constructing `line`.
- **Don't use WebFetch for PR contents.** It can't authenticate against
  private repos. Use `gh` for every GitHub interaction.
