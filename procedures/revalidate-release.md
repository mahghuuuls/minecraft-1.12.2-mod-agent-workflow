# Revalidate Release

## Purpose

Rebuild and re-inspect an already approved release handoff without reopening Release Presentation merely because fresh artifact evidence is needed.

This is a callable procedure, not a reusable stage. It does not create a new workflow checkpoint, change public materials, approve a new version, or publish anything.

## When To Use

Use this procedure only when the owner or an active workflow requests fresh validation for an existing approved release source revision, for example after:

- Moving the project to another machine or build environment
- Regenerating a missing release artifact
- Verifying that an approved source revision still builds reproducibly
- Rechecking artifact metadata or contents before manual publication

If source code, resources, version metadata, dependencies, configuration defaults, or public release files must change, use Release Presentation within the active workflow or begin a Change Cycle. Do not use revalidation to conceal a source change.

## Required Inputs

- Approved `release-handoff.md`
- Approved `project-baseline.md` when one exists
- Active mod repository
- Exact approved source revision
- Approved build command and expected normal artifact pattern
- Accepted validation waivers and owner-managed validation boundaries

## Boundaries

- Do not modify production source, resources, version metadata, dependencies, or public release files.
- Do not commit, push, upload, or publish without the separately required authorization.
- Do not select a development, sources, Javadoc, or otherwise non-release artifact.
- Do not claim compatibility or publication results that the evidence does not establish.
- Build outputs and local reports may be regenerated and remain uncommitted.

## Procedure

1. Inspect the active mod repository, current branch, HEAD revision, and working tree.
2. Compare HEAD with the approved handoff and baseline revision.
3. If the revisions differ or tracked changes are present, stop and classify the drift before building. Revalidation requires the exact approved clean revision.
4. Confirm the approved build environment, build command, expected artifact pattern, and normal release artifact.
5. Stop stale development processes when they would lock or contaminate build outputs.
6. Run the clean approved build and all automated checks included by that command.
7. Select the normal release artifact and record its path, filename, size, and SHA-256 checksum.
8. Inspect archive integrity, processed mod metadata, version, Minecraft/loader compatibility fields, author/source fields, Java class target, bundled libraries, and prohibited development-only contents as relevant.
9. Run only the runtime, compatibility, or multiplayer checks explicitly assigned for this revalidation. Carry forward accepted waivers without repeatedly asking for waived owner-managed checks unless new evidence makes one release-blocking.
10. Compare the new artifact identity and inspection results with the approved handoff.
11. Update `release-handoff.md` with a dated revalidation record containing the source revision, command, environment, result, artifact identity, checksum, differences, and remaining waivers.
12. Report whether the release is reproduced, differs without an explained source change, or is blocked by a failed check.

## Completion

Revalidation is complete when:

- The exact approved clean source revision was used.
- The clean build and assigned checks passed, or failures are reported plainly.
- The normal release artifact was identified and inspected.
- The checksum and comparison result are recorded.
- No source or public release material was changed.
- No upload or publication occurred.

An unexplained artifact difference is a finding, not an automatic defect correction. Do not change the project until the owner approves the appropriate workflow route.
