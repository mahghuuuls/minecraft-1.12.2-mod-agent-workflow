# Validation Record

Validated on Windows x64 on 2026-11-16 with Minecraft 1.12.2, Cleanroom 0.7.14-alpha, Java 25.0.3, Agent Test Toolkit 1.8.0, Fugue 0.25.5 and Scalar Legacy 1.0.1. This qualifies the runtime facility with that minimal profile, not arbitrary project mods or other Cleanroom releases.

## Automated Checks

`py -3 -m unittest discover -s ./tools/cleanroom-runtime/tests -v` passed all 36 tests. They cover input validation and independent copies, missing/changed caches, reference-directory protection, reparse points and hardlinks, declared extracted dependencies, separate launch permissions, protocol identity/freshness, occupied ports, exclusive ownership, deadlines, early process death, graceful/forced shutdown, restarts, Windows file-sharing retries and job containment. The abrupt-supervisor test also verifies that an unrelated sibling process survives.

These checks use synthetic caches and small real Python child processes. They do not prove game behavior.

## Actual Game Session

The versioned `examples/smoke-session.json` and `examples/smoke-bundles.json` passed all 38 steps in a newly prepared isolated runtime. Nine Java processes started: six dedicated servers and three clients. Eight shut down normally with exit zero; the ninth was the explicitly requested server interruption. A subsequent server restart verified the saved block.

- Dedicated server startup, console commands and world changes.
- A saved block surviving actual server process restarts.
- Toolkit-driven single-player creation, game quit and reopening in a new client process.
- A separate client joining the loopback server and executing a paired Toolkit request.
- Deliberately false block assertions recognized as expected failures in single player and multiplayer.
- Three screenshots visually inspected: the expected gold block in both worlds and the creative inventory opened by a client action.
- Controlled server interruption followed by restart and persistence verification.
- Final process inspection found no owned game processes; ownership lock and temporary pairing proofs were removed.

The session completed in about 198 seconds through `host-run`. Console error scanning found only the two intentional negative assertions. Both copied mod sets passed the mod-JAR dependency check with the loader-provided IDs supplied. The process-document validator and Git whitespace checks passed.

Earlier retained attempts exposed legitimate Scalar Legacy dependency extraction and temporary Windows sharing locks on evidence and Toolkit answers. The tool now validates declared extracted JAR hashes and retries those transient file accesses; regression tests cover each correction.

## Profile JVM Properties, Tutorial Setting And Owner Wait (2026-11-19)

Added `jvmArgs`, `client.dismissTutorial` in the generated Toolkit settings, and the `ownerWait` step. `py -3 -m unittest discover -s ./tools/cleanroom-runtime/tests` passed all 47 tests (twice in a row), including new checks of the `jvmArgs` limits and refused namespaces, the generated setting, an `ownerWait` released only by a fresh Toolkit mark with its exact label (not by a chat-like line or a longer label), one not released by a mark written before it, one refused on a stopped process, the refused `timeout` field, and the launch arguments kept in the evidence.

Actual game session on Windows x64, Minecraft 1.12.2, Cleanroom 0.7.14-alpha, Java 25.0.3, Agent Test Toolkit 1.9.0, Fugue 0.25.5 and Scalar Legacy 1.0.1, profile with `jvmArgs: ["-Dmixin.debug.export=true"]`: a dedicated server and a client joined over loopback, then an `ownerWait` on the server held the session for 2 minutes 41 seconds, with no release after 150 seconds of waiting, and ended 1 second after the agent sent a bundle that ran `devtool mark` through the server inbox. Both processes stopped with exit zero; the session passed and released its lock. The client's `options.txt` read `tutorialStep:none` after the launch. The same JVM option lines read from each side's generated argument file gave `mixin.debug.export = true` in `java -XshowSettings:properties`; the game itself wrote no `.mixin.out` export on Cleanroom 0.7.14-alpha, so the tool's claim stops at delivering the property. After an independent review, the release rule was narrowed to Toolkit `[MARK]` lines with the exact label and `jvmArgs` gained refused namespaces; a second session on the same runtime held the `ownerWait` for 36 seconds, with no release after 30 seconds, and ended 1 second after the agent's mark (`[DevToolkit][MARK] side=SERVER ... label=OWNER_GO_TOOLCHECK`); it passed, both processes exited zero, the lock was released, and the evidence folder held `profile.json`, `client.args` and `server.args`. The client-side `ownerWait` is not yet validated in a game.

## Limits

The tested importer requires complete existing caches and an installed dedicated server. Fresh provisioning, authentication, headless clients, other operating systems and CleanroomGradle development runs are not qualified here. Graphical tests require an interactive Windows session. Game directories are isolated; third-party mod code is not sandboxed. Add project-specific bundles and compatibility profiles before claiming a mod criterion passed.
