---
name: authoring-pi-extensions
description: Extend Pi itself — author a skill, extension, prompt template, theme, or package, and choose whether it belongs at user or project level. Use when a task calls for teaching Pi a reusable capability or adding executable behavior.
---

# Authoring Pi extensions

Pi's customization points, lightest to heaviest. Reach for the first that fits.

| Want | Use | Read |
|---|---|---|
| Instructions loaded on demand, with optional bundled scripts/assets | **skill** | `pi-docs/skills.md` |
| A reusable prompt exposed as a `/command` | **prompt template** | `pi-docs/prompt-templates.md` |
| Executable behavior — tools, hooks, commands, providers, UI | **extension** | `pi-docs/extensions.md` |
| TUI colors | **theme** | `pi-docs/themes.md` |
| Ship several of the above through npm or git | **package** | `pi-docs/packages.md` |

`pi-docs/` is a symlink to the documentation bundled with the installed Pi
version, so it always matches the harness that is running.

## Where a resource lives

- **User level** (`~/.pi/agent/…`, or `$PI_CODING_AGENT_DIR` if set): applies in
  every working directory. Right for personal capabilities.
- **Project level** (`.pi/…` inside a repo): applies only there, and loads only
  after project trust is granted. Right for repo-specific workflows.

Skills are additionally discovered from the Agent Skills locations
`~/.agents/skills/` and `.agents/skills/`.

| Resource | Conventional directory | `settings.json` key |
|---|---|---|
| Skills | `~/.pi/agent/skills/` | `skills` |
| Extensions | `~/.pi/agent/extensions/` | `extensions` |
| Prompt templates | `~/.pi/agent/prompts/` | `prompts` |
| Themes | `~/.pi/agent/themes/` | `themes` |
| Packages | — | `packages` |

Paths listed in `settings.json` load *in addition* to the conventional
directories. Relative paths resolve from the agent directory for user settings
and from `.pi/` for project settings; absolute paths and `~` also work.

## Creating a skill

A skill is a directory containing `SKILL.md`:

```text
my-skill/
├── SKILL.md
├── scripts/
└── references/
```

```markdown
---
name: my-skill
description: What it does. Use when <trigger>.
---

Instructions. Refer to bundled files by paths relative to this directory.
```

The **description is the routing contract.** Pi lists only each skill's name and
description until a matching task loads the body, so state both what the skill
covers and when to use it. `disable-model-invocation: true` hides it from
automatic selection; force a load with `/skill:my-skill`.

## Verify

Start Pi where the resource is discoverable and watch the startup diagnostics.
`pi config` shows discovered resources, `/skill:name` forces a skill, and
`/reload` picks up edits in a live session.

## In this dotfiles repo

Do not hand-place skills in `~/.pi/agent/`. Author them under
`home/programs/pi/skills/<name>/SKILL.md`; `pi.nix` builds each into a
self-contained directory and registers it through `settings.json`. A consuming
deployment can add its own with the `pi.skills` option.
