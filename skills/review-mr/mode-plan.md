# PLAN mode — planning-prose MRs

The diff is predominantly EPIC documents, PRDs, architecture docs,
VISION docs, or task files. The stakes are architectural; the
deliverable is publishable comments tied to specific lines in the
planning docs.

**Mode-fit check:** if Step 1b shows substantial source, test, or
config changes alongside the docs, this is not a plan MR — go back and
run Step 1c to classify IMPL-FIRST vs FOLLOWUP (or ask the user if
genuinely mixed). Don't hardcode IMPL-FIRST: a re-review with prior
review notes is still a FOLLOWUP, and skipping 1c would duplicate
first-pass work. Trivial doc changes (typos, link fixes) don't warrant
the full discipline — bail per SKILL.md.

## Analysis

### A. Verify the plan's claims

Plans frequently contain claims that look authoritative but have
drifted. Apply the Step 3 verification discipline to every checkable
claim — file:line citations, "plumbing already exists", SDK/schema
references, "existing pattern" callouts, architecture-doc summaries.

### B. Find the seam bugs

Read the task list as a composed system, not as isolated tasks. Tasks
often pass individual review and fail composition. Common failure
shapes:

- **Timing gaps.** Task N needs information that Task M+1 produces.
  Example: per-session identity forwarded via `setSessionConfigOption`
  after `newSession()` has already published the session's tool list —
  too late for init-time capability gating.
- **Two paths that should be one shape.** Separate configIds, separate
  stores, or separate validators for data that should share a wire
  contract. Symptoms: `JSON.stringify` appearing in two places; "setX
  then setY" ordering requirements; `if token && roles` guards.
- **Inconsistent fail-open/closed.** One task fails open, another on
  the same flow fails closed, with different reasons. Either the plan
  is inconsistent or the reasons haven't been unified.
- **Orphaned/dead code the plan builds on.** Handler exists but no
  caller; type declared but never read. Treat as cleanup opportunities
  in the same MR.
- **Rollout/ordering hazards.** Task 5 assumes Task 4 has shipped. If
  deploys are independent, verify intermediate states are safe.

### C. Structure the review

Internal working format (doesn't need to be published verbatim):

1. **Strengths** — brief; signals which moves to leave alone. Always
   include unless the plan is broadly off-track.
2. **Issues to resolve before acceptance** — numbered, concrete, each
   with a suggested fix. This is the bulk.
3. **Smaller notes** — line drift, minor inconsistencies, naming.
4. **Verdict** — accept / accept-with-changes / reshape / reject.

## Briefing additions (Step 4)

- **Net-new vs. refactor.** "Net new" means these planning artifacts
  don't exist on `main` yet; "refactor" means they revise existing
  ones. Mixed is fine — say which files are which.

## Publishing (Step 7)

- Top-level comment carries the framing narrative and any reshape
  summary; line-tied comments carry the tactical specifics.

## Anti-patterns

- **Don't publish before the reshape is agreed.** Tactical comments
  tied to lines the user is about to rewrite are noise.
- **Don't chase line-number drift as a top-level issue.** Note it once
  in "Smaller notes"; move on.
- **Don't duplicate `plan-tech-spec`.** This mode covers the
  verify-and-publish loop for a specific MR. For a first-principles
  technical critique of a spec not in an MR, use `plan-tech-spec`.
