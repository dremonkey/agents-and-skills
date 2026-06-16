# Posting line-tied comments on a GitLab MR

Shared recipe for any review skill that needs to attach a comment to a
specific line of a diff (a `DiffNote`), not a free-floating MR-level note.
This is agent-internal plumbing embedded by the review skills — there is no
standalone skill to invoke; read this doc inline and use the helper below.

**The position payload must be sent as nested JSON.** The bracket-form
flags (`-f "position[base_sha]=..."`) do **not** work — `glab api` sends
those as literal keys named `position[base_sha]`, GitLab silently drops
the unrecognized field, and the discussion gets created as an unpinned
top-level comment with HTTP 201 and no error. You only notice when you
inspect the response and find `"position": null` (note `type` is
`DiscussionNote`, not `DiffNote`). `glab mr note` cannot do diff positions
at all — only `glab api` with a JSON body can.

The reliable shape: build the JSON body with `python3`, write it to a
temp file, and POST via `--input` with an explicit `Content-Type` header.

Before calling the helper, substitute the three `diff_refs` SHAs
(`<BASE_SHA>`, `<START_SHA>`, `<HEAD_SHA>`), plus `<PROJECT_ID>` and
`<IID>`, captured from the MR's `diff_refs`.

## Which line fields to send

The `position` fields depend on whether the target line is **added**,
**deleted**, or **context** (unchanged) in the diff. Sending the wrong set
is one of the silent-drop causes below.

| Line kind in diff   | `new_line` | `old_line` | `old_path` | Notes                                   |
|---------------------|------------|------------|------------|-----------------------------------------|
| Added (`+`)         | required   | omit       | omit       | New-file side only                      |
| Deleted (`-`)       | omit       | required   | required   | Old-file side only                      |
| Context (unchanged) | required   | required   | required   | Both sides; lines must correspond       |
| Whole new file      | required   | omit       | omit       | GitLab infers from `new_path`/`new_line` |

To find which kind a line is, look at `git diff <BASE_SHA>..<HEAD_SHA> --
<file>` and check the hunk header (`@@ -OLD,N +NEW,M @@`) plus the `+` /
`-` / ` ` prefix on the target line. For a context line at new-side line N
inside hunk `@@ -OLD_START,OLD_COUNT +NEW_START,NEW_COUNT @@`, the
corresponding old-side line is `OLD_START + (N - NEW_START)` — but only if
every line between NEW_START and N in the hunk is unchanged; count out any
`+`/`-` lines in between manually.

Review comments most often land on **added** lines (the common case, where
`new_line` + `new_path` alone is correct). The helper takes `NEW_LINE` and
an optional `OLD_LINE`, and sends exactly the fields the table prescribes:
pass `NEW_LINE` only for an added line, both for a context line, and
`OLD_LINE` with an empty `NEW_LINE` for a deleted line.

## The helper

```bash
post_pinned() {
  local NEW_PATH="$1"
  local NEW_LINE="$2"  # empty for a deleted line
  local BODY="$3"
  local OLD_LINE="$4"  # set for context (with NEW_LINE) or deleted (without)
  local OLD_PATH="$5"  # set ONLY for renamed files — the pre-rename path; defaults to NEW_PATH

  python3 -c "
import json, sys
new_line, old_line, old_path = sys.argv[3], sys.argv[4], sys.argv[5]
pos = {
  'base_sha':  '<BASE_SHA>',
  'start_sha': '<START_SHA>',
  'head_sha':  '<HEAD_SHA>',
  'position_type': 'text',
  'new_path': sys.argv[2],
}
if new_line:
    pos['new_line'] = int(new_line)
if old_line:
    # context or deleted line — GitLab needs the old side too; on a renamed
    # file the old side lives at the pre-rename path, not new_path
    pos['old_path'] = old_path or sys.argv[2]
    pos['old_line'] = int(old_line)
assert new_line or old_line, 'need at least one of new_line / old_line'
print(json.dumps({'body': sys.argv[1], 'position': pos}))
" "$BODY" "$NEW_PATH" "${NEW_LINE:-}" "${OLD_LINE:-}" "${OLD_PATH:-}" > /tmp/disc.json

  glab api --method POST -H "Content-Type: application/json" \
    "projects/<PROJECT_ID>/merge_requests/<IID>/discussions" \
    --input /tmp/disc.json | python3 -c "
import json, sys
d = json.load(sys.stdin)
n = d.get('notes', [{}])[0]
pos = n.get('position') or {}
print(f\"  -> note {n.get('id')} ({n.get('type')}) pinned to {pos.get('new_path')}:{pos.get('new_line') or pos.get('old_line')}\")
assert n.get('type') == 'DiffNote', 'POSITION DROPPED — comment created unpinned (DiscussionNote)'
"
}

post_pinned "tasks/foo/EPIC.md" 274 'comment body in single quotes'        # added line
post_pinned "apps/foo/bar.ts" 42  'comment on an unchanged line' 39        # context line (new + old)
post_pinned "apps/foo/bar.ts" ""  'comment on a removed line'    51        # deleted line (old only)
post_pinned "apps/foo/new-name.ts" 42 'context line in a renamed file' 39 "apps/foo/old-name.ts"
```

On **renamed files**, context and deleted-line positions need the
pre-rename path as `old_path` (check `renamed_file`/`old_path` in the MR
`changes` payload) — passing the new path on both sides silently drops
the position, per the gotchas below. Added lines in a renamed file don't
send `old_path` at all, so they're unaffected.

The trailing `assert` is non-optional — it's the canary that catches a
silent drop. The type, not the line number, is the tell: if `type` is
`DiscussionNote` the comment is unpinned — delete it and repost before
posting more.

## Gotchas

- **Don't use `-f "position[...]=..."`.** It is silently wrong, not
  loudly wrong. Both forms return 201; only the response payload reveals
  the difference. (The `glab api` `--field`/`--raw-field` flags JSON-encode
  as flat string keys; they don't reconstruct nested objects from the
  bracket syntax.)
- **`Content-Type: application/json` is required** when using `--input`.
  Without it `glab` defers to its default form encoder; GitLab returns
  HTTP 415 ("provided content-type '' is not supported").
- **Single-quoted `$BODY`** prevents shell interpolation of backticks,
  dollars, and quotes inside the markdown. Escape any literal single
  quotes inside the body by closing/reopening: `'it'\''s'`.
- **Other silent-drop causes** (all return 201 with a stripped position,
  never a 4xx): `new_line`/`old_line` doesn't match the diff at the given
  SHAs (e.g. the MR was rebased and your `head_sha` is stale); the diff
  changed after you read the refs (race with a push); or `new_path` is a
  typo / not in the diff. The only recovery is delete-and-repost.
- **Delete a mispinned note** before retrying: `glab api --method DELETE
  "projects/<PROJECT_ID>/merge_requests/<IID>/notes/<NOTE_ID>"`.

## Multi-line ranges

Rarely needed — a single `new_line` on the most representative line is
almost always enough. If the user explicitly asks for a spanning comment,
add a `line_range` to the position object, where `line_code` is
`<sha1(new_path)>_<old_line>_<new_line>`:

```json
"position": {
  "...standard fields...": "...",
  "new_line": 50,
  "line_range": {
    "start": { "line_code": "...", "type": "new", "new_line": 42 },
    "end":   { "line_code": "...", "type": "new", "new_line": 50 }
  }
}
```

## Why not `gh`?

`gh` is GitHub-only. This recipe is for GitLab MRs via `glab`. The
equivalent GitHub flow uses `gh api repos/$OWNER/$REPO/pulls/$PR/comments`
with `line`/`side` parameters and works with `--field` form encoding
without this trap.

## References

- GitLab REST API — Create new merge request thread on a diff:
  https://docs.gitlab.com/ee/api/discussions.html#create-new-merge-request-thread
- Position-type `text` schema: requires `base_sha`, `start_sha`, `head_sha`,
  `new_path`, `old_path`, plus `new_line` and/or `old_line` depending on
  the line kind.
