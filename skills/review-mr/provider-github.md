# Provider: GitHub (`gh`)

Platform mechanics for reviewing a **GitHub pull request (PR)**. `SKILL.md` and
the mode files call these operations by name; this file is the only place that
knows `gh`. Every GitHub interaction goes through `gh` / `gh api` — `WebFetch`
cannot authenticate against private repos, and `glab` is GitLab-only.

## Identifiers to capture once

Run `view-change` first and record, for use by every later operation:

- `<NUMBER>` — the PR number.
- `<OWNER>/<REPO>` — the repository (the `--repo` value).
- `<HEAD_SHA>` — the PR's current head commit. Required as `commit_id` for
  every line-tied comment. (GitHub anchors line comments to the head SHA + a
  `side`; there is no GitLab-style three-SHA `diff_refs`.)

GitHub line-comment line numbers must reference a line **that appears in the
PR's diff** — comments on unchanged context lines are rejected. This differs
from GitLab, which accepts context-line positions.

---

## view-change

Fetch PR metadata and the head SHA.

```bash
gh pr view <NUMBER> --repo <OWNER>/<REPO> \
  --json number,title,headRefName,baseRefName,body,url

gh pr view <NUMBER> --repo <OWNER>/<REPO> \
  --json commits -q '.commits[] | "\(.oid[0:9])  \(.messageHeadline)"'   # commit subjects

gh api "/repos/<OWNER>/<REPO>/pulls/<NUMBER>" \
  -q '{number:.number, head_sha:.head.sha, base_sha:.base.sha, head_ref:.head.ref, base_ref:.base.ref}'
```

Record `number`, `head_sha`. If the PR receives a new push before you publish,
refetch `head_sha`.

## list-files

Changed files with additions/deletions, for the plan-vs-code classification.

```bash
gh api "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/files" --paginate \
  -q '.[] | "\(.filename)  (+\(.additions)/-\(.deletions))"'
```

## my-prior-notes

The current reviewing user's own prior review activity — used to decide
IMPL-FIRST vs. FOLLOWUP. Resolve the username dynamically; never hardcode it.
GitHub splits review activity across three endpoints; check inline review
comments and review summaries:

```bash
ME=$(gh api user -q .login)

# Inline (line-tied) review comments authored by me:
gh api "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/comments" --paginate \
  -q "[.[] | select(.user.login==\"$ME\") | {id, path, line, created_at, body: .body[0:120]}]"

# Review summaries authored by me (non-empty body = a real review pass):
gh api "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/reviews" --paginate \
  -q "[.[] | select(.user.login==\"$ME\" and (.body|length>0)) | {id, state, submitted_at, body: .body[0:120]}]"
```

- Both empty → **IMPL-FIRST**.
- Substantive review content → **FOLLOWUP**.
- Only PR issue-comment chitchat, no review comments/summaries → ambiguous;
  ask the user.

## raw-file

Pull a file's full contents at a SHA (full-context reading + line mapping).

```bash
gh api "/repos/<OWNER>/<REPO>/contents/<path>?ref=<SHA>" \
  -H "Accept: application/vnd.github.raw" > /tmp/<basename>
```

`<SHA>` is `<HEAD_SHA>` for current-state reads. If the PR is a local checkout,
`git show <SHA>:<path>` is faster.

## post-top-level

**On GitHub this is fused with `post-line-comment`.** The Reviews API carries
the top-level body *and* every line-tied comment in one atomic submission, so
the top-level narrative is the `body` field of the batched review built in
`post-line-comment` below — there is no separate top-level call in the normal
path. (The fallback posts it as a standalone PR issue comment only when the
batch fails.)

## post-line-comment

**GitHub fuses `post-top-level` and `post-line-comment` into one batched
review.** The Reviews API attaches the top-level body and every line-tied
comment as a single atomic review — one notification, one accept/dismiss.
Build the payload once; do not post the narrative and the line comments
separately unless the batch fails (see fallback).

Find each `line` by grepping the raw file from `raw-file` for the target
phrase — never guess from the diff hunk.

```bash
cat > /tmp/review.json <<'EOF'
{
  "body": "## <Framing title>\n\n<narrative per mode>",
  "event": "COMMENT",
  "comments": [
    { "path": "tasks/<EPIC>/EPIC.md", "line": 42, "side": "RIGHT",
      "body": "<comment body — markdown>" },
    { "path": "apps/foo/bar.ts", "start_line": 10, "line": 14,
      "start_side": "RIGHT", "side": "RIGHT", "body": "<multi-line comment>" }
  ]
}
EOF

gh api --method POST "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/reviews" --input /tmp/review.json
```

`event` is `COMMENT`, `APPROVE`, or `REQUEST_CHANGES`. The response carries the
review `id` and each comment `id` — capture them. **Unlike GitLab, a bad line
fails loudly:** if any comment targets a line not in the diff, GitHub rejects
the *whole* review with HTTP 422. Fix the line and resubmit — there is no
silent-drop failure mode to guard against.

Field rules:

- **`side: RIGHT`** for the new version of the file (the typical case); `LEFT`
  only for a removed line.
- **`line` must appear in the PR diff.** To comment on an unchanged context
  line, anchor to the nearest changed line and describe the target in the body.
- **Multi-line** needs `start_line`+`line` and `start_side`+`side` (both
  `RIGHT` typically).
- **Single-quoted heredoc (`<<'EOF'`)** prevents shell interpolation of
  backticks/dollars/quotes in the markdown.

### Fallback — separate top-level + per-line (only if the batch 422s)

```bash
# Top-level narrative as a PR issue comment:
gh pr comment <NUMBER> --repo <OWNER>/<REPO> --body-file /tmp/top-level.md

# Each line-tied comment individually:
gh api --method POST "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/comments" \
  -f body="<comment body>" -f commit_id="<HEAD_SHA>" \
  -f path="path/to/file.md" -F line=42 -f side="RIGHT"
```

## list-prior-threads

All of the current user's prior review threads, with line positions and
resolution state — the FOLLOWUP resolution-audit input. Resolution state is
GraphQL-only (the REST comments endpoint has no `isResolved`).

```bash
ME=$(gh api user -q .login)

gh api graphql -f query='
query($owner:String!,$repo:String!,$num:Int!,$cur:String){
  repository(owner:$owner,name:$repo){
    pullRequest(number:$num){
      reviewThreads(first:100, after:$cur){
        pageInfo{ hasNextPage endCursor }
        nodes{
          id isResolved isOutdated
          comments(first:1){ nodes{ databaseId author{login} path line originalLine body createdAt } }
        }
      }
    }
  }
}' -F owner=<OWNER> -F repo=<REPO> -F num=<NUMBER> -f cur="" | python3 -c "
import json, sys
me = sys.argv[1]
d = json.load(sys.stdin)
for t in d['data']['repository']['pullRequest']['reviewThreads']['nodes']:
    c = (t['comments']['nodes'] or [{}])[0]
    if c.get('author', {}).get('login') != me: continue
    print(json.dumps({
      'thread_id': t['id'],          # GraphQL node id — needed to resolve
      'comment_id': c.get('databaseId'),  # REST id — needed to reply
      'resolved': t['isResolved'],
      'outdated': t['isOutdated'],
      'path': c.get('path'),
      'line': c.get('line') or c.get('originalLine'),
      'body_preview': (c.get('body') or '')[:200],
    }))
" "$ME"
```

Paginate via `pageInfo.endCursor` into `$cur` if `hasNextPage`. Capture per
thread: `thread_id` (to resolve), `comment_id` (to reply), `resolved` (skip
those), `path`+`line` of the prior pin, and the original body. Skip threads
where the first comment's author isn't the reviewing user.

## prior-review-head

The head SHA at the time of the last review — the delta boundary. The
`commit_id` on the reviewing user's most recent review is that head.

```bash
ME=$(gh api user -q .login)

gh api "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/reviews" --paginate \
  -q "[.[] | select(.user.login==\"$ME\")] | sort_by(.submitted_at) | last | {commit_id, submitted_at}"
```

The `commit_id` is `<PRIOR_HEAD>`.

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
gh api "/repos/<OWNER>/<REPO>/compare/<PRIOR_HEAD>...<HEAD_SHA>" \
  -q '.files[].filename'
```

## reply-thread

Append a comment to an existing review thread (FOLLOWUP follow-ups /
acknowledgments). `<COMMENT_ID>` is the `comment_id` (REST databaseId) of the
thread's first comment from `list-prior-threads`.

```bash
gh api --method POST \
  "/repos/<OWNER>/<REPO>/pulls/<NUMBER>/comments/<COMMENT_ID>/replies" \
  -f body="$(cat <<'EOF'
<follow-up body>
EOF
)"
```

**Note first, resolve second.** A reply added *after* resolving lands in a
collapsed thread.

## resolve-thread

Mark a review thread resolved. GraphQL-only; `<THREAD_ID>` is the `thread_id`
(node id) from `list-prior-threads`.

```bash
gh api graphql -f query='
mutation($id:ID!){ resolveReviewThread(input:{threadId:$id}){ thread{ isResolved } } }' \
  -F id=<THREAD_ID>
```

## delete-note

Remove a mis-posted review comment, before reposting.

```bash
gh api --method DELETE "/repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID>"
```

## post-publish report fields

For the Step 7d report: review URL
(`https://github.com/<OWNER>/<REPO>/pull/<NUMBER>#pullrequestreview-<ID>`); each
line-tied comment as `file:line` + topic + comment ID; FOLLOWUP thread actions
(resolved / replied); any open threads.

## GitHub anti-patterns

- **Don't use `glab` or `WebFetch` for GitHub.** `gh` is the only authenticated
  path.
- **Don't post the narrative and line comments separately by default.** The
  batched Reviews API is one atomic review; piecemeal posting yields N
  notifications and no review record. Use the fallback only when the batch
  422s.
- **Don't target a `line` that isn't in the diff.** GitHub 422s the whole
  review; re-anchor to a changed line.
- **Don't refetch the resolution state from REST.** `isResolved` is GraphQL
  (`reviewThreads`) only.
