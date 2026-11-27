---
name: test-design
description: Rules for what a test may reach, what must be doubled, and what a double must prove — no widening production visibility for a test, tests through the public interface, seams for the outside world, and a conformance test for every double. Use when adding or changing tests, when production code is about to change so a test can reach it, or when deciding what to fake, stub, or mock.
---

# Test design

These rules bind the test and the production change that makes it possible. The
temptation is to break them from the production side, so start there.

## Never widen the production API for a test

A test is not a caller. Making something public so a test can see it publishes it
to every real caller and has to be supported from then on. A method with one
caller is still public API. Reach the code without widening it, in this order:

1. **Use what is already public.** Arrange and observe through an entry point
   real callers use.
2. **Reach it from inside.** A unit test in the same module (Rust
   `#[cfg(test)] mod`, Go same-package `_test.go`, a TS test importing the
   module) sees what the file sees, with no visibility change.
3. **Change the design.** If neither works, the seam is in the wrong place. Move
   the seam; do not publish it.

A build tag or feature flag that exports the code only to tests is still a
second API, maintained and unversioned. Do not add one for this.

"There was no other way" is a finding about the design, not a reason.

## Test through the public interface of the module under test

A test names a behaviour and asserts on what a caller observes. It does not name
a private helper, a call sequence, or an internal field. A refactor that keeps
behaviour keeps the test passing. If a rename or a split turns the test red, the
test was pinned to the implementation and has to be rewritten for nothing.

Interaction assertions are implementation tests unless the interaction *is* the
contract (a record written exactly once, a payment sent once). When it is the
contract, say so in the test name; otherwise assert on the observable result.

The module, not the program. Driving everything through the top-level entry
point multiplies paths together and the suite becomes unaffordable, so each
module is tested through its own interface and composed only where composition
is the risk.

## Double the outside world at a named seam

Anything whose behaviour leaves your system — the clock, the network, the
filesystem, randomness, the environment, another process, a third-party API —
appears in a unit test only as a double.

Production code takes each through an interface it declares (a `Clock`, a
`Store`, a client with a narrow surface) and the test supplies the double. The
seam is that interface, not a patched library global: a patched global doubles
every user of it and hides the dependency from the type.

Declare the interface your code needs, not the library's API. A port that copies
`httpx.Client` or `pgx.Conn` buys the boilerplate without the decoupling, and
still drifts when the library changes. One operation with your own types is the
usual size, and it is worth declaring only where you were about to double
something anyway.

Double what leaves your system, not what leaves the process. A database, queue,
or cache you own is out-of-process and internal, so its behaviour is yours to
assert directly. Faking it means asserting the fake, and its semantics
(constraints, isolation, locking) are what fakes get wrong. Test that layer
against the real engine in an integration test and keep the logic above it clear
of the dependency.

If the fake is not obvious to write, do not write it. Geospatial queries,
full-text search, and transaction isolation belong in integration tests.

Do not double your own code. A double of your own module is a copy of its logic
with none of its tests. Do not double the thing under test.

## Every double owes a conformance test

A double claims to behave like the real thing, and nothing tests the claim. Drift
is then silent in both directions: the double keeps the test green while
production changes underneath it, or the test passes against a fake that was
never right.

Write one behaviour suite and run it against two subjects — the real
implementation and the double. Where the real one cannot run in a test (a paid
API, a USB device, a wall clock), run the suite against a recording or a stated
expectation of real output, and say what the evidence was.

Keep doubles enumerable, one file or directory per seam, and add a test that
fails when a double has no conformance case. A double nobody verifies is a stub
with a good reputation.

## A test must be able to fail

Before trusting a test, name the change that makes it red. An assertion that
holds whatever the code does — a tautology, an assertion on the stub you just
configured, a snapshot nobody reads — reports safety that is not there, and is
worse than no test. Delete it or fix it.

For a load-bearing test, make it fail once on purpose: break the code, watch it
go red. That is the cheapest proof.

Where the repository has a mutation tool (`cargo-mutants`, Stryker, PIT, mutmut),
run it on the diff, not the whole tree, and read survivors as holes: a mutant that
lives is a line the tests run without checking. A full run belongs on a schedule,
because each mutant is a suite run and a push cannot afford thousands.

## Make a rule stick

Prose persuades one turn. When a rule here keeps being broken, move that one into
a mechanism:

- **Visibility** — a public-API snapshot diff in CI (Rust `cargo public-api`, TS
  API Extractor) turns new public surface into a reviewed change rather than a
  side effect of a test.
- **Ambient calls** — ban them at the call site: clippy `disallowed-methods` in
  `clippy.toml` for `SystemTime::now`, `std::env::var`,
  `TcpStream::connect`; eslint `no-restricted-globals` or `no-restricted-syntax`
  for `fetch` and `Date.now`. The code then cannot compile or lint without the
  seam.
- **Reaching inward** — an import boundary (eslint `no-restricted-imports`,
  dependency-cruiser) so a test cannot import an internal module. In Rust this
  is already true: `tests/` sees only the public API.
- **Unverified doubles** — the enumeration test above.
