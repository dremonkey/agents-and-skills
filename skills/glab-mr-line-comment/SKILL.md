---
name: glab-mr-line-comment
description: |
  Post a line-attached inline comment on a GitLab merge request via `glab`.
  Use this skill any time you need a comment to land on a specific line of
  a diff (a `DiffNote`), not as a free-floating MR-level discussion. There
  is one trap that catches every attempt to do this naively — capturing
  it here so the next try doesn't burn a round.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Line-attached MR comments on GitLab via `glab`

## When to use

The user asks you to post review feedback as inline comments on specific
lines of a GitLab MR diff. The deliverable is a `DiffNote` (rendered next
to the changed line in the MR diff view), not a `DiscussionNote` (rendered
in the MR-level activity feed).

## The trap

The obvious approach is to use `glab api` with `--field` for each
parameter, including nested `position[*]` keys:

```bash
# DO NOT DO THIS — silently degrades to a DiscussionNote
glab api projects/$PID/merge_requests/$IID/discussions -X POST \
  --field "body=$BODY" \
  --field "position[base_sha]=..." \
  --field "position[head_sha]=..." \
  --field "position[new_path]=path/to/file.ts" \
  --field "position[new_line]=42" \
  ...
```

GitLab's API **accepts this request and returns 201**, but the resulting
note has `type: DiscussionNote` and no `position` field. The form-encoded
`position[*]` keys are silently dropped on this endpoint. The comment
appears on the MR but is not attached to any line of the diff.

This failure mode is invisible until you actually look at the MR in a
browser or query the note back. `glab mr note` does not support diff
positions at all — only `glab api` does, and only with a JSON body.

## The fix

Send the request as a JSON body with `--input` and an explicit
`Content-Type` header:

```bash
glab api projects/$PROJECT_ID/merge_requests/$MR_IID/discussions \
  -X POST \
  -H "Content-Type: application/json" \
  --input /tmp/comment.json
```

Where `/tmp/comment.json` is:

```json
{
  "body": "...markdown...",
  "position": {
    "base_sha":     "...",
    "start_sha":    "...",
    "head_sha":     "...",
    "position_type": "text",
    "new_path":     "path/to/file.ts",
    "old_path":     "path/to/file.ts",
    "new_line":     42
  }
}
```

The response will have `notes[0].type === 'DiffNote'` and a populated
`position` object. **If `type` is `DiscussionNote`, the position was
dropped — the comment is not line-attached.**

## Step-by-step

### 1. Get the diff refs

```bash
glab api projects/$PROJECT_ID/merge_requests/$MR_IID 2>&1 \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
dr = d.get('diff_refs', {})
print('base_sha:',  dr.get('base_sha'))
print('start_sha:', dr.get('start_sha'))
print('head_sha:',  dr.get('head_sha'))
print('project_id:', d.get('project_id'))
"
```

`base_sha` and `start_sha` are usually the same (the merge-base / target
branch tip). `head_sha` is the MR's current head commit.

### 2. Compute line numbers for each comment

You need different fields depending on whether the line is **added**,
**removed**, or **context** (unchanged) in the diff:

| Line kind in diff   | `new_line` | `old_line` | Notes                                  |
|---------------------|------------|------------|----------------------------------------|
| Added (`+`)         | required   | omit       | New-file side only                     |
| Deleted (`-`)       | omit       | required   | Old-file side only                     |
| Context (unchanged) | required   | required   | Both sides; lines must correspond      |
| Whole new file      | required   | omit       | `old_path` still required, points at same path |

To find which kind a line is, look at `git diff <base_sha>..<head_sha> --
<file>` and check the hunk header (`@@ -OLD,N +NEW,M @@`) plus the `+` /
`-` / ` ` prefix on the target line.

For a context line at new-side line N inside hunk `@@ -OLD_START,OLD_COUNT
+NEW_START,NEW_COUNT @@`, the corresponding old-side line is
`OLD_START + (N - NEW_START)` — but only if all lines between
NEW_START and N in the hunk are unchanged. If there are `+`/`-` lines
in between, count them out manually.

### 3. Write the JSON payload

Use a heredoc or `python3 -c "..."` to escape the body cleanly — markdown
bodies often contain backticks and quotes that break shell escaping.
Example:

```bash
python3 -c "
import json
body = open('/tmp/body.md').read()
payload = {
    'body': body,
    'position': {
        'base_sha':     '$BASE_SHA',
        'start_sha':    '$START_SHA',
        'head_sha':     '$HEAD_SHA',
        'position_type': 'text',
        'new_path':     'apps/foo/bar.ts',
        'old_path':     'apps/foo/bar.ts',
        'new_line':     42,
    },
}
print(json.dumps(payload))
" > /tmp/comment.json
```

### 4. POST and verify the result is a `DiffNote`

```bash
glab api projects/$PROJECT_ID/merge_requests/$MR_IID/discussions \
  -X POST \
  -H "Content-Type: application/json" \
  --input /tmp/comment.json \
  | python3 -c "
import json, sys
d = json.load(sys.stdin)
note = (d.get('notes') or [{}])[0]
print('discussion_id:', d.get('id'))
print('note_id:',       note.get('id'))
print('note_type:',     note.get('type'))
print('has_position:',  bool(note.get('position')))
assert note.get('type') == 'DiffNote', 'comment not line-attached'
"
```

**Always run this verification.** If `note_type` is `DiscussionNote`,
the position was dropped — delete the note and retry. The position can
also be silently dropped if:

- `new_line` / `old_line` doesn't match the diff at the given SHAs (e.g.
  the MR was rebased and your `head_sha` is stale)
- The diff was changed after you read the refs (race with a push)
- The line is on a file path that doesn't exist in the diff (typo in
  `new_path`)

In all these cases, GitLab returns 201 with a stripped-position note
rather than 4xx. There is no way to recover the attachment without
deleting and re-posting.

### 5. (If you got it wrong) Delete and retry

```bash
glab api projects/$PROJECT_ID/merge_requests/$MR_IID/notes/$NOTE_ID -X DELETE
```

Then re-issue the POST with corrected position fields.

## Multi-line ranges

For a comment that spans multiple lines, add a `line_range` to the
position object:

```json
"position": {
  ...standard fields...,
  "new_line": 50,
  "line_range": {
    "start": { "line_code": "...", "type": "new", "new_line": 42 },
    "end":   { "line_code": "...", "type": "new", "new_line": 50 }
  }
}
```

`line_code` is `<sha1(new_path)>_<old_line>_<new_line>` — but in
practice you almost never need multi-line; a single-line `new_line` on
the most representative line is enough. Skip this unless the user
explicitly asks.

## Why not `gh`?

`gh` is GitHub-only. This skill is for GitLab MRs via `glab`. The
equivalent GitHub flow uses `gh api repos/$OWNER/$REPO/pulls/$PR/comments`
with `line` and `side` parameters and works with `--field` form
encoding without this trap.

## References

- GitLab REST API — Create new merge request thread on a diff:
  https://docs.gitlab.com/ee/api/discussions.html#create-new-merge-request-thread
- Position-type `text` schema: requires `base_sha`, `start_sha`, `head_sha`,
  `new_path`, `old_path`, plus `new_line` and/or `old_line` depending on
  the line kind.
