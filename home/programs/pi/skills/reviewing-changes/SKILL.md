---
name: reviewing-changes
description: Review pending changes — a diff, branch, or uncommitted work — before committing, pushing, or opening a PR. Judges whether the approach fits, then checks correctness, failures that leave no trace, and test coverage with parallel read-only passes, and has an independent verifier try to refute the serious findings. Invoke explicitly with /skill:reviewing-changes. Not for auditing a codebase with no change under review, and not for applying the fixes it finds.
disable-model-invocation: true
---

# Reviewing changes

Up to four read-only passes over a change, run in parallel as subagents and
merged into one report. Critical and Important findings are then checked by an
independent verifier that tries to refute each; Suggestions and Outside-the-diff
items are reported unverified and labelled so. The change is the unit of review;
the repository is the evidence.

One of the passes does not look for defects at all. It returns a verdict on the
approach — whether this is the right solution to the problem stated, compared
against at least one alternative — and an argument for it, because a review that
only audits lines cannot see that the lines are the wrong lines.

## Shared contract

Read `references/shared-contract.md` in this skill's directory now. It binds you
as well as every pass. Passes read that file and nothing else here, so the
orchestration below is for you alone.

Resolve that file to an absolute path — this SKILL.md's directory, from the
location the skill was loaded from — and put the path in every task you
dispatch. A pass that cannot read it says so and stops, and you relaunch it.

## Orchestration (parent only)

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
it is judging, and a stray file becomes part of the next review's scope.

### 2. Choose the passes

Mechanically, from the change itself:

| Pass | Agent | Run when |
|---|---|---|
| Approach | `review-approach` | The change adds a mechanism rather than fixing one: a new module, abstraction, or file; new public surface (an exported API, config option, CLI flag, module option); a new dependency or pin; or it is large relative to the purpose it states. Skip for fixes, edits to existing behavior, renames, version bumps, and docs. |
| General | `review-general` | Always. It also covers comments that contradict the code. |
| Silent failures | `review-silent` | The change contains runtime logic: it adds or alters a branch, loop, early exit, handler, default, cap, or filter, updates state, or reads a value from input or configuration. Not docs, comments, formatting, dependency pins, or test-only changes. |
| Tests | `review-tests` | The change alters behavior tests are meant to pin — logic, branches, validation, output — or touches test files. Not docs, comments, formatting, dependency pins, or config values. |

Judge behavior by reading the diff, not by matching file extensions or assuming
a language.

**When it is unclear whether a pass applies, run it** — except approach, which
has no job when nothing is being added. Say in the report header which passes
you skipped and the rule that skipped them.

Type design and simplification have no pass. Do not stretch another pass to
cover them and do not invent an agent; list them under "Not covered" so the gap
stays visible. The approach verdict may judge a change heavier than the job
needs — that is a verdict on the design, not a licence to list simplifications.

### 3. Dispatch

Launch the chosen passes as **parallel** subagents, one task each, so they run
concurrently and cannot see each other's conclusions. Use the pi-subagents
built-in `parallel` workflow, a single call carrying every selected task,
rather than one call per pass; separate calls are dispatched across turns and
start staggered, which loses most of the concurrency:

```js
subagent({
  workflow: "parallel",
  async: false,
  args: { tasks: [
    // one task per pass chosen in step 2, so also review-silent and review-approach when the table says so
    { agent: "review-general", task: "Contract: <absolute path to shared-contract.md>. Change: /tmp/review/change.diff (files: …). Intent: …" },
    { agent: "review-tests", task: "Contract: <absolute path to shared-contract.md>. Change: /tmp/review/change.diff (files: …). Intent: …" },
  ] },
})
```

Every task carries the contract path, the change or how to produce it, the files
and lines in scope, and the intent you gathered, quoted. Give every pass the same
change and the same scope: divergent scope produces findings that cannot be
merged. The approach pass is also told whether the intent was stated or has to be
inferred. A pass that answers `CONTRACT NOT READ` could not open the path: correct
it and relaunch that pass once.

Call details:

- A task item takes only `agent` and `task`. The result lists each pass's
  output in order.
- Use `async: false`. A background workflow returns at once, and a pass
  launched again because the first launch looked lost runs twice: double the
  cost, and every finding twice. The merge cannot start until every pass is
  back, so there is nothing to do meanwhile.
- Do not write a workflow script for this fan-out; `parallel` already does the
  job.
- If the request names a model or thinking level for the passes, put
  `model: "provider/id:level"` on the call, and on the verifier's. Passes take
  their model and thinking level from the call, not from the parent session.

Do not run the passes in your own context. Their value is the isolated context
window; a single session accumulates enough diff, callers, and tests to crowd
out the review itself.

### 4. Merge

Merge the findings. Two passes describing one line are one finding; the higher
severity wins. Tag each finding with the pass or passes that raised it, using the
agent's name without `review-`, such as `[general, silent]`.

**Merge findings; do not rewrite them.** Each arrives in the contract's field
shape, and that shape is the report's shape. Collapsing an entry into one
sentence — "`path:line` — <issue>. <failure>. <fix>." — throws away the labels
that make it scannable, and reverses work the pass already did. Move the fields,
add the tags, drop `Severity:` when the section heading already says it.

The approach pass returns no findings. Its verdict and argument go into the
report as written, minus nothing: you check citations, not prose, and you do not
promote a sentence of its argument into a finding of your own.

### 5. Verify

A Critical or Important finding nobody tried to refute is a finding nobody
checked. Two stages, because most of the checking is lookup rather than
judgment.

**Mechanically, yourself, before dispatching anything.** For each finding:

- Is it anchored to a changed line? If not, and it is real, move it under
  "Outside the diff". It is not counted and not verified.
- Does the cited line exist? If not, the finding is refuted: this is not a close
  call. A refuted Critical or Important finding is counted and listed under
  `## Refuted` with what you checked; a refuted Suggestion is dropped.
- Does a quoted repository rule appear in `AGENTS.md` or `CLAUDE.md`? Search for
  the wording rather than trusting the paraphrase. If it is not there, strike the
  rule from the finding. If the defect stands without it, keep the finding at the
  band it earns without the rule; refute it only when nothing else supports it.

**The approach section gets the same existence check, and no verifier.** Every
`path:line` in its verdict and argument must point at something real. Strike the
sentence whose citation fails; if the verdict rested on it, replace the verdict
with `cannot tell` and say which citation did not hold. The approach pass is a
judgement, and a second read-only agent cannot settle a judgement — it can only
agree or disagree, with no tie-break and no evidence you cannot read yourself.
What it can catch, cheaply, is a claim built on a file that is not there.

**Then hand what survives to `review-verify`** — Critical and Important findings
only; Suggestions and the approach section get the mechanical check above and no
verifier. Use one verifier per finding, each given the change and that finding
alone, in a single `parallel` call like the one in step 3 (`async: false`, the
same `model`). With more than eight findings, use one verifier per file, given
that file's findings. Verifiers run at once, so the stage takes as long as the
slowest one rather than the sum, and no verdict is coloured by the findings read
before it.

A verifier settles what lookup cannot: whether the failure can occur at all
given the callers, guards, and types that produce the inputs. Pass the findings
as written, not the passes' reasoning — the report is what the reader sees, and a
verifier handed the argument for a finding tends to agree with it.

Apply the verdicts: `confirmed` stands, `unrefuted` stands and is marked as not
established, `corrected` replaces the finding, `refuted` is dropped. A finding
corrected down to a Suggestion moves under Suggestions, marked `(checked)`. Mark
an `unrefuted` finding `(unrefuted: <what could not be established>)`. Do not
promote anything a verifier mentions into a finding of your own.

Skip this stage's verifier when there is no Critical or Important finding to
check, and write `Verification: none to check`. The approach citations are still
checked.

### 6. Report

```markdown
# Review — <what was reviewed, one line>

Scope: <files and lines, and how the diff was produced>
Intent: <what the change says it is for, and where that came from — or that nothing stated it>
Passes: <ran> · skipped: <pass and the rule that skipped it> · Verification: <n> checked (Critical, Important) — <c> confirmed, <u> unrefuted, <k> corrected, <r> refuted; approach citations checked, no verifier

## Approach

Problem: <as the pass wrote it>
Approach: <as the pass wrote it>
Alternative: <as the pass wrote it>
Verdict: <as the pass wrote it>

<the pass's argument, as prose>

Open questions: <as the pass wrote it>
Checked: <optional — what you established yourself, such as an open question you settled by evaluating something>

## Critical

### <title — the defect as a claim>
Where: `path:line` · raised by: general, silent · checked: confirmed
What's wrong: <the defect, one or two sentences>
Failure: <the input, state, or sequence that makes it matter>
Fix: <the smallest change that removes it>

## Important

## Suggestions (unverified unless marked checked)

### <title — the defect as a claim>
Where: `path:line` · raised by: tests · checked: unverified
What's wrong: <the defect, one or two sentences>
Fix: <the smallest change that removes it>

## Outside the diff (unverified)
- `path:line` — <a problem the change did not cause, one line>

## Refuted
- `path:line` — <the finding, one line>. Refuted by: <what refuted it>

## Not covered
- <what no pass covers, such as type design and simplification>

## Checked clean
- <what the passes examined and found nothing on>
```

`## Approach` carries the pass's report as written and appears only when that
pass ran. Paste its five parts into the shape above as **plain markdown, never a
fenced block**: the argument is prose meant to be read, and a fence turns it into
fixed-width text that does not wrap. Change none of its words, and do not
interleave your own notes into it — anything you established yourself, such as an
existence-checked citation or an open question you settled by evaluating something,
goes on the `Checked:` line. It sits first because the verdict decides how the
rest is read: when it is `wrong approach`, say in the argument that the findings
below are wasted work until that question is settled. `right fit` is not a
one-line answer — the argument for it is the section, and a verdict with no
argument is the thing this pass exists to prevent.

The finding sections carry the passes' entries in the contract's field shape. Do
not compress an entry into one sentence and do not drop `Failure:` above the
Suggestions band. `checked:` is `confirmed`, `unrefuted`, `corrected`,
`unverified`, or `unrefuted: <what could not be established>`. An empty section
says `None.`


`## Outside the diff` carries what the passes listed under that name, one line
each, unverified, and appears only when there are any. They get the mechanical
check that the cited line exists and no verifier.

`## Refuted` carries refuted Critical and Important findings, one line each with
the evidence, and appears only when there are any. A refuted Suggestion
disappears — it was already the least likely to be read. Keeping the severe ones
visible is what lets the reader audit the verifier: a stage that quietly drops
findings is worse than one that never ran.

`## Checked clean` merges the passes' own `Checked clean:` lines.

The verification counts must reconcile with what the report shows. Confirmed
plus unrefuted plus corrected plus refuted is the number checked, and every
refuted Critical or Important finding appears under `## Refuted`. A count that
does not add up makes the audit line worthless.

Close with one sentence naming what the reader should do first. The report is
the evidence; that sentence is the answer.
