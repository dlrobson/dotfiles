---
name: reviewing-changes
description: Review a change — a diff, branch, or uncommitted work — judging whether the approach fits before checking it line by line, with parallel read-only passes for correctness, error handling, and test coverage, merged into one report, with every finding verified against the change before it is reported. Use when asked to review pending changes before committing, pushing, or opening a PR. Not for auditing a codebase with no change under review, and not for applying the fixes it finds.
disable-model-invocation: true
---

# Reviewing changes

Four read-only passes over a change, run in parallel as subagents, merged into
one report and then verified — a finding reaches the report only once something
has tried and failed to refute it. The change is the unit of review; the
repository is the evidence.

One of the four does not look for defects at all. It asks whether this is the
right solution — whether the repository already does this, whether the machinery
is proportional, whether the change belongs here — because a review that only
audits lines cannot see that the lines are the wrong lines.

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

**One pass is not a finding pass.** `review-approach` asks whether this is the
right solution at all, so it reports in its own shape, defined in its brief. The
scope rule and the finding format above do not bind it. The rest does: it reads
the repository's own instructions, and every claim it makes is grounded in
something it read.

## Orchestration (parent only)

Passes read this skill too. If your task names you as one pass or as the
verifier, stop here — the Shared contract above is what binds you.

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

**Then find the intent.** The approach pass judges the change against the
problem it claims to solve, and cannot do that without knowing the problem. In
order: what the request says; the commit messages under review (`git log`); the
pull request description, if there is one (`gh pr view`, when available); and
any issue those reference. Quote what you find and say where it came from.

Intent is a precondition, not a blocker. When nothing states it, say so and let
the approach pass infer the problem from the change — it marks what it inferred
and cannot then rule on fit to the problem. What it can still do is check the
change against the repository.

Note the repository's own review instructions while you are here. The passes
inherit them, but you need them to read the findings.

**Write nothing into the repository under review.** Put a staged diff or a commit
message in a temporary directory outside it. The review must not change the tree
it is judging, and a stray file becomes part of the next review's scope — this
already happened once, and the pass had to exclude its own files by name.

### 2. Choose the passes

Mechanically, from the change itself:

| Pass | Agent | Run when |
|---|---|---|
| Approach | `review-approach` | The change adds a mechanism rather than fixing one: a new module, abstraction, or file; new public surface (an exported API, config option, CLI flag, module option); a new dependency or pin; or it is large relative to the purpose it states. Skip for fixes, edits to existing behavior, renames, version bumps, and docs. |
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
built-in `parallel` workflow, a single call carrying every selected task,
rather than one call per pass; separate calls are dispatched across turns and
start staggered, which loses most of the concurrency:

```js
subagent({
  workflow: "parallel",
  async: false,
  args: { tasks: [
    { agent: "review-general", task: "..." },
    { agent: "review-tests", task: "..." },
  ] },
})
```

Every task carries:

- the change, or how to produce it;
- the files and lines in scope;
- an instruction to read the `reviewing-changes` skill and follow its Shared
  contract;
- the reminder that the repository is evidence, while the report covers only the
  changed lines.

Give every pass the same change and the same scope. Divergent scope produces
findings that cannot be merged. The approach pass additionally receives the
intent you gathered, quoted, and told whether it was stated or has to be
inferred.

Details of the call that cost time when they were guessed:

- A task item takes only `agent` and `task`. The result lists each pass's
  output in order.
- Use `async: false`. A background workflow returns at once, and a pass
  launched again because the first launch looked lost runs twice: double the
  cost, and every finding twice. The merge cannot start until every pass is
  back, so there is nothing to do meanwhile.
- Do not write a workflow script for this fan-out. It takes several turns to
  get right, and `parallel` already does the job.
- If the request names a model or thinking level for the passes, put
  `model: "provider/id:level"` on the call, and on the verifier's. Every pass
  takes it from the call. Without it a pass runs at the extension's default
  thinking level, not the parent's, so a level set only on the parent session
  does not reach them.

Do not run the passes in your own context. Their value is the isolated context
window; a single session accumulates enough diff, callers, and tests to crowd
out the review itself.

### 4. Merge

Drop everything below the confidence floor and merge what remains. Two passes
describing one line are one finding; the higher severity wins.

An observation that arrives both as an approach finding and as a line-level
finding is one finding, reported under `## Approach`. The approach version
already names the lines, and repeating it further down buries the structural
point among the nits.

### 5. Verify

A finding nobody tried to refute is a finding nobody checked. Two stages,
because most of the checking is lookup rather than judgment.

**Mechanically, yourself, before dispatching anything.** For each finding:

- does the cited line exist, and is it inside the change? A finding about
  untouched code is out of scope even when it is true;
- if a repository rule is quoted, does that wording appear in `AGENTS.md` or
  `CLAUDE.md`? Search for it rather than trusting the paraphrase.

Drop what fails — no comment needed, these are not close calls — and count them
as refuted.

Approach findings have neither a line nor a quoted rule to look up, so they pass
straight through. What gets checked for them is the alternative they name.

**Then hand what survives to `review-verify`**, one verifier per finding, each
given the change and that finding alone, in a single `parallel` call like the
one in step 3 (`async: false`, the same `model`). Verifiers run at once, so the
stage takes as long as the slowest finding rather than the sum of them, and no
verdict is coloured by the findings read before it. With more than eight
findings, group them by file so that no verifier gets more than a few.

A verifier settles what lookup cannot: for a defect, whether the failure can
occur at all given the callers, guards, and types that produce the inputs; for an
approach finding, whether the alternative it names exists and covers the case.
Pass the findings as written, not the passes' reasoning — the report is what the
reader sees, and a verifier handed the argument for a finding tends to agree with
it.

Apply the verdicts: `confirmed` stands, `corrected` replaces the finding,
`refuted` is dropped. Do not promote anything a verifier mentions into a finding
of your own.

Skip this stage when the merged report is empty.

### 6. Report

```markdown
# Review — <what was reviewed, one line>

Scope: <files and lines, and how the diff was produced>
Intent: <what the change says it is for, and where that came from — or that nothing stated it>
Passes: <ran> · skipped: <pass and the rule that skipped it>
Verification: <n> checked — <c> confirmed, <r> corrected, <f> refuted

## Approach
Problem as understood: <stated, or inferred and marked so>
Approach taken: <one line>
Fit: <verdict>
- [approach] <observation> — <the existing thing that covers it, cited>
Open questions: <what only the author can answer>

## Critical
- [errors] `path:line` — <issue>. <failure>. <fix>.

## Important

## Suggestions

## Refuted
- `path:line` — <the finding, one line>. <what refuted it>.

## Not covered
- <passes not run, and why>

## Checked clean
- <what the passes examined and found nothing on>
```

`## Approach` carries the pass's report as written, and appears only when that
pass ran. When fit is `wrong approach`, say so above the detail sections: until
that question is settled, fixing the findings below is wasted work. When fit is
`right fit`, one line is the whole section.

`## Refuted` carries refuted Critical, Important, and approach findings, one line
each with the evidence, and appears only when there are any. A refuted Suggestion
disappears — it was already the least likely to be read. Keeping the severe ones
visible is what lets the reader audit the verifier: a stage that quietly drops
findings is worse than one that never ran.

The verification counts must reconcile with what the report shows. Confirmed
plus corrected plus refuted is the number checked, and every refuted Critical,
Important, or approach finding appears under `## Refuted`. A count that does not
add up makes the audit line worthless.

Close with one sentence naming what the reader should do first. The report is
the evidence; that sentence is the answer.
