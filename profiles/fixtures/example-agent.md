---
name: example
description: Coverage fixture. Never deployed.
tools: read
---

Fixture agent for `profiles/coverage.nix`. Exists so the `pi.agents` code path
in `pi.nix` is built by `run-tests`, which the minimal and desktop profiles
leave empty.
