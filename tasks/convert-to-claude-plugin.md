# Convert repo to a Claude Code plugin

## Goal

Restructure this skills repo so it works as a Claude Code plugin — installable via `claude plugin install` and distributable through a marketplace.

## Current state

```
agents-and-skills/
├── eng-manager-plan/
│   └── SKILL.md
├── draft-technical-architecture/
│   └── SKILL.md
├── setup.sh              ← manual symlink script
├── CLAUDE.md
├── README.md
└── ...
```

Skills are installed by running `setup.sh`, which symlinks each skill directory into `~/.claude/skills/`. This is manual and fragile.

## Target state

```
agents-and-skills/
├── .claude-plugin/
│   └── plugin.json       ← manifest (metadata, component paths)
├── skills/
│   ├── eng-manager-plan/
│   │   └── SKILL.md      ← unchanged
│   ├── draft-technical-architecture/
│   │   └── SKILL.md      ← unchanged
│   └── .../
├── CLAUDE.md
├── README.md
└── ...
```

After conversion, installation is:
```bash
claude plugin install ./agents-and-skills   # local
claude plugin install github:user/repo      # remote
```

## Tasks

### 1. Create `.claude-plugin/plugin.json`

Minimal manifest:

```json
{
  "name": "agents-and-skills",
  "version": "1.0.0",
  "description": "Agent definitions and skill prompts for Claude Code — plan review, technical architecture drafting, and more.",
  "author": {
    "name": "ahanyu"
  },
  "repository": "https://github.com/ahanyu/agents-and-skills",
  "license": "MIT",
  "skills": "./skills/"
}
```

Adjust `repository` to the actual remote URL.

### 2. Move skill directories into `skills/`

Move each `<skill-name>/` directory into a `skills/` subdirectory so the plugin's `skills` path resolves correctly:

```bash
mkdir skills
git mv eng-manager-plan skills/
git mv draft-technical-architecture skills/
# repeat for any future skill directories
```

No changes needed inside the SKILL.md files — the frontmatter and content stay the same.

### 3. Remove `setup.sh`

The symlink script is replaced by `claude plugin install`. Delete it:

```bash
git rm setup.sh
```

### 4. Update `CLAUDE.md`

Update the repo structure section to reflect the new layout:

```
skills/
  <skill-name>/
    SKILL.md          — The skill prompt (required)
    *.md              — Supporting templates or references
.claude-plugin/
  plugin.json         — Plugin manifest
```

### 5. Update `README.md`

- Replace the **Setup** section: remove the `setup.sh` instructions, add `claude plugin install` usage.
- Update the **Structure** section to show the `skills/` nesting.
- Mention the plugin manifest and how to validate it (`claude plugin validate`).

### 6. Update `.gitignore` if needed

Ensure no plugin cache artifacts (if any) get committed. Typically nothing to add, but verify.

### 7. Validate

```bash
claude plugin validate
```

Confirm all skills are discovered and invocable after install.

## Out of scope

- Adding hooks, MCP servers, agents, or commands — those can come later as separate tasks.
- Marketplace publishing — just get the structure right first.
- Renaming skills or changing SKILL.md content.

## Notes

- Claude Code auto-discovers `skills/` at the plugin root even without a manifest, but including `plugin.json` gives us metadata for distribution and versioning.
- Skill invocation names don't change — they're derived from the directory name, not the plugin name.
- The `CURSOR.md` file can stay as-is; it's not part of the plugin structure.
