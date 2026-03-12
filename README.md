# Agents and Skills

A collection of agent definitions and skill prompts for Claude Code.

These are designed for Claude Code's agent and skill system but can be used by any harness that supports the same format.

## Structure

Each directory contains a self-contained agent or skill definition:

- `eng-manager-plan/` — Engineering manager plan review skill

## Setup

```bash
# Symlink all skills into ~/.claude/skills (default)
./setup.sh

# Or specify a different target directory
./setup.sh -t ~/.cursor/skills
```

## Usage

Skills are invoked via slash commands in Claude Code (e.g., `/plan-eng-review`).

## Authoring guidance

- Claude-focused guidance: `CLAUDE.md`
- Cursor-focused guidance: `CURSOR.md`

## License

MIT
