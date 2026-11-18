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
- Exact approved release source revision, canonical JAR path and SHA-256 from the handoff. Reconcile any disagreement with the approved baseline before starting.
- Approved build command and expected normal artifact pattern
- Accepted validation waivers and owner-managed validation boundaries

## Boundaries

- Do not modify production source, resources, version metadata, dependencies, or public release files.
- Apply the routine mod-repository Git policy in `guidelines/collaboration-guidelines.md`; upload and publication keep their separately required authorization.
- Do not select a development, sources, Javadoc, or otherwise non-release artifact.
- Treat the normal distributable JAR under `<mod-repository>/build/libs/` as the canonical upload source. Retained copies elsewhere are evidence only.
- Do not claim compatibility or publication results that the evidence does not establish.
- Build outputs and local reports may be regenerated and remain uncommitted.

## Procedure

1. Read the release identity from the approved handoff. Record the repository state, canonical JAR path, expected filename, size and SHA-256. Compare HEAD and tracked changes with the release revision. A documented copy-only commit may explain the difference. Resolve any other drift before writing to the active checkout's build directory. Use the exact release revision for the build.
2. Inspect the canonical path before running a build. If the file matches the approved hash, copy it to a new run-specific evidence directory outside all build outputs and verify the copy against that hash. If the file is missing, record that fact and check any retained evidence copy against the handoff. If the canonical file exists with a different hash, preserve it in place, report the discrepancy, and establish its identity before replacing anything.
3. Record the recovery path or the absence of approved bytes in the dated revalidation record before starting the build. On resumption, verify any recorded recovery copy and recheck the canonical path. Keep a verified recovery copy through completion.
4. Make a separate clean checkout or worktree of the approved release revision in the run's staging directory outside the active mod repository. Verify its HEAD and tracked cleanliness. Stage the approved build inputs and use the recorded environment. Resolve the build output directory and check that it is independent of the active checkout's `build/` and the recovery copy. If the build uses a shared absolute output path, isolate that path before running it.
5. Run the approved clean build and its automated checks there. Confirm there is exactly one normal distributable JAR in that checkout's `build/libs/`. Record its filename, size and SHA-256 and compare them with the handoff.
6. If the build fails or the identity differs, retain the build result and any differing candidate as evidence. Recheck the original canonical and recovery files against the preflight record. Report the failure or difference with both identities when available. Leave the approved handoff identity and baseline intact.
7. For a matching candidate, inspect archive integrity, processed metadata, version, loader, class target, bundled libraries and development-only exclusions. Run the runtime checks assigned for this revalidation and carry forward applicable waivers. A failed inspection or runtime check follows the failure path in step 6.
8. On success, recheck the canonical path. Keep a matching file in place. If it is missing, copy the verified candidate to a fresh temporary file in the canonical `build/libs/`, verify the temporary file's SHA-256, and rename it to the expected filename without overwrite. If another writer supplied the destination, verify its identity before continuing. If an unexpected file occupies the destination or another normal distributable JAR is present, report the conflict before calling the directory upload-ready.
9. Read back the canonical SHA-256. Append the result, original and rebuilt identities, canonical path, recovery location, checks and any limitations to the dated handoff record. Only a matching canonical file with passing assigned checks completes revalidation successfully.

## Completion

Revalidation is complete when:

- The exact approved clean source revision was used.
- The clean build and assigned checks passed, or failures are reported plainly.
- A successful revalidation identifies and inspects the matching release artifact. A failed attempt records whether the previously approved bytes are recoverable.
- On success, the validated upload-ready JAR is present under `<mod-repository>/build/libs/`. On failure, the dated finding preserves the approved identity and records the actual canonical-file state.
- The checksum and comparison result are recorded.
- No source or public release material was changed.
- No upload or publication occurred.

An unexplained artifact difference is a finding, not an automatic defect correction. Do not change the project until the owner approves the appropriate workflow route.
