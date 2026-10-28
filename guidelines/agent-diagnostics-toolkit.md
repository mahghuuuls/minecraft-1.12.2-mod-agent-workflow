# Agent Diagnostics Toolkit Integration

This file is the authoritative source for selecting and using the optional Agent Diagnostics Toolkit during mod development.

The toolkit is a separate Minecraft 1.12.2 Forge mod. Its current repository is `https://github.com/mahghuuuls/agent-test-toolkit`, and its current release is `1.3.0` (tag `v1.3.0`). The mod and its jar are named **Agent Test Toolkit** and use the identifier `agenttesttoolkit`; its CurseForge page is titled **Agent Diagnostics Toolkit**. It prepares repeatable test environments from JSON command bundles and writes structured diagnostic records into the normal Minecraft log. From `1.3.0` it also has a command inbox through which the agent starts bundles itself (Command Inbox below).

It is a development aid, not a library API for the mod under development.

## Project Setup Decision

During Project Setup, resolve exactly one preference:

- **Prefer:** Use the toolkit when it is compatible with the approved development runtime and a verified artifact is available.
- **Ask each project:** Present the choice during each Project Setup.
- **Do not use:** Do not install or plan around the toolkit unless the owner overrides this preference for the active project.

Read the preference from `workspace/documentation/owner-defaults.md` when present. If the owner answers during Project Setup and wants the answer reused, persist it there. A saved **Prefer** or **Do not use** answer removes the repeated setup question; it does not override a later project-specific instruction.

The project-specific setup artifact must record:

- The selected use decision and source of that decision.
- The pinned toolkit version and artifact identity, or when they must be resolved.
- The acquisition and installation method.
- The client, integrated-server, and dedicated-server environments that will contain it.
- Whether client defaults or operator join automation are enabled, and the client default values.
- Whether the command inbox is enabled, and in which runtimes.
- Known compatibility limitations.
- The location of the toolkit feedback log when use is selected.

Do not block the first design stages merely because a release artifact is not yet available. Make artifact acquisition and verification due before the first validation card that depends on the toolkit.

## Acquisition And Dependency Boundary

Use a released, versioned JAR whenever possible. Prefer acquisition sources in this order:

1. A verified CurseForge or other approved distribution file with an immutable file identity.
2. A verified GitHub release asset.
3. An owner-provided local release JAR.
4. A JAR built from a pinned source revision in a separate toolkit checkout, only when no suitable released artifact exists or toolkit development is itself in scope.

Record the source URL or local source, version, file name, and SHA-256 hash. Do not silently replace the artifact during an active validation campaign. A version change requires renewed capability inspection and invalidates evidence that depends on the previous version unless the issue explains why it remains applicable.

The toolkit must be development-runtime only:

- Do not add it to the mod's compile API or implementation classpath unless a separately approved feature intentionally integrates with a public toolkit API.
- Do not shade, embed, relocate, or copy its classes into the shipping mod JAR.
- Do not declare it as a required player dependency in shipping metadata, publication relations, or public installation instructions.
- Do not include its JAR in a release handoff for the mod under development.
- Inspect the generated mod artifact and dependency metadata when the build configuration could accidentally package or publish it.

When the selected template supports a development-only runtime configuration, use that configuration and its required deobfuscation mechanism. The agent-managed test instance may instead receive the pinned release JAR directly in its `mods` directory. Do not assume that the same obfuscated JAR can be dropped into a deobfuscated `runClient` or `runServer` environment; verify the selected template's local-file or remote dependency path. The exact Gradle notation is template-specific and must be verified against that build rather than copied from another project.

Do not clone the toolkit repository into every mod project. A source checkout is optional reference material under `workspace/dependencies/` when exact source inspection is needed, and it remains a separate repository. The released JAR is sufficient for normal use.

CurseForge availability affects only the preferred acquisition method. It does not block designing the integration or using another verified release artifact. Do not invent CurseMaven coordinates before the approved file is publicly available and its project and file identifiers have been inspected.

## Runtime Placement

Toolkit observation and commands execute on the logical server.

- For singleplayer, install the toolkit in the development client runtime, which also hosts the integrated server.
- For a dedicated-server check, install it in the dedicated server runtime.
- Install it on the physical client when client defaults (Safe Baseline Environment) or screenshots on request are required. Everything else acts on the server.
- From `1.3.0`, a client without the toolkit can join a server that has it (observed for `1.3.0`). For an earlier pinned version, do not assume that topology unless it is verified for that version.

Start a toolkit-assisted session by confirming the live build and environment with its capability, environment, and mod-list commands. Exact commands and record shapes belong to the pinned toolkit version's `AGENTS.md`; read that file before authoring bundles. This workflow records how the toolkit is used, not a frozen duplicate of its entire command surface.

## Safe Baseline Environment

The recommended disposable-world baseline is:

- Creative mode for the test operator.
- `keepInventory` enabled.
- Natural mob spawning disabled.
- Client brightness set to the brightest supported vanilla value.
- Client music volume set to 0 percent and master volume to 50 percent.
- Client weather, hostile, friendly and ambient sounds set to 0 percent, so the owner hears the mod and not the world.
- The client keeps running when its window loses focus, so a test does not stall while the owner reads a card or a terminal takes focus. In single player a paused game runs no ticks, so a wait, a checkpoint or an inbox request would stop with it.

`owner-defaults.md` may set other values; apply those instead.

The world settings are ordinary Minecraft commands in a bundle. The client settings are opt-in toolkit configuration, because logical-server commands cannot change physical-client options. With `1.3.0` or later, the development `run/config/devtool/devtool.cfg` carries them like this (keys as the pinned `AGENTS.md` names them):

```text
client {
    B:applyOnJoin=true
    D:brightness=1.0
    D:musicVolume=0.0
    D:masterVolume=0.5
    D:weatherVolume=0.0
    D:hostileVolume=0.0
    D:friendlyVolume=0.0
    D:ambientVolume=0.0
    B:noPauseOnLostFocus=true
}
```

Check the key names and value types against the configuration file the pinned version writes before editing it. The client applies these once per launch, at the first world join, and saves them to `options.txt`, so they stay after the key is turned off; F3+P in game turns the pause back on. A volume key left at its default (`-1`) leaves that category alone. Before `1.3.0` only brightness and music are toolkit settings: set the rest in the development `run/options.txt` (`soundCategory_master:0.5`, `soundCategory_weather:0.0`, `soundCategory_hostile:0.0`, `soundCategory_neutral:0.0` for friendly creatures, `soundCategory_ambient:0.0`, and `pauseOnLostFocus:false`) with the game closed, or ask the owner to set them once.

A reusable baseline bundle may use this shape after its commands have been checked against the pinned version:

```json
{
  "workflow_safe_baseline": {
    "description": "Apply safe defaults for a disposable creative test world",
    "stopOnFailure": true,
    "commands": [
      "gamemode creative",
      "gamerule keepInventory true",
      "gamerule doMobSpawning false",
      "devtool environment",
      "devtool inspect player",
      "devtool mark BASELINE_READY"
    ]
  }
}
```

This bundle does not create or reset an arena, clear inventory, kill entities, or alter the day/weather cycle. Add those only to a scenario that needs them. The client settings stay in the configuration above.

Client settings and join automation are both opt-in because they mutate persistent application or world state. Enable them only when the owner selects them for the active development environment.

An operator join bundle must be:

- Restricted to a disposable development world or server.
- Idempotent.
- Limited to the approved baseline and other explicitly approved safe setup.
- Free of arena reset, arena clear, inventory clearing, entity killing, broad teleportation, or other destructive scenario-specific work.

Keep destructive or feature-specific setup in the named test bundle the owner deliberately runs. Never enable login automation in an external multiplayer server, normal play world, or modpack instance without explicit authorization for that exact environment.

## Bundle And Evidence Workflow

Use the toolkit to reduce deterministic command transcription, not to hide the test from the owner:

1. The agent writes or updates the scenario bundle in the active runtime.
2. The agent starts the bundle itself through the command inbox (next section). Without the inbox (a version before `1.3.0`, or the inbox not enabled for that runtime), the owner runs one named bundle command instead.
3. The owner performs the small number of gameplay actions in the test card.
4. The agent reads the bundle's result file and the accessible current or rotated log, and attributes the records to the issue and card.

From `1.3.0` the toolkit reloads bundles and configuration at every world start, so the owner no longer types `devtool reload` after opening a world. A bundle file changed while a world is open still needs a reload: the agent sends `reload` through the inbox, or the owner types it.

If the owner would otherwise type a deterministic multi-command setup, reset, inspection, marker, or cleanup sequence that the selected toolkit supports, move that sequence into a project-owned bundle. Keep the individual commands readable in bundle source and evidence documentation. Keep physical gameplay actions, visual observations, audio observations, and subjective interaction quality in the test card.

Every setup bundle should normally:

- Start a named diagnostic session.
- Establish or reset the complete starting state.
- Inspect relevant bypass state such as game mode, held items, inventory, or target state.
- Enable only the narrow event categories needed for the test, after noisy setup actions finish.
- Place a mark immediately before each owner action whose absence would otherwise be ambiguous.
- End with a clear readiness mark after required delays.

Provide an idempotent teardown bundle when the scenario changes persistent state. Disable logging early during teardown. Arena creation, reset, and clear are destructive within their bounds and belong only in disposable test environments.

The toolkit complements the mod's own diagnostics. It can record generic game events and exposed state, but it cannot explain which internal branch, formula, synchronization decision, or compatibility path the mod used. Keep mod-specific diagnostics when an acceptance criterion depends on those decisions.

Toolkit logs are evidence only when the setup is also evidenced. A missing event is ambiguous if the category was disabled, a filter excluded it, the owner never reached the action, the wrong process log was inspected, or a restart rotated `latest.log`. Follow the pinned toolkit guide and the evidence rules in `stages/7-implementation.md`.

## Command Inbox

From `1.3.0`. The pinned version's `AGENTS.md` owns the request lines, the result-file fields, the records and the refusal reasons; read its inbox section before the first request. This section says how the workflow uses it.

**Where it may be enabled.** Set the toolkit's `inbox.enabled` key to true only in the development runtimes and the agent-managed test instance, and record that in the project setup. Never in an external server, a normal play world, or a modpack instance outside the approved test scope. Set it back to false in the test instance at its reset.

**Who opens it.** Only a person, by typing `/devtool inbox open` in chat, once each time a world opens. A bundle cannot open it; do not try through a bundle or a join hook. Put the opening on the session's first card and again after anything that closes it: the owner leaving or reconnecting, a server stop or restart, another world. Before each request, check that `status.json` exists in the inbox folder; no file means the inbox is closed.

**What it runs.** A named bundle, `reload`, `save`, `mark`, the read-only inspections, and a screenshot of the opener's client. No vanilla command and nothing else. Anything that changes the world goes in a project bundle the owner can read. Requests run as the player who opened the inbox, with that player's permissions, and the run's `BUNDLE_START` says `channel=inbox`.

**How to send a request.** Write `<id>.tmp` in the inbox folder, rename it to `<id>.req`, and wait for `<id>.result.json`. Use a new id for every request: a reused id is refused and never run. Judge the run by the result file's outcome and counters, then read the log records it names. The toolkit never deletes files in the folder; tidy it only while the inbox is closed.

**Single player.** A paused single-player game reads nothing. With the no-pause client default on, only an open menu pauses it; a request that waits longer than expected usually means a menu is open.

**Order on a card.** Run the setup bundle, confirm its result, then send the card; after the owner reports, run the check bundle. The owner never waits on a bundle the agent has not confirmed.

## Other Capabilities To Plan Around

From `1.3.0`, read the pinned `AGENTS.md` for the exact forms:

- **`devtool save`** writes player data and every loaded world, in single player and on a dedicated server, without stopping anything. Use it for a save boundary inside a bundle. It is not a restart.
- **The `WORLD` record** at every world start names the save folder and seed; a session ends when a different save opens. Use it to tell which save and which launch a stretch of log belongs to.
- **Screenshots on request** (`devtool screenshot <label> [delayTicks]`) save the owner's view to that client's `screenshots/` folder (`run/screenshots/` in development). The agent can open the image itself, so a still visual check (is the block there, is the overlay drawn, what the inventory shows) can move from **Owner checks** to **I will verify**. Motion, sound and feel stay owner checks. The client needs the toolkit.
- **Attribute and Baubles inspection** read attributes with every modifier, and bauble slots when Baubles is installed, without asking the owner to describe a tooltip.
- **Tolerated failures leave a `TOLERATED` record**, and `BUNDLE_END` counts them, so a teardown step that found nothing is distinguishable from one that ran.

## Test Asset Retention

Runtime bundle files may be ignored and temporary, but evidence must remain attributable.

- Record the runtime bundle path and hash in the owning issue before cleanup or replacement.
- Preserve the relevant log or rotated log when a restart could overwrite its identity.
- Keep reusable regression bundles under a clearly named project verification directory when the project benefits from version-controlled test assets.
- Do not copy toolkit source, binaries, or its own example bundles into the mod repository merely to preserve a scenario.

## Owner-Facing Test Cards

Toolkit-assisted cards still follow `guidelines/manual-validation.md`. The session map should state that the toolkit is active, the pinned version, the runtime that hosts it, any automatic baseline, whether the agent runs the bundles through the inbox, and the bundle names that will be used.

With the inbox open, **Do this** holds no toolkit command at all: the agent has already run the setup bundle and says so in **Starting state**, and the steps are only the gameplay. The first card of a session, and the first after anything that closes the inbox, starts with:

```text
/devtool inbox open
```

Without the inbox, place only the bundle command under **Do this**, then the gameplay:

```text
/devtool run <bundle_name>
```

Put records, counters, log lines, bundle completion, result files, screenshots the agent reads, and authoritative inspections under **I will verify**. Ask the owner to report only results the agent cannot obtain from the runtime files.

Do not call a bundle successful because the command was accepted. Inspect its end record, failures, readiness marks, enabled categories, and relevant setup inspections before accepting the gameplay result.

## Toolkit Feedback

When the toolkit is selected, create:

```text
workspace/documentation/agent-diagnostics-toolkit-feedback.md
```

from `setup/agent-diagnostics-toolkit-feedback-template.md`.

Record a feedback entry when development reveals:

- A missing generic fixture, action, observer, inspection, filter, lifecycle hook, or client default that would reduce repeated owner work.
- A command, record, or failure mode that an agent could misinterpret.
- A defect or compatibility problem in the toolkit.
- A recurring bundle pattern that belongs in the toolkit rather than every mod project.

Do not record mod-specific game logic as a toolkit request. Separate observations from suggested solutions and include the toolkit version, environment, reproduction, expected diagnostic value, current workaround, and supporting log or bundle paths.

Use these statuses:

- **Candidate:** observed once and worth retaining.
- **Confirmed:** reproduced or encountered in more than one relevant test.
- **Reported:** transferred to the toolkit project or issue tracker.
- **Resolved:** verified in a later toolkit version.
- **Rejected:** determined to be mod-specific, unsafe, outside toolkit scope, or not useful enough to retain.

Feedback collection does not authorize changes to the toolkit repository, opening an external issue, or updating the pinned toolkit version. Those are separate actions.

## When Not To Use It

Do not force toolkit use when:

- The selected runtime is incompatible with the available toolkit artifact.
- The check is entirely automated and the toolkit adds no evidence.
- The required observation is purely visual, audio, timing-sensitive at the client, or internal to the mod and the toolkit cannot expose it.
- Installing it would alter an external environment outside the owner's approved test scope.
- A minimal mod-specific fixture provides stronger and simpler evidence.

Record the limitation or alternative. Optional tooling must not become a gate that prevents valid testing.
