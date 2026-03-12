---
name: draft-technical-architecture
version: 1.0.0
description: Draft technical specifications for small-scope component architecture using concise sections and ASCII diagrams, and produce full-system Excalidraw visuals by invoking excalidraw-diagram-skill when broader system context is needed. Use when the user asks for a technical spec, architecture draft, RFC-lite, component design, or implementation plan.
---

# Draft Technical Architecture

Create practical technical specs that are easy to review and implement.

## When to use this skill

Use this skill when the user asks for:
- a new technical specification
- component or subsystem architecture
- an RFC-lite for a bounded change
- implementation-ready architecture notes

This skill is optimized for **small scope** design work (single feature area, bounded component set).

## Output goals

Every spec should be:
- specific enough to implement
- explicit about assumptions and tradeoffs
- diagram-driven for faster understanding

## Workflow

1. **Scope classify first**
   - Confirm the request is small/bounded (component-level).
   - If scope is broad, split into bounded components and process one at a time.

2. **Gather constraints**
   - Problem statement, success criteria, non-goals.
   - Technical constraints (stack, interfaces, performance, security, rollout).
   - Known unknowns and open decisions.

3. **Draft the component architecture**
   - Use the template in `SPEC_TEMPLATE.md`.
   - Include concrete interfaces, data flow, and failure handling.
   - Prefer explicit decisions over abstract language.

4. **Add ASCII diagrams (required)**
   - Use ASCII to show local architecture and behavior:
     - component boundaries
     - request/data flow
     - state transitions
     - dependency direction
   - Keep diagrams close to the section they explain.

5. **Add whole-system view (when needed)**
   - If the user asks for a broader system visual, apply the `excalidraw-diagram-skill`.
   - Use Excalidraw for end-to-end/system-level context only.
   - Keep ASCII for component-level details even when Excalidraw is used.

6. **Finalize for implementation**
   - Call out risks, mitigations, and test strategy.
   - List unresolved questions clearly.
   - Ensure acceptance criteria are verifiable.

## ASCII diagram conventions

- Prefer left-to-right flow for request pipelines.
- Label every arrow with action or data shape where useful.
- Use consistent naming with the prose spec.
- Keep diagrams readable in plain markdown (no Unicode box drawing required).

### Example component flow

```text
[Client]
   |
   | POST /widgets
   v
[Widget API] ---> [Validator]
   |                  |
   | valid payload    | invalid -> 400
   v                  v
[Widget Service] --> [Widget Repo] --> [DB]
        |
        +--> [Event Bus] --> [Indexer]
```

## Spec quality checklist

- Scope is bounded and explicit.
- At least one ASCII diagram explains component behavior.
- Interfaces and contracts are concrete.
- Failure modes and edge cases are documented.
- Test plan maps to key flows and risks.
- Open questions and assumptions are visible.

## Additional resources

- Spec template: `SPEC_TEMPLATE.md`
