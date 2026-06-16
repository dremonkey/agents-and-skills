# Provider: GitLab (`glab`)

Platform mechanics for reviewing a **GitLab merge request (MR)**. `SKILL.md`
and the mode files call these operations by name; this file is the only place
that knows `glab`. Every GitLab interaction goes through `glab` — `WebFetch`
cannot authenticate against private GitLab instances, and `gh` is GitHub-only.

## Identifiers to capture once

Run `view-change` first and record, for use by every later operation:

- `<IID>` — the MR's internal ID (the number in the MR URL).
- `<PROJECT_PATH>` — `group/subgroup/repo` (the `--repo` value).
- `<PROJECT_ID>` — numeric project ID (from the API; URL-safe in API paths).
- `diff_refs`: `<BASE_SHA>`, `<START_SHA>`, `<HEAD_SHA>` — **all three** are
  required for every line-tied comment. `<HEAD_SHA>` is also the current head.

---

## view-change

Fetch MR metadata and the anchoring SHAs.

```bash
glab mr view <IID> --repo <PROJECT_PATH> --output json | python3 -c "
import json, sys
mr = json.load(sys.stdin)
print('TITLE:', mr['title'])
print('SOURCE_BRANCH:', mr['source_branch'])
print('DESCRIPTION:'); print(mr['description'] or '<empty>')
"
glab mr view <IID> --repo <PROJECT_PATH> --commits   # commit subjects

glab api "projects/<PROJECT_ID>/merge_requests/<IID>" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(json.dumps({'iid': d['iid'], 'project_id': d['project_id'], 'diff_refs': d['diff_refs']}, indent=2))
"
```

Record `iid`, `project_id`, and the three `diff_refs` SHAs.

## list-files

Changed files with rough diff size, for the plan-vs-code classification.

```bash
glab api "projects/<PROJECT_ID>/merge_requests/<IID>/changes" | python3 -c "
import json, sys
d = json.load(sys.stdin)
for c in d['changes']:
    p = c['new_path']
    lines = len((c.get('diff') or '').split('\n'))
    print(f'{p}  (~{lines} diff lines)')
"
```

## my-prior-notes

The current reviewing user's own non-system notes on the MR — used to decide
IMPL-FIRST vs. FOLLOWUP. Resolve the username dynamically; never hardcode it.

```bash
ME=$(glab api user | python3 -c "import json,sys; print(json.load(sys.stdin)['username'])")

glab api "projects/<PROJECT_ID>/merge_requests/<IID>/notes?per_page=100" \
  --paginate --output ndjson | jq -s '.' | python3 -c "
import json, sys
me = sys.argv[1]
notes = json.load(sys.stdin)
mine = [n for n in notes
        if n.get('author', {}).get('username') == me
        and not n.get('system')]
print(json.dumps([{'id': n['id'], 'created_at': n['created_at'],
                    'body_preview': (n.get('body') or '')[:120]} for n in mine],
                  indent=2))
" "$ME"
```

- Empty → **IMPL-FIRST**.
- Substantive review content → **FOLLOWUP**.
- Only questions / chitchat → ambiguous; ask the user.

## raw-file

Pull a file's full contents at a SHA (full-context reading + line mapping).

```bash
# URL-encode slashes in the path: apps/foo/bar.ts -> apps%2Ffoo%2Fbar.ts
glab api "projects/<PROJECT_ID>/repository/files/<URLENCODED_PATH>/raw?ref=<SHA>" > /tmp/<basename>
```

`<SHA>` is `<HEAD_SHA>` for current-state reads. If the repo is a local
checkout, `git show <SHA>:<path>` is faster.

## post-top-level

The framing/narrative comment. GitLab posts it as its own note (separate from
line-tied comments). Use a single-quoted HEREDOC to avoid shell interpolation.

```bash
glab mr note <IID> --repo <PROJECT_PATH> -m "$(cat <<'EOF'
## <Framing title>

<narrative per mode>
EOF
)"
```

## post-line-comment

A comment pinned to a specific diff line (a `DiffNote`). Use the `post_pinned`
helper documented in [../shared/glab-line-comments.md](../shared/glab-line-comments.md).
Substitute the three `diff_refs` SHAs from `view-change`, plus `<PROJECT_ID>`
and `<IID>`, into the helper before calling it.

**Read the shared doc before posting your first line-tied comment.** The
bracket-form `position[...]` flags fail *silently* — GitLab returns HTTP 201
and drops the position, leaving an unpinned `DiscussionNote`. The helper's
trailing `assert` is the canary that catches this; the note `type` (`DiffNote`
vs `DiscussionNote`), not the line number, is the tell. The raw file at
`<HEAD_SHA>` (`raw-file`) is the source of truth for `new_line` — grep it for
the target phrase before constructing the position.

## list-prior-threads

All of the current user's prior review discussions, with line positions and
resolution state — the FOLLOWUP resolution-audit input.

```bash
ME=$(glab api user | python3 -c "import json,sys; print(json.load(sys.stdin)['username'])")

glab api "projects/<PROJECT_ID>/merge_requests/<IID>/discussions?per_page=100" \
  --paginate --output ndjson | jq -s '.' > /tmp/mr-<IID>-discussions.json

python3 -c "
import json, sys
me = sys.argv[1]
discs = json.load(open('/tmp/mr-<IID>-discussions.json'))
for d in discs:
    notes = d.get('notes', [])
    if not notes: continue
    first = notes[0]
    if first.get('system'): continue
    if first.get('author', {}).get('username') != me: continue
    pos = first.get('position') or {}
    print(json.dumps({
      'discussion_id': d['id'],
      'note_id': first['id'],
      # discussion-level 'resolved' is authoritative; note-level flags are
      # null on replies, so any(note.resolved) under-reports
      'resolved': bool(d.get('resolved')),
      'new_path': pos.get('new_path'),
      'new_line': pos.get('new_line'),
      'reply_count': len(notes) - 1,
      'body_preview': (first.get('body') or '')[:200],
    }))
" "$ME"
```

Capture per discussion: `discussion_id` (to reply or resolve), `note_id`, the
already-resolved flag (skip those), `new_path`+`new_line` of the prior pin,
`reply_count` (read author replies if any), and the original body.

## prior-review-head

The head SHA at the time of the last review — the delta boundary. Each MR
version is a push.

```bash
glab api "projects/<PROJECT_ID>/merge_requests/<IID>/versions" | python3 -c "
import json, sys
vs = json.load(sys.stdin)
for v in vs:
    print(json.dumps({'id': v['id'], 'head_commit_sha': v['head_commit_sha'], 'created_at': v['created_at']}))
"
```

Match the timestamp of your most recent review note (`my-prior-notes` /
`list-prior-threads`) to the closest prior version; its `head_commit_sha` is
`<PRIOR_HEAD>`.

## delta-files

Files changed between `<PRIOR_HEAD>` and `<HEAD_SHA>` — the FOLLOWUP Phase 2
scope.

```bash
git fetch origin
git diff <PRIOR_HEAD> <HEAD_SHA> --stat
git diff <PRIOR_HEAD> <HEAD_SHA> -- '<changed-files>'
```

If the repo isn't a local checkout:

```bash
glab api "projects/<PROJECT_ID>/repository/compare?from=<PRIOR_HEAD>&to=<HEAD_SHA>" \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
for diff in d.get('diffs', []):
    print(diff['new_path'])
"
```

## reply-thread

Append a note to an existing discussion (FOLLOWUP follow-ups / acknowledgments).

```bash
glab api --method POST \
  -f body="$(cat <<'EOF'
<follow-up body>
EOF
)" \
  "projects/<PROJECT_ID>/merge_requests/<IID>/discussions/<DISCUSSION_ID>/notes"
```

**Note first, resolve second.** A note added *after* a thread is resolved hides
in the collapsed thread.

## resolve-thread

Mark a discussion resolved. `resolved=true` goes in the request body via `-f`
(GitLab's documented form parameter) — not the URL query string.

```bash
glab api --method PUT \
  "projects/<PROJECT_ID>/merge_requests/<IID>/discussions/<DISCUSSION_ID>" \
  -f resolved=true
```

## delete-note

Remove a mis-posted note (e.g. a line comment that landed unpinned), before
reposting.

```bash
glab api --method DELETE \
  "projects/<PROJECT_ID>/merge_requests/<IID>/notes/<NOTE_ID>"
```

## post-publish report fields

For the Step 7d report: top-level note URL; each line-tied note as
`file:line` + topic + discussion ID; FOLLOWUP thread actions (resolved /
replied); any open threads.

## GitLab anti-patterns

- **Don't use `gh` or `WebFetch` for GitLab.** `glab` is the only
  authenticated path.
- **Don't trust an HTTP 201 on a line comment.** GitLab returns 201 even when
  it drops the position. Verify the note `type` is `DiffNote` (the helper's
  `assert`), then move on.
- **Don't put `resolved=true` in the query string.** It must be a `-f` body
  parameter.
