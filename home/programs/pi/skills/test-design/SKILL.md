---
name: test-design
description: Decide what to test and how — what a test may reach, what to double, and when to stop adding tests. Use when writing or changing tests, making code testable, adding a call to the clock, network, filesystem, environment, randomness or another process, choosing what to mock, stub or fake, or fixing a flaky test. Not for running a suite or debugging a CI failure that is not flakiness.
---

# Test design

## Ask before testing grows the change

Tests that fit the change go with it, without asking. Ask the user first when
good testing would cost more than the change itself:

- production code needs a new seam or a redesign before it can be tested, in
  code the change does not otherwise touch (a clock or client parameter on the
  function you are writing is part of the change);
- the right test needs infrastructure the repository lacks, such as an
  integration harness or a conformance suite;
- the code the change touches has no tests, and pinning it first is worth it.

Say what you would add, the regression it prevents, and roughly how large it is.
If no one can answer (a non-interactive run), make the change without it and
list the proposal in your summary.

## Start with a budget

A test is worth its maintenance. Name the regression it prevents: the future
change that would break and go unnoticed without it. If you cannot name one, the
test is not worth writing.

- One test per behaviour. A bug fix gets one regression test that fails on the
  old code. A new branch or error path gets a success case and a failure case.
- Docs, comments, formatting, dependency bumps, generated code, and wiring with
  no branch of its own get no unit test. Wiring is covered once, end to end,
  where the composition is the risk.

## Never widen the production API for a test

Making something public so a test can see it publishes it to every real caller,
and it has to be supported from then on. A method with one caller is still
public API. Reach the code without widening it, in this order:

1. **Use what is already public.** Arrange and observe through an entry point
   real callers use.
2. **Reach it from inside.** A test inside the module may call the module's
   internal interface: unexported items that other code in the module calls.
   Rust: a `#[cfg(test)] mod` in the same file. TypeScript has no module-private
   test scope, so a separate test file sees only exports. Where the repository
   uses Vitest, an in-source test (`if (import.meta.vitest)`, stripped from the
   build by `define`) is inside the module. Under Jest or `node:test` a test in
   the module file ships with it, so test through the public interface instead.
3. **Change the design.** If neither works, the seam is in the wrong place. Move
   the seam; do not publish it. A redesign grows the change, so ask first.

A build tag or feature flag that exports the code only to tests is still a
second API, maintained and unversioned. It counts as widening. So does a
production branch that checks for a test run (`cfg!(test)`,
`NODE_ENV === 'test'`).

## Test through the public interface of the module under test

A test names a behaviour and asserts on what a caller observes. It does not name
a helper only one function calls, a call sequence, or an internal field. A
refactor that keeps behaviour keeps the test passing.

Interaction assertions are implementation tests unless the interaction *is* the
contract (a record written exactly once, a payment sent once). When it is the
contract, say so in the test name; otherwise assert on the observable result.

The module, not the program. Driving everything through the top-level entry
point multiplies paths together and the suite becomes unaffordable, so each
module is tested through its own interface and composed only where composition
is the risk.

## Ambient dependencies

An ambient dependency is anything code reaches without being passed it: the
clock, randomness, the environment, the filesystem, the network, a database,
another process. Which kind it is decides what the test does with it:

- **Owned** — your system owns it, and a test can create it, put it in a known
  state, and throw it away: a database, queue, or cache only your system uses;
  a directory the test creates. Use the real one. Its semantics (constraints,
  isolation, locking) are what fakes get wrong, and faking it means asserting
  the fake. Test that layer against the real engine in an integration test, and
  keep the logic above it free of the dependency.
- **External** — everything else: the clock, randomness, environment variables
  (process-wide, so parallel tests see each other's), a third-party API, a
  service or file another system owns. A unit test reaches it only through a
  double, at a seam.

Production code takes each external dependency through an interface it declares
(a `Clock`, a client with a narrow surface) and the test supplies the double.
The seam is that interface, not a patched library global: a patched global
doubles every user of it and hides the dependency from the type.

Declare the interface your code needs, not the library's API. A port that copies
`httpx.Client` or `reqwest::Client` buys the boilerplate without the decoupling,
and still drifts when the library changes. One operation with your own types is
the usual size, and it is worth declaring only where you were about to double
something anyway.

If a double of an external dependency is not obvious to write, do not write it.
Test against the real one in an integration test instead.

Do not double your own code. A double of your own module is a copy of its logic
with none of its tests. Do not double the thing under test.

## A double with behaviour owes a conformance test

Nothing tests a double's claim to behave like the real thing, so drift is
silent.

A double that only returns what the test hands it — a fixed clock, a seeded
random source, a canned response — claims nothing, so it needs no conformance
test. One with its own behaviour, such as an in-memory fake of an API, does.

Write one behaviour suite and run it against two subjects — the real
implementation and the double. Where the real one cannot run in a test (a paid
API, a USB device), run the suite against a recording or a stated
expectation of real output, and say what the evidence was.

## Each test owns its state

- Create the owned dependencies the test needs — a temp directory, a fresh
  database — and any fakes, and remove them in teardown, even when the test
  fails.
- Poll for the condition, or advance the clock seam, instead of sleeping for a
  fixed time. A test that waits 100 ms fails on a slow machine.
- A flaky test is a bug. Find the variance (time, randomness, shared state,
  order, network) and remove it. Do not retry it green, and do not delete it.

## A test must be able to fail

Before trusting a test, name the change that makes it red. An assertion that
holds whatever the code does — a tautology, an assertion on the stub you just
configured, a snapshot nobody reads — reports safety that is not there, and is
worse than no test. Delete it or fix it.

When an existing test goes red after your change, first decide whether the
behaviour was meant to change. If it was, update the assertion and say so in
your summary. If not, fix the code. Never loosen an assertion, re-record a
snapshot, or skip or ignore a test only to get green.

For a load-bearing test, make it fail once on purpose: break the code, watch it
go red.

Where the repository has a mutation tool, run it on the change only
(`cargo mutants --in-diff`, Stryker `--mutate <files>`) and read survivors as
holes. A run over the whole crate or package can take hours.
