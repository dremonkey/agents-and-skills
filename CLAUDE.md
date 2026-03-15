# Agents and Skills

This repo stores agent definitions and skill prompts for Claude Code (and compatible harnesses).

## Repo structure

This repo is a Claude Code plugin.

```
.claude-plugin/
  plugin.json         — Plugin manifest (metadata, component paths)
skills/
  <skill-name>/
    SKILL.md          — The skill prompt (required)
    *.md              — Supporting templates or references
```

## Conventions

- Each skill lives in its own directory under `skills/`.
- `SKILL.md` is the entry point — it contains the full prompt that gets loaded when the skill is invoked.
- Supporting files (templates, examples) live alongside SKILL.md in the same directory.
- Keep prompts self-contained: a skill directory should have everything it needs to run.

## Skill authoring notes

- Keep runtime `SKILL.md` files behavior-focused; do not include meta notes about cross-platform compatibility in the skill body.
- Use simple YAML frontmatter (`name`, `description`, optional `version`) for portability.
- Avoid platform-specific invocation syntax in skill instructions; reference related skills by name.
