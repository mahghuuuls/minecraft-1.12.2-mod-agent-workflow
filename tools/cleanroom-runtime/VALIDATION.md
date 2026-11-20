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

## Standard Forge Profiles (2026-11-19)

Added `"loader": "forge"` profiles and the Java 8 command line. `py -3 -m unittest discover -s ./tools/cleanroom-runtime/tests` passed all 63 tests, also with `-W error::ResourceWarning`; the Cleanroom tests pass with a Java release file added to their fixture.

Actual game session on Windows x64: Minecraft 1.12.2, Forge 14.23.5.2864 from a CurseForge launcher installation (read only), vanilla 1.12.2 server JAR, Temurin Java 8 (1.8.0_462), Agent Test Toolkit 1.9.0; runtime `forge-check-2` (1,351 pinned inputs). The dedicated server logged "Forge Mod Loader version 14.23.5.2864" and "Java is OpenJDK 64-Bit Server VM, version 1.8.0_462", answered `forge tps`; the paired client joined over loopback (`RuntimeTester joined the game`), ran a server bundle through the inbox, and a requested screenshot showed the flat test world (inspected). Both processes stopped with exit zero; the session passed and released its lock; the client's `options.txt` read `tutorialStep:none`. The first attempt (`forge-check-1`) failed at launch because Java 8 cannot read an `@` argument file; that is the reason for the command-line route.

After an independent review the tool also refuses a Java it cannot identify (a Forge profile needs Java 8, a Cleanroom profile a Java its metadata lists in `compatibleJavaMajors`), refuses a library that resolves to no pinned JAR, and skips a natives entry's plain artifact only when the caches do not hold it. With that code:

- Forge 14.23.5.2864 with MixinBooter 12.3 on both sides (runtime `forge-check-mb`): the client joined with `mixinbooter@12.3` in its mod list, the inbox bundle and the screenshot (inspected) passed, both processes exited zero and the lock was released.
- Cleanroom regression (runtime `tool-check-2`, Java 25.0.3 read as 25, `@` argument files kept): dedicated server and client joined with `cleanroom@0.7.14-alpha` and `mixinbooter@12.1`, the inbox bundle and the screenshot (inspected) passed, both processes exited zero.

A last review round tied the Cleanroom Java check to the metadata's `compatibleJavaMajors` and read a JDK 8 `release` file above `jre/` only; these change preparation checks only, and the real Cleanroom (`tool-check-3`, Java 25) and Forge (`forge-check-3`, Java 8) profiles prepared with the final code.

Not covered: Forge single player through the client request channel, and other Forge 1.12.2 builds (an older version file without `downloads` entries is refused by name rather than launched).

## Embedded core and save-name regression

On Cleanroom 0.7.14-alpha with LLibrary 1.7.20 and Toolkit 1.8.0, the existing disposable profile passed inventory verification with the first-launch Maven copy present. The server started and stopped cleanly. The client created a flat save with a 32-character expanded name and exited zero. A second plan with a 33-character name failed before either process started. The runtime tests also cover changed bytes, an unexpected extraction path, a missing embedded pin, and the save-name boundary for both create and open.

## Limits

The tested importer requires complete existing caches and an installed dedicated server. Fresh provisioning, authentication, headless clients, other operating systems and CleanroomGradle development runs are not qualified here. Graphical tests require an interactive Windows session. Game directories are isolated; third-party mod code is not sandboxed. Add project-specific bundles and compatibility profiles before claiming a mod criterion passed.
