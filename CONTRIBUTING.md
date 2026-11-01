# Contributing to essential8

Thank you for helping improve essential8!

## Ways to contribute

- Report a suspected reference-rule discrepancy.
- Add or review independently derived validation fixtures.
- Improve input validation, documentation, or package infrastructure.
- Propose a reference-rule change.

## Reference rule changes

Reference rule pull requests require more than ordinary code review:

Open a “Reference Documentation” issue identifying the standard, metric,
population, measurement pathway, and exact source location.

## Code contributions

- Follow snake_case naming and two-space indentation.
- Keep public functions focused and type-stable.
- Use namespace-qualified dependency calls in package code.
- Add tests for new behavior and structured error classes.
- Run `devtools::document()`, `devtools::test()`, and
  `devtools::check()` before submitting a pull request.

## Pull requests

Keep changes focused. Describe the motivation clearly, verification
performed, and any backward-compatibility implications. Do not mix a
rule change with an unrelated refactor.
