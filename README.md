# Agents and Skills

A Claude Code plugin packaging agent definitions and skill prompts.

## Structure

```
.claude-plugin/
  plugin.json                        — Plugin manifest
setup.sh                             — Symlink helper for Cursor-compatible harnesses
skills/
  plan-eng-tasks/                    — Engineering manager plan review skill
  draft-technical-architecture/      — Technical architecture drafting skill
```

## Installation

```bash
# Install as a Claude Code plugin (local)
claude plugin install ./agents-and-skills

# Install from GitHub
claude plugin install github:dremonkey/agents-and-skills

# Validate the plugin
claude plugin validate
```

### Cursor (and other compatible harnesses)

Use the symlink helper script to link every skill in `skills/` into your local skills directory:

```bash
# Default target: ~/.cursor/skills
./setup.sh

# Optional: provide a custom target directory
./setup.sh "$HOME/.cursor/skills"
```

The script is idempotent: it keeps existing correct links and only creates or updates missing links.

## Dependencies

Some skills reference other skills that must be installed separately:

- **excalidraw-diagram-skill** — used by `draft-technical-architecture` for system-level Excalidraw diagrams

## Usage

Skills are invoked via slash commands in Claude Code (e.g., `/plan-eng-tasks`).

## Authoring guidance

- Claude-focused guidance: `CLAUDE.md`
- Cursor-focused guidance: `CURSOR.md`

## License

MIT
