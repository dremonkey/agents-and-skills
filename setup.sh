#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="$HOME/.claude/skills"

while getopts "t:" opt; do
  case $opt in
    t) TARGET_DIR="$OPTARG" ;;
    *) echo "Usage: $0 [-t target_dir]" >&2; exit 1 ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "$TARGET_DIR"

for skill_dir in "$REPO_DIR"/*/; do
  name="$(basename "$skill_dir")"
  [[ -f "$skill_dir/SKILL.md" ]] || continue

  ln -snf "$skill_dir" "$TARGET_DIR/$name"
  echo "  $name -> $TARGET_DIR/$name"
done

echo ""
echo "Skills symlinked to $TARGET_DIR"
