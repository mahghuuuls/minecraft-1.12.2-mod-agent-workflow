# Release Build And Discovery

## Purpose

Build the release artifact from the approved committed revision, inspect it, and see it pass discovery once in the agent-managed test instance, in an order that avoids the failures seen in practice: a build directory the Gradle daemon still holds, a stale jar from an older version, a borrowed instance left changed.

This is a callable procedure, not a reusable stage. `stages/8-release-presentation.md` owns what the artifact must satisfy (its inspection list, the manifest rule, the logo rule, the toolkit absence rule, the dependency relation policy) and what the handoff records. `procedures/revalidate-release.md` owns rebuilding an already approved release later. This file owns the order of the first release build and its discovery launch.

## When To Use

Use this procedure at step 21 of `stages/8-release-presentation.md`, after the release-preparation commit, when release validation is agent-managed. Do not use it to rebuild an approved release; that is `procedures/revalidate-release.md`.

## Required Inputs

- The committed, clean release revision and its id
- The approved build command and the launch path recorded in Project Setup (see Running Builds And Tests in `guidelines/coding-standards.md`)
- The expected artifact file name and version
- The test instance record from Project Setup: launcher, instance path, template mod list, and the `mixinbooter` version it reports
- The owner's launch form for the instance, as recorded in Project Setup

## Boundaries

- Build only from the committed revision. A working-tree change after the commit means a new commit and a new build.
- Do not modify source, resources, version metadata, or public files here.
- Do not upload or publish; the owner does that from the handoff.
- Treat the test instance as borrowed: the lock-note and reset rules of Shared Machine and Test Instance in `guidelines/project-defaults.md` apply in full.

## Procedure

1. Confirm the mod repository is clean and HEAD is the release revision named in the release-preparation commit. Record the id.
2. Make sure nothing holds this repository's `build/` folder: no development client or server of this project runs. Do not run `gradlew.bat --stop`; on a shared machine it ends other projects' builds, servers, and clients (Shared Machine in `guidelines/project-defaults.md`). When `clean` fails with "Unable to delete directory", follow Running Builds And Tests in `guidelines/coding-standards.md`.
3. Run the approved clean build with `--no-daemon` through `tools/host-run/host-run.cmd run`, with a timeout that covers a full recompile, and read its exit code and the test totals from the captured output.
4. Confirm exactly one normal distributable jar is under `<mod-repository>/build/libs/` with the expected name and version, and no normal distributable jar from an older version. Record the path, size, and SHA-256.
5. Inspect the jar as the Responsibilities list of `stages/8-release-presentation.md` requires: the manifest and every attribute it names, the processed mod metadata, the logo file the metadata names, the class target, the absence of toolkit and development-only classes, and the dependency relations. List the archive entries and read each inspected file; do not infer from the build script.
6. Copy the jar to `workspace/validation/release/` as evidence. The copy under `build/libs/` stays the canonical upload source. When a packaged campaign ran an earlier build of the same version, compare the two jars entry by entry and record every entry that differs. On Windows with `core.autocrlf`, switching branches for the merge rewrites text resources (models, blockstates, language files) with other line endings, so the bytes differ although the content does not; compare such entries with line endings normalized, and treat any other difference as a change the campaign did not test.
7. Follow [Shared Test Instance Preparation](../guidelines/project-defaults.md#shared-test-instance-preparation) to borrow the test instance, with `tools/instance-reset` (`snapshot`, then `lock`). Stage the exact release JAR and any approved required dependencies the instance lacks. Confirm the staged paths in a fresh listing.
8. Give the owner one card in the form of `guidelines/manual-validation.md`: launch the instance from the launcher, open the mod list, find the mod, and report whether the name, version, and logo show. Say to close the game after.
9. Read the instance log after the launch: the discovery line that names the mod id and version, the loader and `mixinbooter` versions, and any error or warning that names the mod. Stage the log into the release staging folder at once, with absolute paths.
10. Reset the instance under [Test Instance](../guidelines/project-defaults.md#test-instance) and [Shared Machine](../guidelines/project-defaults.md#shared-machine), with `tools/instance-reset` (`plan`, then `apply`). Write the verified reset check into the release staging folder.
11. Record in `release-handoff.md`: the revision, the command, the artifact path, size, and SHA-256, every inspection result, the discovery launch result with the instance's reported versions, and the reset. The handoff and the project baseline remain the authority for the artifact checksum.

## Completion

The build and discovery are complete when:

- The jar was built from the clean release revision and is the only normal distributable jar under `build/libs/`.
- Every inspection the stage requires has a recorded result read from the jar itself.
- The instance log shows the mod discovered with the expected id and version, and the owner reported the mod list.
- The instance matches its baseline and holds no lock note from this project.
- The handoff records all of the above and nothing was uploaded.
