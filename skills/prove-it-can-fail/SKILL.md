---
name: prove-it-can-fail
description: Demonstrate that a new test or check actually fails when the behavior it claims to cover is absent, by temporarily reverting the fix or mutating the guarded code and running the suite. A test that passes either way is reported as a finding, not counted as coverage.
license: MIT
---

# Prove It Can Fail

The user invoked this skill after new tests or checks were written. Your job is to show, by running them against broken code, that they can detect the thing they claim to detect.

The failure this remedies: verification that agrees with itself. A test written by the author of the fix encodes the author's assumptions; when one of those assumptions is wrong, the test passes with the fix present and passes with it absent, and its green result means nothing. In this workflow's history a sensitivity check like this was run twice in one day and caught a worthless test both times - one whose fixture was incomplete in a way that made the code under test run for an unrelated reason, so the assertion could never miss.

`guidelines/coding-standards.md` already states the principle: a test must be able to fail, and before claiming coverage you must name the change that would make it fail. This skill is the mechanical version of that sentence.

## Procedure

1. **Confirm a clean starting point.** Full suite green, working tree clean. Record the test count.
2. **Name the pairs.** For each new test, state the specific implementation change that should make it fail. If no such change can be named, that is already the finding; stop and rewrite the test.
3. **Break the code, temporarily.** Revert the fix, or apply the named mutation. Keep the change trivially reversible: take a copy of the file first, and never commit in this state.
4. **Run and compare against the prediction.** Predict which tests fail before running. The interesting outcomes:
   - Predicted test fails: it earns its place.
   - Predicted test **passes**: it cannot detect the absence of the behavior. Finding. Either the fixture does not reach the rule under test, or the assertion checks something the mutation does not touch. Fix the test, not the prediction.
   - Unpredicted tests fail: note them; they overlap the same behavior, which is worth knowing but is not a defect.
5. **Restore and re-verify.** Put the code back, confirm the tree is clean against git, run the full suite green again. The sweep is not finished until this step; a mutation left behind is worse than no sweep.
6. **Record the result** in the owning issue: each pair, the prediction, the outcome. A test that survived mutation and was then fixed gets its before-and-after stated.

## Honest classifications

Not every passing-either-way test is worthless. Some are **guards**: they protect a behavior the current change did not create, and they pass with the change reverted because the behavior exists trivially without it. That is legitimate - but it must be labeled a guard in the test's own documentation, not counted as proof the change works. This distinction was learned here the expensive way: a test presented as demonstrating a fix turned out to be a guard, and the record had to be corrected.

## Boundaries

- Applies to automated tests and to scripted checks alike. A manual check gets the same standard from `guidelines/manual-validation.md`: define what would look different if the feature were absent.
- Never leave the mutated state in the tree, in a stash someone might pop, or in a commit. Verify restoration mechanically, not by recollection.
