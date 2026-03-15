# Agents and Skills

A Claude Code plugin packaging agent definitions and skill prompts.

## Structure

```
.claude-plugin/
  plugin.json                        — Plugin manifest
skills/
  eng-manager-plan/                  — Engineering manager plan review skill
  draft-technical-architecture/      — Technical architecture drafting skill
```

## Setup

```bash
# Install as a Claude Code plugin (local)
claude plugin install ./agents-and-skills

# Install from GitHub
claude plugin install github:dremonkey/agents-and-skills

# Validate the plugin
claude plugin validate
```

## Dependencies

Some skills reference other skills that must be installed separately:

- **excalidraw-diagram-skill** — used by `draft-technical-architecture` for system-level Excalidraw diagrams

## Usage

Skills are invoked via slash commands in Claude Code (e.g., `/eng-manager-plan`).

## Authoring guidance

- Claude-focused guidance: `CLAUDE.md`
- Cursor-focused guidance: `CURSOR.md`

## License

MIT
