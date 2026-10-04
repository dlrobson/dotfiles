---
name: dependency-management
description: How external dependencies are pinned and updated in this repo. Use when adding, bumping, or referencing an external dependency.
---

# Dependency management

External versions live in `npins/sources.json`, not as literals in code. A
version written inline is easy to forget and never gets bumped; an npins pin is
centralized, visible in one file, and updated by `update-pins`. Prefer a pin for
anything external, and derive values from it rather than repeating them.

## Adding

`npins add …` decides how the dependency is tracked:

- GitHub repo with releases — `npins add github <owner> <repo>` (tracks the
  latest release).
- A branch — `npins add github <owner> <repo> --branch <branch>`.
- A tarball or URL — `npins add url --url <url>`.

## Consuming

Read the value off the pin instead of duplicating it:

```nix
sources = import ../../npins;
...
"npm:pi-web-access@${lib.removePrefix "v" sources.pi-web-access.version}"
```

## Bumping

Run `update-pins` (`npins upgrade && npins update`). It rewrites every pin's
revision and hash, so never hand-edit `sources.json` and never maintain a hash
for a pin by hand.

Corollary: don't add a hash that *is* hand-maintained. If a tool installs its
own dependencies at runtime (the npm packages Pi and opencode consume), pin the
source/version and let the tool install — don't reach for `buildNpmPackage` or a
fixed-output derivation just to get it into the store, since that adds a
build-time hash you would have to bump by hand.

Some ecosystems have no lockfile tool — VS Code marketplace extensions, for
example — so a hand-maintained hash is unavoidable there. The rule is about not
introducing one where a tool could maintain it instead.
