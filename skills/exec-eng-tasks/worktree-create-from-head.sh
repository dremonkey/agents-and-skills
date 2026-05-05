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
WORKTREE_NAME=$(jq -r '.worktree_name' <<<"$INPUT")
WORKTREE_PATH=$(jq -r '.worktree_path' <<<"$INPUT")
CWD=$(jq -r '.cwd' <<<"$INPUT")

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
