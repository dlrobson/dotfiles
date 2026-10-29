# Shared contract

Binds every pass, parent and child alike. A pass reads this file and nothing
else from the `reviewing-changes` skill.

**Scope is the change; the repository is the evidence.** Focus on what the
change causes or exposes. Read anything you need — callers, sibling tests, the
rest of the module — to decide whether a finding is real. Anchor each finding to
the changed line that is responsible, even when the code that breaks is outside
the diff; name that code in the finding. A problem the change did not cause may
be noted under "Outside the diff", but do not go looking for one: a reviewer
holding the whole repository will otherwise audit code nobody asked about.

**Read the repository's own rules before judging anything.** Root `AGENTS.md`
and `CLAUDE.md`, plus any nested ones, define the conventions that count. Where
they speak they beat your defaults. On conventions and style, where they are
silent, so are you; a defect needs no rule behind it. Never import conventions
from another project — the repository's own files are the only authority.

**Every finding must be grounded.** Read the code that makes the claim true; if
the claim rests on nothing you read, drop it. Within your remit, report real
problems however small: a wrong comment, a log message that does not match what
happens. Do not report preferences or style a linter would catch. Severity sorts
what you report; it is not a reason to leave something out.

**One entry per finding:**

```
file:line — <severity>
What's wrong: <the defect, one or two sentences>
Failure: <the concrete input, state, or sequence that makes it matter>
Fix: <the smallest change that removes the defect>
```

**Severity** — impact, not certainty:

- **Critical** — breaks in realistic use, or violates a repository rule worded
  as mandatory (must, never, always).
- **Important** — a real defect needing unusual conditions, or a violation of
  any other rule the repository states.
- **Suggestion** — real but minor: a small inaccuracy (such as a comment that
  contradicts the code) or an improvement worth making, not a matter of taste.
  Suggestions are not verified; the report says so.

There is no confidence, score or floor. Rank findings by severity only; nothing
is left out for seeming unimportant or unlikely.

**End your report with two lines.** `Outside the diff:` lists, one per line as
`path:line — <problem>`, problems you noticed that the change did not cause, or
says `none`. `Checked clean:` names what you examined and found nothing on.

**Nothing to report is a complete answer.** Say so in one line. Do not pad a
clean result with style opinions, and do not restate the change.

**A pass whose own brief defines a different report shape follows that shape**,
not the finding format, the report-everything rule, or the two closing lines. The
approach pass and the verifier are such passes. The rest of this contract binds
them: read the repository's own rules, and ground every claim in something you
read.
