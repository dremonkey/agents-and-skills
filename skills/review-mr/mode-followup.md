# FOLLOWUP mode — re-review after a prior pass

The user has already posted review comments on this MR in a prior
session. The focus shifts to (1) a **resolution audit** of every prior
comment and (2) **Phase 2 code quality on the delta** — only what the
author added since the last review.

**Mode directives:**

1. **Resolution audit before new nits.** Close out prior threads first;
   new code-quality issues come after.
2. **Append to existing threads, don't open duplicates.** Partial or
   unaddressed points get a reply *in their thread*, never a new
   top-level comment.
3. **Resolve threads only on verified change.** "Addressed" requires
   reading the new code and confirming the point is closed — not the
   author saying "fixed".
4. **Phase 2 runs on the delta, not the whole MR.** Re-litigating
   already-reviewed code is noise.
5. **Don't carry forward Phase 1** unless the follow-up *introduced*
   new drift. Phase 1 was the first pass's job.

**Trivial follow-up** (author pushed one tiny commit clearly addressing
one comment): just confirm and resolve manually — skip the full
discipline.

## Analysis

### A. Pull all prior threads (with line positions)

Run `list-prior-threads`. It returns, per prior thread authored by the current
user (resolved dynamically — never hardcoded): a thread id (needed to reply or
resolve), the already-resolved flag (skip those), the prior pin's `path` +
`line`, whether the author replied (read it if so), and the original body for
the audit comparison.

### B. Identify the delta since the last review

Run `prior-review-head` to get `<PRIOR_HEAD>` — the head SHA at the time of
your last review. Then run `delta-files` between `<PRIOR_HEAD>` and the current
head. The output is the **delta file list** — Phase 2 targets these files only.

### C. Resolution audit

For each prior thread: read the file at current HEAD (`raw-file`, Step 1e).
Line numbers from the prior pin may have shifted — grep for the content the
prior comment was about; trust the current file content, not the old pin.

Classify each prior comment:

- **ADDRESSED.** The change fully resolves the point. Resolve the
  thread at publish time.
- **PARTIAL.** Progress made but not closed. Capture exactly what's
  still missing.
- **NOT ADDRESSED.** The diff didn't touch it. Defensible (author
  replied disagreeing) or silent — capture which.
- **OUTDATED.** Surrounding code moved enough that the point no longer
  applies (e.g., the flagged function was deleted in a refactor).

If the discussion has author replies, read them — a sound disagreement
can flip your assessment to OUTDATED or acknowledged-and-deferred; an
unanswered clarifying question gets answered in your follow-up note.
Evidence for each classification goes in working notes.

### D. Phase 2 on the delta

Apply the **Phase 2 code-quality rubric from `mode-impl-first.md`**,
scoped to the delta:

- Only lines that changed between `PRIOR_HEAD` and HEAD are in scope —
  use the SHA diff to know which.
- New files added since the last review get full Phase 2 treatment.
- Tests added in response to prior feedback are validated as part of
  the resolution audit (C), not Phase 2 — confirm they actually
  exercise the changed path.

## Briefing additions (Step 4)

- **Pass type.** "Follow-up review (pass N)", with the change reference.
- **What changed since last review.** One paragraph summarizing the
  commits between `PRIOR_HEAD` and `HEAD`.
- **Resolution audit summary table.** One row per prior discussion:

  ```
  #1234  apps/foo/bar.ts:42  ADDRESSED     (commit abc1234 — explicit fix)
  #1235  apps/foo/baz.ts:88  PARTIAL       (got X; still missing Y)
  #1236  apps/foo/qux.ts:15  NOT ADDRESSED (no change; author silent)
  #1237  apps/foo/zap.ts:7   OUTDATED      (function deleted in refactor)
  ```

- **Delta files** — the Phase 2 scope.
- **Fork specifics for this mode:** PARTIAL classifications where
  re-raise vs. close is unclear; NOT ADDRESSED where the author
  disagreed — hold the line or accept their reasoning?

In the Step 6 sanity check, also list **what you're about to do per
prior discussion** (resolve / append note / resolve with note).

## Publishing (Step 7c — mode-specific actions)

### Resolve threads (ADDRESSED, OUTDATED)

Note first, resolve second — for both classes. Run `reply-thread` to post the
note, *then* `resolve-thread`; a note added after resolution hides in a
collapsed thread and the audit trail looks empty.

- **ADDRESSED** — one acknowledgment note is enough (e.g. "Addressed —
  thanks."), then resolve.
- **OUTDATED** — the note is a one-line explanation of *why* it's moot (e.g.
  "Closing — surrounding code moved; the refactor in commit abc1234 replaced
  the function this referenced."), then resolve.

### Append follow-up notes (PARTIAL, NOT ADDRESSED)

Run `reply-thread` with a body stating what's still missing, or why the point
still stands. Do **not** resolve these threads.

### New line-tied comments on the delta

Run `post-line-comment` (Step 7b) against the **current** head — never the
prior review's SHAs.

### Top-level summary

```
## Follow-up review (pass <N>)

### Resolution audit
- N addressed, M partial, K not addressed, J outdated.

### New issues on delta
- <bullet list — line-tied comments cover specifics>

### Verdict
<accept / accept-with-changes / reshape>
```

## Anti-patterns

- **Don't open a new top-level comment for a point that has an existing
  thread.** The audit trail belongs in-thread.
- **Don't resolve a thread because the author said "fixed."** Verify
  against the diff first.
- **Don't run Phase 2 over the whole MR.** Delta only.
- **Don't infer "addressed" from a green CI build.** CI passing means
  nothing caught fire, not that the point was addressed.
- **Don't trust line numbers from prior pins.** Files shift; grep for
  the content, then resolve to the current line.
