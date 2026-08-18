# Contributing to essential8

Thank you for helping build reliable cardiovascular health scoring software.

## Ways to contribute

- Report a suspected scientific-rule discrepancy.
- Add or review independently derived validation fixtures.
- Improve input validation, documentation, or package infrastructure.
- Propose a reference adapter with a documented provider and source profile.

## Scientific rule changes

Scientific rule pull requests require more than ordinary code review:

1. Open a scientific-rule issue identifying the standard, metric, population,
   measurement pathway, and exact source locator.
2. Update the evidence ledger before transcribing values.
3. Add rules with status `transcribed` and complete boundary semantics.
4. Add exact-boundary, near-boundary, compound-logic, and modifier tests.
5. Supply golden expectations derived independently of package output.
6. Obtain review from a second person who compares every transcribed value
   directly with the source.
7. Record the reviewer and verification date only after discrepancies are
   resolved.

The author of a transcription must not be its sole scientific verifier.

## Code contributions

- Follow snake_case naming and two-space indentation.
- Keep public functions focused and type-stable.
- Use namespace-qualified dependency calls in package code.
- Add tests for new behavior and structured error classes.
- Run `devtools::document()`, `devtools::test()`, and `devtools::check()` before
  submitting a pull request.

## Pull requests

Keep changes focused. Describe the scientific or engineering motivation,
verification performed, and any backward-compatibility implications. Do not
mix a rule change with an unrelated refactor.

