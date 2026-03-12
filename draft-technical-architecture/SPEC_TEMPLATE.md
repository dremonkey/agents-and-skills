# Technical Specification Template

Use this template for small-scope/component architecture specs.

## 1) Overview

- **Problem:** What is broken or missing?
- **Goal:** What outcome must this design achieve?
- **Non-goals:** What is intentionally excluded?

## 2) Scope and context

- **In scope:** Bounded components this spec changes.
- **Out of scope:** Adjacent concerns not addressed here.
- **Dependencies:** Services, libraries, or teams relied on.

## 3) Architecture proposal

Describe the proposed design in concrete terms:
- components and responsibilities
- interface contracts
- storage/data model changes
- control flow and data flow

### ASCII diagram (required)

```text
[Caller] -> [Boundary/API] -> [Core Component] -> [Dependency]
                  |                 |
                  v                 v
              [Validation]      [Side Effects]
```

## 4) API and data contracts

- Request/response shapes
- Event/message formats
- Schema changes and compatibility notes

## 5) Failure modes and edge cases

- Expected failure scenarios
- Error handling behavior
- Retries, idempotency, and timeouts

## 6) Security and performance

- Authn/authz impact
- Data sensitivity and access boundaries
- Latency, throughput, and scalability expectations

## 7) Rollout and migration

- Release strategy (flag, phased rollout, big bang)
- Backward compatibility plan
- Rollback strategy

## 8) Testing strategy

- Unit tests for business logic and edge cases
- Integration tests for contracts and boundaries
- End-to-end or smoke coverage for critical path

## 9) Risks and mitigations

- Key technical risks
- Mitigation steps and owners

## 10) Open questions

- Unresolved architectural decisions
- Required stakeholder input

## 11) Acceptance criteria

- [ ] Behavior works for primary flow
- [ ] Failure paths are handled and tested
- [ ] Observability/logging is sufficient
- [ ] Rollout and rollback are documented
