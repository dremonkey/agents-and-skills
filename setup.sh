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

echo "Done."
echo "Tip: pass a custom target directory as the first arg."
echo "Example: ./setup.sh \"\$HOME/.claude/skills\""
