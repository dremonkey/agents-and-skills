#!/usr/bin/env bash
# WorktreeCreate hook for Claude Code.
#
# Forks worktrees (both `--worktree` sessions and `isolation: "worktree"`
# subagents) from the launching session's current HEAD instead of the
# default `origin/HEAD`. Required for exec-eng-tasks workflows where
# Phase N agents must see commits from Phase N-1 on a feature branch.
#
# Wire up in <repo>/.claude/settings.json (substitute the absolute path
# to this file for <ABS_PATH_TO_THIS_SCRIPT>):
#   {
#     "hooks": {
#       "WorktreeCreate": [
#         { "hooks": [ { "type": "command",
#           "command": "<ABS_PATH_TO_THIS_SCRIPT>"
#         } ] }
#       ]
#     }
#   }

set -euo pipefail

INPUT=$(cat)

# Harness payload contract (observed 2026-05-07):
#   { session_id, transcript_path, cwd, hook_event_name, name }
# `name` is the agent identifier (e.g. "agent-a3a8f88ac89ff10c9"); the
# harness does NOT send `worktree_path`, so we derive it from cwd + name.
# `.worktree_name` is read as a fallback for older/alternate harness builds
# that may still use that key.
WORKTREE_NAME=$(jq -r '.name // .worktree_name // empty' <<<"$INPUT")
CWD=$(jq -r '.cwd' <<<"$INPUT")

if [[ -z "$WORKTREE_NAME" ]]; then
  echo "WorktreeCreate hook: no .name or .worktree_name in payload" >&2
  echo "payload: $INPUT" >&2
  exit 1
fi

WORKTREE_PATH=$(jq -r '.worktree_path // empty' <<<"$INPUT")
if [[ -z "$WORKTREE_PATH" ]]; then
  WORKTREE_PATH="$CWD/.claude/worktrees/$WORKTREE_NAME"
fi

cd "$CWD"

# Freeze the base to a SHA so concurrent agents don't drift if HEAD
# moves between dispatch and worktree creation.
BASE_SHA=$(git rev-parse HEAD)
BRANCH_NAME="worktree-${WORKTREE_NAME}"

git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" "$BASE_SHA" >&2

# .worktreeinclude is bypassed when this hook is configured — replicate it.
if [[ -f "$CWD/.worktreeinclude" ]]; then
  while IFS= read -r pattern; do
    [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
    if [[ -e "$CWD/$pattern" ]]; then
      mkdir -p "$WORKTREE_PATH/$(dirname "$pattern")"
      cp -r "$CWD/$pattern" "$WORKTREE_PATH/$pattern"
    fi
  done < "$CWD/.worktreeinclude"
fi

echo "$WORKTREE_PATH"
