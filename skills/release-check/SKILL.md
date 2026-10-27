---
name: release-check
description: Build the release jar from the committed revision, inspect it, and see it pass discovery once in the test instance, in the order this workflow specifies. Use after the release-preparation commit of Release Presentation, or when an agent is about to build or hand off a release artifact.
license: MIT
---

# Release Check

The release commit is in. Before the owner uploads anything, the jar must be built from that exact revision, read from the inside, and seen once in the launcher players use. Each of those has failed in practice for a mechanical reason: a daemon holding the build folder, a stale jar beside the new one, an inspection inferred from the build script, an instance left with the jar in it.

## Read first, every time

`procedures/release-build-and-discovery.md` in the workflow repository. It is the procedure; this skill only makes sure it runs at the moment the stage reaches it. Find the workflow root by walking up from the working directory to the folder holding `guidelines/` and `workspace/`. Read the procedure as it is on disk now, not from memory.

## Then do it

Follow its steps in order, and say which step you are on. Read every inspected value from the jar itself. Give the owner one launch card and read the instance log yourself. Reset the instance before you write the handoff.

## Boundaries

- This skill adds nothing to the procedure and changes nothing in `stages/8-release-presentation.md`. Where they disagree, the stage document is correct.
- It cannot approve the release, upload it, or publish it. The handoff goes to the owner, who does those.
- To rebuild an already approved release, the procedure is `procedures/revalidate-release.md`, not this one.
