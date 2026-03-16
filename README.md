# Agents and Skills

A Claude Code plugin packaging agent definitions and skill prompts.

## Skills

| Skill name | Role | Short description |
| --- | --- | --- |
| `plan-eng-tasks` | Engineering manager execution lead | Converts approved scope into dependency-aware task plans and drives execution via structured tasks and sub-agents. |
| `plan-ceo-review` | CEO/founder strategic reviewer | Challenges plans at product and strategic levels with expansion/hold/reduction review modes. |
| `plan-cto-review` | CTO technical reviewer | Performs deep technical readiness review across architecture, risks, security, testing, and rollout. |
| `orchestrate-initiative-planning` | Planning workflow orchestrator | Coordinates CEO review, CTO review, and engineering task planning from PRD through EPICs and task files without implementation. |
| `draft-technical-architecture` | Technical architect | Produces architecture drafts with clear system design, tradeoffs, and implementation direction. |

## Structure

```
.claude-plugin/
  plugin.json                        — Plugin manifest
setup.sh                             — Symlink helper for Cursor-compatible harnesses
skills/
  <skill-name>/
    SKILL.md
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

## Artifact path conventions

Use these canonical paths for planning and execution artifacts:

- Product strategy artifacts: `vision/<INITIATIVE>/VISION.md` and `vision/<INITIATIVE>/PRD.<TOPIC>.md`
- Technical architecture artifacts: `docs/architecture/<INITIATIVE>/`
- Execution artifacts (epics + tasks): `tasks/<EPIC_NAME>/`

Recommended handoff flow:

- `plan-ceo-review` -> `vision/<INITIATIVE>/...`
- `plan-cto-review` -> `docs/architecture/<INITIATIVE>/` + `tasks/<EPIC_NAME>/EPIC.md`
- `plan-eng-tasks` -> updates `tasks/<EPIC_NAME>/...` and `docs/architecture/<INITIATIVE>/` as implementation details are discovered
- `orchestrate-initiative-planning` -> coordinates the full handoff across all three stages

## Authoring guidance

- Claude-focused guidance: `CLAUDE.md`
- Cursor-focused guidance: `CURSOR.md`

## License

MIT
