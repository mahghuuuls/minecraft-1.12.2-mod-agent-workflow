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

## Limits

The tested importer requires complete existing caches and an installed dedicated server. Fresh provisioning, authentication, headless clients, other operating systems and CleanroomGradle development runs are not qualified here. Graphical tests require an interactive Windows session. Game directories are isolated; third-party mod code is not sandboxed. Add project-specific bundles and compatibility profiles before claiming a mod criterion passed.
