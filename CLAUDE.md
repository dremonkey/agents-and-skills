# Agents and Skills

This repo stores agent definitions and skill prompts for Claude Code (and compatible harnesses).

## Repo structure

```
<skill-name>/
  SKILL.md          — The skill prompt (required)
  *.md              — Supporting templates or references
```

## Conventions

- Each skill lives in its own directory.
- `SKILL.md` is the entry point — it contains the full prompt that gets loaded when the skill is invoked.
- Supporting files (templates, examples) live alongside SKILL.md in the same directory.
- Keep prompts self-contained: a skill directory should have everything it needs to run.
