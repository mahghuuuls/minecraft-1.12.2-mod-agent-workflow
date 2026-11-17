# Release Build And Discovery

## Purpose

Build the release artifact from the approved committed revision, inspect it, and see it pass discovery once in the agent-managed test instance, in an order that avoids the failures seen in practice: a build directory the Gradle daemon still holds, a stale jar from an older version, a borrowed instance left changed.

This is a callable procedure, not a reusable stage. `stages/8-release-presentation.md` owns what the artifact must satisfy (its inspection list, the manifest rule, the logo rule, the toolkit absence rule, the dependency relation policy) and what the handoff records. `procedures/revalidate-release.md` owns rebuilding an already approved release later. This file owns the order of the first release build and how to obtain or reuse its discovery evidence.

## When To Use

Use this procedure at step 21 of `stages/8-release-presentation.md`, after the release-preparation commit, when release validation is agent-managed. Do not use it to rebuild an approved release; that is `procedures/revalidate-release.md`.

## Required Inputs

- The committed, clean release revision and its id
- The approved build command and the launch path recorded in Project Setup (see Running Builds And Tests in `guidelines/coding-standards.md`)
- The expected artifact file name and version
- The selected runtime record from Project Setup, including its isolated profile or shared instance baseline, required test inputs, and reported `mixinbooter` version
- The approved launch and control ownership for that runtime

## Boundaries

- Build only from the committed revision. A working-tree change after the commit means a new commit and a new build.
- Do not modify source, resources, version metadata, or public files here.
- Do not upload or publish; the owner does that from the handoff.
- Follow the selected runtime's ownership and cleanup procedure. Isolated profiles use [Isolated Cleanroom Validation](isolated-cleanroom-validation.md). Shared instances use the borrowing and reset rules in `guidelines/project-defaults.md`.

## Discovery Evidence From Packaged Gameplay

When the expected release identity and in-mod logo or approved deferral are known, use the last planned packaged gameplay launch in the agent-managed test instance to capture discovery evidence when practical. Use that same launch for the Mods list card and gameplay. Record:

- The SHA-256 of the staged JAR that actually ran and the launch log that ties the JAR to the discovered mod ID and version.
- The launch profile and instance baseline, the actual loader and applicable MixinBooter versions, and any staged dependencies or discovery-relevant configuration. Preserve the relevant discovery lines and any errors or warnings naming the mod.
- The owner's observation of the displayed name and version, and whether the expected logo shows or the approved no-logo state is displayed.
- The verified isolated shutdown and ownership-lock release, or the shared-instance reset, for that session.

After the final clean release build and inspections, reuse this evidence only if the canonical upload JAR's SHA-256 matches the staged JAR, the discovery runtime and relevant launch conditions match the release test target, and the retained evidence establishes each required result for the approved release identity. The gameplay result and entry-by-entry comparison in step 6 serve other validation claims. Discovery and Mods list reuse require the whole-file hash match and the observations above. Use a fresh release discovery launch when any required result or match is missing.

## Procedure

1. Confirm the mod repository is clean and HEAD is the release revision named in the release-preparation commit. Record the id.
2. Make sure nothing holds this repository's `build/` folder: no development client or server of this project runs. Do not run `gradlew.bat --stop`; on a shared machine it ends other projects' builds, servers, and clients (Shared Machine in `guidelines/project-defaults.md`). When `clean` fails with "Unable to delete directory", follow Running Builds And Tests in `guidelines/coding-standards.md`.
3. Run the approved clean build with `--no-daemon` through `tools/host-run/host-run.cmd run`, with a timeout that covers a full recompile, and read its exit code and the test totals from the captured output.
4. Confirm exactly one normal distributable jar is under `<mod-repository>/build/libs/` with the expected name and version, and no normal distributable jar from an older version. Record the path, size, and SHA-256.
5. Inspect the jar as required by [Release Presentation](../stages/8-release-presentation.md#in-scope), including the manifest and every attribute it names, the processed mod metadata, the logo file when the metadata names one, the class target, the absence of toolkit and development-only classes, and the dependency relations. List the archive entries and read each inspected file directly.
6. Copy the jar to `workspace/validation/release/` as evidence. The copy under `build/libs/` stays the canonical upload source. When a packaged campaign ran an earlier build of the same version, compare the two jars entry by entry and record every entry that differs. On Windows with `core.autocrlf`, switching branches for the merge rewrites text resources (models, blockstates, language files) with other line endings, so the bytes differ although the content does not; compare such entries with line endings normalized, and treat any other difference as a change the campaign did not test.
7. Check [Discovery Evidence From Packaged Gameplay](#discovery-evidence-from-packaged-gameplay). If the retained evidence qualifies, go to step 11. Otherwise prepare the runtime selected in Project Setup. For an isolated profile, follow [Isolated Cleanroom Validation](isolated-cleanroom-validation.md). For a shared instance, follow [Shared Test Instance Preparation](../guidelines/project-defaults.md#shared-test-instance-preparation) with `tools/instance-reset` (`snapshot`, then `lock`). Stage the exact release JAR and approved required test inputs. Confirm the staged paths and SHA-256.
8. Launch using the recorded ownership and authorization. Announce an authorized agent launch before opening the graphical client. Give the owner a card for any remaining actions or observations, using `guidelines/manual-validation.md`. Confirm the Mods list name, version, and expected logo or approved no-logo state with the owner. Use supported Toolkit actions for shutdown when authorized. Desktop input requires its own applicable permission.
9. Read the instance log after the launch: the discovery line that names the mod id and version, the loader and `mixinbooter` versions, and any error or warning that names the mod. Stage the log into the release staging folder at once, with absolute paths.
10. For an isolated runtime, verify graceful shutdown and ownership-lock release, preserving its logs and evidence under the isolated procedure. For a borrowed instance, perform and verify the reset under [Test Instance](../guidelines/project-defaults.md#test-instance) and [Shared Machine](../guidelines/project-defaults.md#shared-machine), with `tools/instance-reset` (`plan`, then `apply`). Retain the applicable shutdown or reset record in the release evidence.
11. Record in `release-handoff.md` the revision, the command, the artifact path, size, and SHA-256, every inspection result, the discovery and Mods list results, and the verified shutdown or reset. Identify the launch and link the retained log and owner observation. For reused evidence, record the matching hash and runtime basis. The handoff and the project baseline remain the authority for the artifact checksum.

## Completion

The build and discovery are complete when:

- The jar was built from the clean release revision and is the only normal distributable jar under `build/libs/`.
- Every inspection the stage requires has a recorded result read from the jar itself.
- The instance log confirms the expected mod ID and version, and the owner confirms the displayed name, version, and expected logo or approved no-logo state.
- The isolated runtime stopped cleanly and released its ownership lock, or the shared instance matches its reset baseline and holds no lock note from this project.
- The handoff records all of the above and nothing was uploaded.
