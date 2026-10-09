---
name: writing-good-skills
description: Write or improve the content of a SKILL.md so it triggers reliably and actually helps — description wording, scope, what to include or cut, progressive disclosure, and how to test it. Use when drafting, reviewing, trimming, or debugging a skill that doesn't trigger or doesn't help, even if the user doesn't say "skill quality". For where a skill lives and how it is deployed, use authoring-pi-extensions.
---

# Writing good skills

Craft guidance for the *content* of a skill. Placement and Nix wiring live in
`authoring-pi-extensions`. This is a distillation of the open Agent Skills
guidance; read the sources when a point needs more depth:

- https://agentskills.io/skill-creation/best-practices
- https://agentskills.io/skill-creation/optimizing-descriptions
- https://agentskills.io/specification (hard limits, e.g. description ≤ 1024 chars)

## 1. Start from real material, not general knowledge

A skill written from the model's general knowledge comes out generic ("handle
errors appropriately") and adds nothing. Ground it in something concrete:

- **A task just done in conversation.** Extract the steps that worked, the
  corrections the user made, input/output formats, and project facts the agent
  didn't know.
- **Existing artifacts.** Runbooks, style guides, schemas, review comments,
  fix commits, real failure reports.

If neither exists, do the task once with the user first, then write the skill.

## 2. Scope: one coherent unit of work

Treat a skill like a function. Too narrow and several must load for one task;
too broad and it can't be triggered precisely. Check existing skills for
overlap before adding one.

## 3. Description is the trigger

Only name and description are visible until the skill loads, so the description
carries all routing. Write it to:

- say what it does **and** when to use it, in imperative form ("Use when…");
- describe user intent, not implementation;
- be a little pushy — name contexts where the user won't use the obvious
  keywords ("even if they only describe…");
- say what it is *not* for when a neighbour skill is easy to confuse with it;
- stay short (a few sentences) and under 1024 characters.

Agents skip skills for tasks they can handle alone, so a skill only earns its
place on specialised knowledge, not trivial one-step jobs.

## 4. Body: add what the agent lacks, cut what it knows

For each paragraph ask: *would the agent get this wrong without it?* If not,
cut it. Prefer:

- **Gotchas** — concrete corrections to mistakes the agent will make. Often the
  highest-value content. Keep them in `SKILL.md`, not a reference file.
- **A default, not a menu.** Pick one approach; mention alternatives briefly.
- **Procedures over declarations.** Teach how to approach a class of problem,
  not the answer for one instance.
- **Templates** for required output formats; agents pattern-match them well.
- **Checklists / validate-then-fix loops** for multi-step or fragile work.
- **Why, not shouting.** Explain the reason behind a rule. Reserve rigid steps
  for fragile operations; give freedom where several approaches are fine. A
  wall of ALWAYS/NEVER is a sign the reasoning is missing.

Moderate detail beats exhaustive coverage: extra edge cases can send the agent
down irrelevant paths.

## 5. Progressive disclosure

Keep `SKILL.md` under ~500 lines. Move bulky material to `references/`,
`assets/` or `scripts/` and say *when* to load each ("Read
`references/api-errors.md` if the API returns non-200"), not just "see
references/". Use paths relative to the skill directory. Bundle a script when
the step is deterministic, or when test runs show the agent re-inventing the
same helper each time.

## 6. Test it (pi has no eval harness — do it by hand)

Pi can run non-interactively, which is enough:

```sh
# With the draft skill only (path to the skill dir), no other skills
pi -p --no-session --no-skills --skill ./my-skill "<realistic prompt>"
# Baseline: same prompt, no skills at all
pi -p --no-session --no-skills "<realistic prompt>"
```

Add `--mode json` to see tool calls and confirm whether `SKILL.md` was read.

**Test runs are real runs.** The agent can write files, and one test run once
created a file in `~/.pi/agent/` by itself. For skills that give advice (where
to put things, how to do X), add a read-only allowlist so the test can't change
anything, e.g. `--tools read,grep,find,ls`. For skills that must act, run in a
scratch copy of the repo. Afterwards check `git status` and any directories the
skill touches for stray files.

**Output quality.** Write 2–3 realistic prompts (file paths, backstory, casual
phrasing). Compare with-skill against baseline. If the baseline is already
good, the skill isn't adding value — trim it or drop it. Read the transcripts,
not just the result: instructions that cause wasted steps should go.

**Triggering.** Write ~10 prompts that should trigger and ~10 that shouldn't.
Make the negatives *near-misses* that share keywords but need something else.
Run each a few times (behaviour varies) without `--skill` forcing — install it
where it is auto-discovered, e.g. via `pi.skills`, or run with `--skill` and
no other skills so discovery is the only path. When revising, fix categories
of failure rather than pasting in keywords from failed prompts, and hold some
prompts back to check you haven't overfit.

**Generalise.** Iterate on feedback, but make changes that help the whole class
of task, not just the few prompts you've been staring at.

## Pitfalls

- Vague or purely descriptive description ("Helps with PDFs").
- Skill restates what the model already knows, or duplicates `AGENTS.md`.
- Multiple options with no default.
- Deeply nested references the agent never opens.
- Time-sensitive facts that will rot.
- Skill covers two jobs; split it.
