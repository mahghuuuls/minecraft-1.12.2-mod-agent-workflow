# Isolated Cleanroom Runtime

Prepare cached, hash-pinned Minecraft 1.12.2 Cleanroom or standard Forge files into independent client/server directories, then run a finite JSON test session directly through Java. No modpack launcher is needed for these launches. [The workflow procedure](../../procedures/isolated-cleanroom-validation.md) owns when to select this route and the permission record.

## Requirements And Limits

- Windows x64, CPython 3.11 or later, and a suitable installed Java runtime. Tested with Cleanroom 0.7.14-alpha and Java 25.0.3, and with standard Forge 14.23.5.2864 and Java 8 (1.8.0_462). The tool reads the Java version from the installation's `release` file (the JDK root, or above `jre/` in a JDK 8) and refuses a Java it cannot identify; a Forge profile needs Java 8, and a Cleanroom profile a Java its pinned metadata lists in `compatibleJavaMajors` (25 for Cleanroom 0.7.14-alpha), and at least Java 9. Java 8 cannot read an `@` argument file, so for it the tool passes the same verified arguments on the command line, refusing one longer than the Windows limit.
- For standard Forge (`"loader": "forge"`): a launcher installation of Forge for 1.12.2 (its `versions/forge-<version>/forge-<version>.json`, the vanilla `versions/1.12.2/1.12.2.json`, the matching `libraries` tree and the client JAR) and the vanilla 1.12.2 server JAR. Both JARs are checked against the vanilla version file's SHA-1.
- For Cleanroom profiles: a complete cached Cleanroom 0.7.x installation: the three MultiMC-format metadata files, matching libraries, Minecraft client, Minecraft 1.12 assets, and an installed dedicated server with its five-line `win_args.txt`.
- Pinned Agent Test Toolkit 1.8.0 or later on each side that uses its control channel. Include runtime support mods required by the selected profile, such as Fugue and Scalar Legacy, and the project JAR being tested.
- Explicit authorization recorded for the selected local tests and applicable owner EULA acceptance. Graphical launches are separately represented by `clientLaunch`.

This version imports existing files. It does not install Java, download Minecraft, authenticate accounts, migrate Gradle templates or launch an owner's pack. Missing or changed inputs produce errors before destination creation. It uses a local offline identity on a server bound to `127.0.0.1`; it is not an online multiplayer launcher. The client needs a logged-in graphical Windows session. A selected mod may perform its own downloads or write user-level caches; this tool is an isolation convention for game directories, not a sandbox for untrusted mod code.

## Prepare A Profile

Start with [profile.example.json](examples/profile.example.json), or [profile.forge.example.json](examples/profile.forge.example.json) for standard Forge. Replace its paths and hashes with verified local inputs. Keep the completed profile under the project's ignored workspace. The example deliberately does not grant consent.

| Field | Meaning |
| --- | --- |
| `schema`, `minecraft` | Schema 1, fixed Minecraft 1.12.2 |
| `loader` | Optional `cleanroom` (default) or `forge` for standard Forge |
| `cleanroom` | Cleanroom profiles: exact selected Cleanroom version |
| `forge` | Forge profiles: exact Forge version for 1.12.2, such as `14.23.5.2864`; the Forge version file must name that Forge library |
| `java` | Absolute `java.exe` path and SHA-256 |
| `authorization` | Current approval source, `eulaAccepted`/`eulaSource`, `toolkitActions`, `serverLaunch` and `clientLaunch` decisions |
| `metadata` | Absolute path and SHA-256 for each selected cached metadata file: Cleanroom's `net.minecraft.json`, `net.minecraftforge.json` and `org.lwjgl3.json`; for Forge, `net.minecraft.json` is the vanilla launcher's `1.12.2.json` and `net.minecraftforge.json` the Forge version file |
| `libraryRoots` | Maven-layout cache roots to search; only exact artifact hashes from the pinned metadata match |
| `clientJar` | Minecraft 1.12.2 client path and SHA-256; also checked against the metadata's SHA-1 |
| `serverInstall`, `serverArgsSha256` | Cleanroom profiles: existing installed server root and the hash of its Cleanroom `win_args.txt` |
| `serverJar` | Forge profiles: the vanilla 1.12.2 server JAR path and SHA-256. The Forge server runs from Forge's library list plus this JAR, which carries its own libraries |
| `assets` | Existing assets root containing `indexes/1.12.json` and `objects/` |
| `mods` | Exact JAR path, SHA-256 and `sides` (`client`, `server`, or both) |
| `files` | Exact configuration, script or bundle inputs: source `path`, SHA-256 and relative `target` |
| `protectedRoots` | Owner reference packs and other directories that must never overlap the runtime |
| `player`, `heapMiB` | Optional local test name and heap limit; defaults `RuntimeTester`, 2048 MiB per process |
| `clientQueryResult` | Optional answer to Forge's startup questions on the client: `cancel` (default), `confirm`, or `none` for no answer, so Forge shows its question screen. The server always cancels |
| `jvmArgs` | Optional list of up to 16 Java system properties for both sides, each `-Dname=value` without spaces or quotes, for a diagnostic switch that a loader or mod reads. The tool only passes the property; whether the game acts on it is for the check to show (on Cleanroom 0.7.14-alpha, `-Dmixin.debug.export=true` reached the JVM but wrote no `.mixin.out` export). Other JVM options are refused, and so are the properties the tool sets itself (`file.encoding`, `java.library.path`, `fml.queryResult`), `fml.coreMods.load`, and every name in a namespace that could move files, load unpinned native code, open a listener, change the console encoding or route network traffic (`java.`, `javax.`, `jdk.`, `sun.`, `com.sun.`, `user.`, `file.`, `native.`, `os.`, `stdout.`, `stderr.`, `org.lwjgl.`, `jna.`, `jnidispatch.`, `net.java.games.`, `log4j`, `minecraft.`, `http.`, `https.`, `ftp.`, `socksProxy`, `socksNonProxy`, `networkaddress.`) |

The importer resolves every input before creating `<workspace>/runtime/<name>`. The workspace must already exist. It copies rather than links inputs, preserves Maven layout, records hashes and writes safe local test defaults. Existing runtime names are refused. A copy failure leaves a `preparing.json` marker and cannot be launched; retain it for diagnosis and use a new name after correcting the input.

The generated defaults are a disposable flat dedicated-server world, creative mode, two-player limit, loopback binding, RCON/query disabled, FML missing-registry questions cancelled, and separate log/config/world directories. The server always launches with `-Dfml.queryResult=cancel`. The client does too by default, so a missing-blocks or missing-registry question is answered before any screen shows; a test of that screen or of a Toolkit `open ... onQuestion=` step needs `clientQueryResult` set to `none` in a new profile. Client defaults are windowed 960 by 540, 60 FPS, six-chunk render distance, muted sound and no focus-loss pause. Test audio and subjective behavior separately when needed. The tool owns `devtool.cfg`: it turns on the client actions, the request channel and the inbox, and `client.dismissTutorial` so the tutorial hints never cover a test or a screenshot (read by Toolkit 1.9.0 and later; with an older Toolkit the hints can still show). Other inputs may target `client/config/`, `server/config/`, or their `scripts/` folders. It rejects imported channel files and local-join proofs. Mod/config selection is not inferred from filenames or copied wholesale from a reference pack.

From the workflow repository root, using absolute paths for these placeholders:

```powershell
py -3 ./tools/cleanroom-runtime/runtime.py prepare --profile C:/work/example/workspace/runtime-profile.json --workspace C:/work/example/workspace --name campaign-a
```

The manifest pins input files and allows only declared `ContainedDeps` extracted from selected mod JARs into `mods/1.12.2`, with their embedded hashes. Cleanroom may also write the declared LLibrary core 1.0.11-1.12.2 at its exact Maven path under `mods/memory_repo`. The same embedded hash is required there. Extra or changed JARs fail before another launch. Prepare a new profile for intentional changes. `config` and `scripts` are copied into each launch's evidence; the game may legitimately rewrite them.

### Loader-Provided Mod Ids

Cleanroom supplies some mod ids itself, with no JAR in `mods`. Pass them with `-Provided` when you run the [mod JAR dependency check](../mod-jar/README.md#check) over each side's `mods` folder. Cleanroom 0.7.14-alpha provides `cleanroom`, `mixinbooter` and `fermiumbooter`:

```powershell
./tools/mod-jar/mod-jar.cmd check -Folder C:/work/example/workspace/runtime/campaign-a/client/mods -Provided cleanroom,mixinbooter,fermiumbooter
```

A list that leaves one out lets a separate JAR of that mod pass the check, and the game then stops at launch on the duplicate. Standard Forge provides only `minecraft`, `mcp`, `FML` and `forge`; MixinBooter is a separate JAR there. For another Cleanroom version, read the list again from a log of that runtime that entered a world: the ids in `Client attempting to join with <n> mods : ...` that no JAR in its `mods` folder supplies.

## Run A Session

A session file is schema 1 with `steps`, `timeoutSeconds` (default 600, maximum 7200), `stopSeconds` (default 30, maximum 60), and optional `port` (zero chooses an available loopback port). One session owns at most one server and one client. `allowInterruptionTest` must be explicitly true for a deliberate process interruption.

```powershell
py -3 ./tools/cleanroom-runtime/runtime.py run --root C:/work/example/workspace/runtime/campaign-a --plan C:/work/example/workspace/session.json
```

When the recorded Java launch path needs `host-run`, use its finite-command wrapper. Choose its timeout above the session deadline plus four times `stopSeconds` and another 20 seconds for both cleanup paths. Quote paths with spaces according to [Host Run](../host-run/README.md#quoting).

```powershell
./tools/host-run/host-run.cmd run -WorkingDirectory tools/cleanroom-runtime -Command "py -3 runtime.py run --root C:/work/example/workspace/runtime/campaign-a --plan C:/work/example/workspace/session.json" -TimeoutSeconds 1200 -Label cleanroom-tests -TailLines 20
```

| Action | Fields and success condition |
| --- | --- |
| `start` | `side`; waits for a live server's Done marker or this client's fresh Toolkit channel timestamp |
| `stop` | `side`; sends server `stop` or the appropriate Toolkit client quit and requires exit zero |
| `console` | Server `side`, one-line `text`, `contains`; requires that marker in output produced after the command |
| `bundle` | Server `side`, `name`; waits for a new matching console bundle result and zero failed commands |
| `request` | `side`, `text`, optional `channel` (`inbox` or `client-inbox`); checks request identity and `outcome` |
| `screenshot` | Inbox sender `side`; waits for a unique image and its client's saved record; inspect the image afterward |
| `pair` | After server readiness, before client start; copies the ephemeral Toolkit local proof only between these two disposable directories |
| `waitLog` | `side`, `contains`; waits for a marker in this process's console log |
| `ownerWait` | `side`, `contains` (a Toolkit mark label: 4 to 128 letters, digits, `_`, `.` or `-`); holds the session while the owner works, until this process's console log shows a Toolkit `[MARK]` line with exactly that label, written after the step began. Ordinary log or chat lines that contain the word do not count. It takes no `timeout`: only the mark, the session deadline or an exited process ends it, so an owner pause never runs the teardown early. The agent releases it when the owner reports the card done, with a bundle that runs `devtool mark <label>`, sent through the server inbox (`tools/devtool-inbox` `send`); that request and its answer appear in the launch's `after` snapshot of `config/`, not in `events.json`. Validated on the dedicated server side; the client side applies where the marks reach the client's console (single player) and is not yet validated in a game |
| `expectExit` | `side`, optional `code` (default zero); waits for the exact child to exit |
| `interrupt` | `side`; deliberately terminates this session's child when interruption testing is enabled; follow with `stop` to archive it |

Each step except `ownerWait` accepts `timeout` (default 120 seconds, maximum 600), bounded by the session deadline. Request `expect` defaults to `done`; `failed` or `refused` also requires the specific `reason`. Request and console text support `{player}`, `{port}` and `{run}` substitutions. `{run}` is unique and expands to 24 characters. Before launch, the runner checks that successful client-inbox `create` and `open` requests fit the Toolkit limit of 32 characters after substitution. A dynamic port reserves five digits. Requests explicitly testing a refusal still go to the Toolkit.

The paired server has an explicit operator entry for the generated offline test identity, scoped to this isolated server. `pair` is required because these two game folders are separate; the client otherwise cannot prove a local join. No proof content is logged or included in snapshots, and proofs are removed on cleanup. Never copy a real server's credentials or use this route to access another server.

[smoke-session.json](examples/smoke-session.json) uses [smoke-bundles.json](examples/smoke-bundles.json), which must be included in both profile sides. It tests a placed block across actual process restarts, single player, local multiplayer, expected failure, screenshots, an inventory action and controlled server interruption. It is a test of the runtime facility, not proof that a project mod works. Replace or extend its steps and bundles with criterion-specific project checks.

## Ownership And Evidence

`active.lock` is acquired exclusively. A second run cannot take it, and stale locks are not stolen. Windows job ownership is assigned before each child resumes; closing or losing the supervisor's job handle terminates those children and their descendants. It does not search for or terminate other Java processes. Normal cleanup tries graceful stop; a forced cleanup makes the session fail even if all earlier assertions passed. A killed supervisor leaves a lock and possibly partial evidence, requiring inspection before reuse.

Each `evidence/<timestamp>-<unique-id>/` contains the session plan, runtime manifest, the prepared profile and both launch argument files (so the active `jvmArgs` are on record), tool source snapshot, events, per-launch console logs, before/after configuration and diagnostic snapshots, Toolkit results and screenshots. Older channel files are moved into that launch's evidence before a new process starts, so they cannot supply readiness or answers. Saves remain in the isolated runtime. The tool does not delete worlds, old runs or caches automatically.

Exit zero means preparation succeeded or every session step and shutdown succeeded. Exit one means failure. A session normally records `result.json`, including cleanup failures; abrupt supervisor death may leave no final result and must not be called a pass. Read the errors and relevant logs. The tool does not mechanically classify every warning printed by mods.

## Tests

See the [validation record](VALIDATION.md) for the tested runtime profile, actual game results and limits.

```powershell
py -3 -m unittest discover -s ./tools/cleanroom-runtime/tests -v
```

These tests use disposable source/cache fixtures and real small Python child processes. They check copying and hash boundaries, standard Forge profiles (launch entry points, the native placeholder skip, server and client JAR identity, refused Cleanroom fields, a library that resolves to no pinned JAR), the Java version checks, and the Java 8 command line with its length limit, the client and server `fml.queryResult` arguments, `jvmArgs` limits, the generated Toolkit settings, `ownerWait` release only on a fresh marker, references and reparse points, declared embedded dependencies, protocol freshness and identity, ports, ownership, deadlines, early exits, graceful/forced cleanup and Windows job behavior, including abrupt supervisor termination. They cannot establish Minecraft loading, rendering, networking or a mod's behavior; use the actual smoke session and project scenarios for those boundaries.
