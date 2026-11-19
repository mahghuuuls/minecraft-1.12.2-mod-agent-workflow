# Isolated Cleanroom Validation

Use this procedure for approved packaged Minecraft 1.12.2 checks when Project Setup selects an isolated agent-launched Cleanroom runtime. It is an operational procedure, not a new stage or a replacement for issue acceptance criteria.

## Selection And Authorization

Project Setup owns the runtime choice. Prefer this route when the agent can stage the required cached inputs and the owner permits automatic launches. Reuse a saved applicable preference; ask once for missing launch/control decisions, not once per session. Keep an already approved shared-instance choice until the owner approves a setup amendment. Do not silently replace a pack-specific compatibility check with a minimal profile.

Record in Project Setup:

- The chosen isolated profile, exact Cleanroom/Java/Toolkit pins, support mods and source-cache locations.
- Whether the agent may launch local servers, graphical clients, and perform Toolkit menu/player actions. Apply existing user restrictions, including separate desktop-control consent. An authorized graphical launch may show a window; announce it first.
- The [EULA decision](../guidelines/project-defaults.md#local-test-server-eula), including its source and scope. Carry forward covered saved acceptance.
- Maximum concurrency and resources. Default to one server and one client within a session, 2 GiB each, and finite session/shutdown deadlines. Coordinate other active projects before increasing the machine's total load.
- The reference-pack roots protected from writes, the runtime root, launch route, evidence location, and remaining owner-only observations.

The same tool prepares an isolated standard Forge profile (`"loader": "forge"`, Java 8) from a launcher installation of Forge for 1.12.2 and the vanilla server JAR. Use it for criteria that name standard Forge, such as a packaged check with and without MixinBooter, instead of an owner instance or a project-local script; everything in this procedure applies to it.

An existing owner's launcher is not required for these launches. The current tool imports complete cached runtime files; it does not install Java or download a new runtime. If prerequisites are missing, identify the exact missing input and arrange authorized installation/provisioning or use the approved shared-instance fallback. Do not claim the route works from a version/help command; run a bounded world-level smoke test when establishing it.

## Preparation

1. Read [tool instructions](../tools/cleanroom-runtime/AGENTS.md) and its README. Use a project-owned profile and session plan in the ignored workspace.
2. Select the exact built project JAR and required dependency/configuration inputs. Preserve the canonical release artifact in `build/libs`. Hash the copied JAR and record its source revision. Use [read-only references](../guidelines/project-defaults.md#read-only-modpack-references) only as input sources, including mod JARs, configs and scripts needed for the test.
3. Pin trusted runtime metadata, Java and inputs. Confirm the selected Java satisfies the metadata's requirements. Include every owner reference pack in `protectedRoots`. Never infer that a hash proves authenticity or that an arbitrary JAR is a required dependency. Keep the client's default answer to Forge's startup questions unless a check needs the question to reach its screen; then set `clientQueryResult` in the profile (tool README).
4. Prepare a new named runtime with `tools/cleanroom-runtime/runtime.py prepare`. Inspect its manifest, generated files and copied bundle hashes in a separate read. Run the [mod JAR dependency check](../tools/mod-jar/README.md#check) over each side's mod set, with `-Provided` naming the [loader-provided mod ids](../tools/cleanroom-runtime/README.md#loader-provided-mod-ids) of the pinned Cleanroom. A new profile needs its own preparation; do not update the manifest to legitimize unexplained runtime drift.
5. Map issue criteria to session steps, bundles and distinguishing evidence. Group configuration-compatible checks. Include real process stop/start where persistence requires it. Plan explicit negative controls where useful. Keep the scope and validation tier stated; a successful minimal profile cannot stand in for a selected compatibility profile.
6. Before the campaign, run the smoke launch from [Before The Session](../guidelines/manual-validation.md#before-the-session) as a bounded session on every isolated profile that uses a new scene bundle, and keep its evidence with the campaign's.

## Execution And Evidence

Run the finite session through the setup's proven launch path, using `tools/host-run` when the agent-host process tree prevents Java loopback operation. Keep the outer timeout above the session and shutdown bounds. The tool starts Java directly and retains stdin for server commands, so it does not require the owner to launch CleanroomTestBench or type console commands.

Use the Toolkit for supported deterministic actions. The tool can pair its own isolated client/server using the Toolkit's temporary local proof; this does not authorize exporting another server's credentials. Keep tests on loopback with the generated offline test identity. Authenticated servers and normal player worlds are outside this route.

Read the final result, console captures, Toolkit answers and bundle results. Inspect saved screenshots yourself. Verify gameplay claims against their specific expected state or behavior. A zero exit, a ready marker or a request acknowledgment alone does not establish a mod's criterion. Report expected failures separately from unexpected errors, and preserve failed attempts.

Use [Manual Validation](../guidelines/manual-validation.md) for remaining owner-assisted observations, such as motion, sound, feel or unsupported interaction. Do not add owner launch steps to an already authorized automatic session. When owner cards run inside an isolated session, hold the session with the runtime's `ownerWait` step between cards and release each wait with a fresh marker only when the owner reports the card done; never release a wait on a timer, because a timer cannot tell an owner pause from the end of the work. Do not use desktop-control APIs merely because Toolkit actions are approved.

## Shutdown And Handoff

Require graceful quits/stops for ordinary completion. The supervisor's Windows job contains its own child processes; an unexpected supervisor exit terminates that process tree and leaves partial evidence. It never authorizes ending another project's Java process. A forced stop fails normal completion. An intentional interruption test is labeled separately and must verify recovery afterward.

Read the recorded shutdown outcomes and inspect any missing final result. A stale ownership lock is evidence of an interrupted session, not permission to start another over it. Confirm the recorded runtime processes have ended using identity rather than PID alone, retain the evidence, then remove only that runtime's stale lock if recovery is authorized. Never blanket-delete a shared or reference directory.

Record the runtime profile and evidence in the issue/campaign result. Preserve worlds and logs until evidence retention is settled. The shared CleanroomTestBench reset procedure does not apply to an isolated directory that never borrowed that instance. Report a failed or incomplete automated check as such; do not convert it into a passing check or a waiver.
