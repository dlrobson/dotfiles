---
name: reviewing-changes
description: Review a change — a diff, branch, or uncommitted work — with parallel read-only passes for correctness, error handling, and test coverage, merged into one severity-ranked report. Use when asked to review pending changes before committing, pushing, or opening a PR. Not for auditing a codebase with no change under review, and not for applying the fixes it finds.
disable-model-invocation: true
---

# Reviewing changes

Three read-only passes over a change, run in parallel as subagents, merged into
one report. The change is the unit of review; the repository is the evidence.

## Shared contract

Binds every pass, parent and child alike.

**Scope is the change; the repository is the evidence.** Report only on lines
the change touches. Read anything you need — callers, sibling tests, the rest of
the module — to decide whether a finding is real, but never widen what you
comment on. A reviewer holding the whole repository will otherwise audit code
nobody asked about.

**Read the repository's own rules before judging anything.** Root `AGENTS.md`
and `CLAUDE.md`, plus any nested ones, define the conventions that count. Where
they speak they beat your defaults; where they are silent, so are you. Never
import conventions from another project — the repository's own files are the
only authority.

**Every finding must be grounded.** If you did not read the code that makes the
claim true, verify it or drop it. Ten real findings beat thirty plausible ones.

**One entry per finding:**

```
file:line — <severity> (confidence <0-100>)
What's wrong: <the defect, one or two sentences>
Failure: <the concrete input, state, or sequence that makes it matter>
Fix: <the smallest change that removes the defect>
```

**Severity** — impact, not certainty:

- **Critical** — breaks in realistic use, or contradicts an explicit rule in the
  repository's own instructions.
- **Important** — a real defect needing unusual conditions, or a rule the
  repository states that the change violates.
- **Suggestion** — a genuine improvement, not a preference.

**Confidence** — how sure you are the finding is real, independent of severity.
**Report nothing below 80.** A wrong finding costs more than a missing one: it
sends the reader to code that is fine and teaches them to distrust the report.

**Nothing to report is a complete answer.** Say so in one line. Do not pad a
clean result with style opinions, and do not restate the change.

## Orchestration (parent only)

Passes read this skill too. If your task names you as one pass, stop here — the
Shared contract above is what binds you.

### 1. Establish the change

Normally the branch checked out in the working directory. Take the first source
that yields a non-empty diff:

1. A diff named in the request — a path, a pasted patch, a PR number.
2. The working tree — tracked modifications **plus untracked files**.
   `git diff` alone omits untracked files, and a change made of new files is the
   common case; find them with `git status --porcelain`.
3. The branch against its base — `git diff <base>...HEAD` — for committed work.

**If all three are empty, stop and say so**, naming what you checked. An empty
diff produces a confident "nothing found", which is worse than an error.

Note the repository's own review instructions while you are here. The passes
inherit them, but you need them to read the findings.

### 2. Choose the passes

Mechanically, from the change itself:

| Pass | Agent | Run when |
|---|---|---|
| General | `review-general` | Always. |
| Errors | `review-errors` | The change adds or alters error handling: a catch/rescue/except block, an error return or propagation, a fallback or default used on failure, retry logic, or an error logged while execution continues. |
| Tests | `review-tests` | The change alters behavior tests are meant to pin — logic, branches, validation, output — or touches test files. Skip only when it cannot affect behavior: docs, comments, formatting, dependency pins, config values. |

Judge error handling and behavior by reading the diff, not by matching file
extensions or assuming a language.

**Borderline means skip, and say you skipped it.** A skipped pass is one line to
request; an unrequested pass costs tokens and buries what matters.

**Passes that do not exist yet: types, comments, simplification.** Do not
substitute the general pass for them or invent an agent. List them under
"Not covered" so the gap stays visible.

### 3. Dispatch

Launch the chosen passes as **parallel** subagents, one task each, so they run
concurrently and cannot see each other's conclusions. Use the extension's
parallel form — a single call carrying every selected task — rather than one
call per pass; separate calls are dispatched across turns and start staggered,
which loses most of the concurrency. Every task carries:

- the change, or how to produce it;
- the files and lines in scope;
- an instruction to read the `reviewing-changes` skill and follow its Shared
  contract;
- the reminder that the repository is evidence, while the report covers only the
  changed lines.

Give every pass the same change and the same scope. Divergent scope produces
findings that cannot be merged.

Do not run the passes in your own context. Their value is the isolated context
window; a single session accumulates enough diff, callers, and tests to crowd
out the review itself.

### 4. Merge

Drop everything below the confidence floor and merge what remains. Two passes
describing one line are one finding; the higher severity wins.

```markdown
# Review — <what was reviewed, one line>

Scope: <files and lines, and how the diff was produced>
Passes: <ran> · skipped: <pass and the rule that skipped it>

## Critical
- [errors] `path:line` — <issue>. <failure>. <fix>.

## Important

## Suggestions

## Not covered
- <passes not run, and why>

## Checked clean
- <what the passes examined and found nothing on>
```

Close with one sentence naming what the reader should do first. The report is
the evidence; that sentence is the answer.
