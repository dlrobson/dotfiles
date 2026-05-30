---
name: Spec Sidecar Policy
description: Global Copilot workflow for lightweight per-topic living spec documentation across repositories
applyTo: "**"
---

# Spec Sidecar Policy

Superpowers skills remain the primary workflow driver.

Use lightweight per-topic spec files as a sidecar for continuity and decision history, not as a hard gate.

## Spec Model

One living spec file per topic. Do not create a new file per task or session — update the existing topic file.

Preferred path: `docs/specs/<topic>.md`

Fallback when `docs/` is absent: `.agent-context/specs/<topic>.md`

Examples: `docs/specs/auth.md`, `docs/specs/database.md`, `docs/specs/ci.md`

## When To Read A Spec

Before generating code, proposals, or plans for any topic — check whether a spec file exists for that topic. If it does, read it first.

Pay particular attention to the most recent handoff note and any superseded decisions.

## When To Create Or Update A Spec

Create a new topic spec when starting substantial work on a new domain.

Update an existing topic spec when:

- A major architectural decision is made
- Tooling or approach changes
- Scope or constraints shift significantly

Skip for trivial, obvious, single-step edits.

## Decision Entry Format

Decision entries must be short and timestamped:

    - [YYYY-MM-DD] Chose X over Y because Z.

When a past decision is superseded, annotate it rather than rewriting:

    - [YYYY-MM-DD] Used approach A. — *Superseded YYYY-MM-DD: switched to B because Z.*

## Session Continuity

At the end of a session involving a spec topic, append a short handoff note to the relevant topic spec:

- What changed this session
- What to read first next session

## Priority And Overrides

If repository-specific instructions define stronger conventions, follow repository conventions.
