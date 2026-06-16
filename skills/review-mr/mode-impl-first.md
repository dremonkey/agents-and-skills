# IMPL-FIRST mode — first-pass implementation review

The diff is predominantly source code, tests, or config, and the user
has no prior review notes on this MR. The review leads with **Phase 1**
(task fidelity, drift, docs) and backs into **Phase 2** (code quality)
only after Phase 1 is settled.

**Mode directive — Phase 1 before Phase 2.** A diff that meets style
but quietly diverged from the task is a worse review outcome than the
inverse. Do not open a single file with a code-quality lens until
Phase 1's drifts are captured. If Phase 1 turns up significant
undefended drift, the review lead is the drift; code-quality issues are
supplementary.

## Analysis

### Phase 1 — Big-picture investigation

**A. Find the originating task.** The `view-change` output captured in
Step 1a carries the high-fidelity signals: the description (often links the
task file), the source branch (`<initials>/<short-task-name>` style), the
commit subjects (`task(<epic>): ...`), and the title. Read them there; re-run
`view-change` if you need the full description body.

If not obvious, ask the user via `AskUserQuestion` which task in
`tasks/<epic>/` this change implements. Don't guess.

**Untasked MRs.** Some MRs legitimately have no originating task —
skills-only MRs (per SKILL.md 1b), hotfixes, tooling tweaks. Don't force
the question when there's genuinely nothing to find: Phase 1's ask
becomes the MR description's stated intent instead of a task file. Run
step C against that intent (does the diff deliver what the description
claims, and nothing undeclared?), skip step B, and keep step D — the
docs check applies regardless. For skills MRs specifically, "ask vs.
ship" means the skill's described behavior vs. what its instructions
actually do.

**B. Read the task + EPIC.** Read `tasks/<epic>/task-XX-*.md` and its
parent `tasks/<epic>/EPIC.md`. Capture: what the task asked for (Goal,
Implementation steps, Acceptance criteria), what's marked Not in scope,
and what dependencies (`Depends on`, `Blocks`) are flagged.

**C. Compare ask vs. ship.** For each implementation step in the task
(or each claim in the MR description, for untasked MRs):

- **Delivered as specified** — note briefly; no review action.
- **Delivered with a deviation** — did the MR description call it out?
  Yes → **explicit drift**: capture the rationale and judge whether
  it's defensible. No → **silent drift**: review comment.
- **Not delivered** — deferred to a follow-up, or dropped without
  acknowledgment? Either way, comment.

For each drift capture: what changed (file:line), explicit or silent,
what tradeoff was made, and your judgment (defensible / needs
justification).

**D. Docs check.** For each layer the MR touches, check the
corresponding docs:

- New provider package → `docs/contributing/03_creating-a-provider.md`
  + `docs/architecture/03_domain-extensibility.md`
- Agent loop changes → `docs/architecture/01_agent-loop.md`
- Tool registration → `docs/contributing/01_*` (tool-registration guide)
- Boot pipeline → `docs/architecture/02_boot-sequence.md` (if it exists)
- ACP / protocol changes → `docs/architecture/04_acp.md`

A doc that should describe the new behavior but wasn't updated is a
**Phase 1** comment — drift from the "docs are part of the change"
project rule (CLAUDE.md), not a Phase 2 nit.

### Phase 2 — Code quality

Code-quality rules (from CLAUDE.md):

- **Naming.** Filenames kebab-case; symbols still camel/PascalCase.
  Test files are siblings (`foo.ts` → `foo.test.ts`), not `__tests__/`.
- **File size.** ~500-line cap on source files; tests exempt. Growth
  past 500 = split by responsibility, not by "utils".
- **Layering.** Biome `noRestrictedImports`: `boot/**` cannot import
  from `acp/server`, `acp/adapter`, `cli/`, `entry/`; `entry/**` is
  thin plumbing only; no circular imports — they signal a wrong module
  boundary.
- **Tests.** Adjacent `.test.ts` files. No inline mirrors of production
  logic. `mock.module` is process-wide — don't redefine re-exported
  symbols in its factory; prefer dependency injection when mocking
  multiple re-exports.
- **Shape of exports.** Pure helpers return data; callers mutate.
  Module state in a dedicated `*-state.ts` with typed setters/getters,
  not `let _foo` sprinkled across modules.
- **Commits.** Messages explain *why*, not *what*. No "TODO: follow-up"
  scaffolding. No dead code / unused exports.
- **No two files with near-identical names** — always a half-applied
  rename.
- **No emojis in code** unless explicitly requested.
- **No comments explaining what the code does** — only WHY-comments for
  non-obvious constraints.

Also check:

- **Tool discoverability** (CLAUDE.md): new tool well-described?
  Differentiates from overlapping tools? References the relevant SKILL
  if part of a multi-tool workflow? Domain-specific tool names
  namespaced (`pika_cli`, `quest_fetch_scan`), not generic
  (`record_outcome`)?
- **SKILL.md format** — name kebab-case ≤64 chars, description covers
  what AND when, `allowed-tools` as a real spec field (not the legacy
  custom `tools:` key).

## Briefing additions (Step 4)

- **Change shape.** Net-new feature / refactor / bug fix / mixed (and
  which parts are which).
- **Originating task.** `tasks/<epic>/task-XX-*.md` with a one-line
  summary of what it asked for; note if you had to ask the user. For an
  untasked MR (see Phase 1), state that instead and name the MR
  description as the ask you reviewed against.
- **Phase 1 summary — the headline.** Drift report (each deviation:
  what, explicit or silent, defensible or not; or "Implementation
  matches the task spec / the MR's stated intent — no drift") and docs
  check (updated / partially / not, with specific doc paths).
- **Phase 2 highlights.** Short list, texture not exhaustive — the
  line-tied comments carry specifics.

## Publishing (Step 7)

Top-level comment leads with Phase 1. If drift is the headline, drift
goes first; if everything tracks the task, state that explicitly and
move Phase 2 highlights up:

```
## <Framing title>

### Phase 1 — Task fidelity, drift, docs
<narrative — drift report, docs check, defensibility judgments>

### Phase 2 — Code quality
<highlights — pointer to line-tied comments for specifics>

### Verdict
<accept / accept-with-changes / reshape / reject>
```

## Anti-patterns

- **Don't lead with Phase 2 when Phase 1 has undefended drift.** Style
  comments under a quietly-rewritten task miss the point.
- **Don't infer the originating task from the MR title alone.** Branch +
  description + commits are the high-fidelity signals;
  `AskUserQuestion` is the fallback.
- **Don't accept "follow-up will fix it" without confirming the
  follow-up task exists.** A task file pending or merged on `main` is
  acceptable; a vague promise in an MR description is not.
- **Don't grade tests by count.** A new test that doesn't fail without
  the change isn't coverage.
- **Don't grade docs by "did the MR touch a .md file."** Grade by
  whether the doc that *should* describe the new behavior was updated.
