#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$ROOT_DIR/skills"
TARGET_DIR="${1:-$HOME/.cursor/skills}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Skills directory not found: $SOURCE_DIR" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

echo "Linking skills from: $SOURCE_DIR"
echo "Linking skills into: $TARGET_DIR"

for skill_dir in "$SOURCE_DIR"/*; do
  [[ -d "$skill_dir" ]] || continue

  skill_name="$(basename "$skill_dir")"
  target_link="$TARGET_DIR/$skill_name"

  if [[ -L "$target_link" ]]; then
    existing_target="$(readlink "$target_link")"
    if [[ "$existing_target" == "$skill_dir" ]]; then
      echo "Already linked: $skill_name"
      continue
    fi

    rm "$target_link"
  elif [[ -e "$target_link" ]]; then
    echo "Skipping $skill_name (exists and is not a symlink): $target_link"
    continue
  fi

  ln -s "$skill_dir" "$target_link"
  echo "Linked: $skill_name"
done

# ---------------------------------------------------------------------------
# WorktreeCreate hook for Claude Code (~/.claude/settings.json)
# ---------------------------------------------------------------------------
# Default Claude Code worktree isolation forks subagent worktrees from
# `origin/HEAD`, leaving later exec-eng-tasks groups blind to earlier commits
# on a feature branch. Wire up a WorktreeCreate hook (user-global) so worktrees
# fork from the launching session's HEAD instead. Only runs when the user is
# installing for Claude Code; harmless idempotent — safe to re-run.

install_worktree_create_hook() {
  local settings_dir="$HOME/.claude"
  local settings_path="$settings_dir/settings.json"
  local hook_script="$SOURCE_DIR/exec-eng-tasks/worktree-create-from-head.sh"

  if [[ ! -x "$hook_script" ]]; then
    echo "Skipping WorktreeCreate hook install: $hook_script not found or not executable" >&2
    return
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "Skipping WorktreeCreate hook install: jq not found (brew install jq)" >&2
    return
  fi

  mkdir -p "$settings_dir"

  local existing
  if [[ -f "$settings_path" ]]; then
    existing="$(cat "$settings_path")"
    if ! echo "$existing" | jq empty >/dev/null 2>&1; then
      echo "Skipping WorktreeCreate hook install: $settings_path is not valid JSON" >&2
      return
    fi
  else
    existing="{}"
  fi

  if echo "$existing" | jq -e --arg cmd "$hook_script" \
    '[.hooks.WorktreeCreate // [] | .[] | .hooks // [] | .[] | select(.command == $cmd)] | length > 0' \
    >/dev/null 2>&1; then
    echo "WorktreeCreate hook already installed in $settings_path"
    return
  fi

  local updated
  updated="$(echo "$existing" | jq --arg cmd "$hook_script" \
    '.hooks.WorktreeCreate = ((.hooks.WorktreeCreate // []) + [{"hooks": [{"type": "command", "command": $cmd}]}])')"

  echo "$updated" > "$settings_path"
  echo "Installed WorktreeCreate hook in $settings_path"
}

# Only touch ~/.claude/settings.json when the user is installing for Claude Code.
case "$TARGET_DIR" in
  *.claude*) install_worktree_create_hook ;;
esac

echo "Done."
echo "Tip: pass a custom target directory as the first arg."
echo "Example: ./setup.sh \"\$HOME/.claude/skills\""
