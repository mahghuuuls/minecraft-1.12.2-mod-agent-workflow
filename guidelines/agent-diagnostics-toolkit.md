# Agent Diagnostics Toolkit Integration

This file is the authoritative source for selecting and using the optional Agent Diagnostics Toolkit during mod development.

The toolkit is a separate Minecraft 1.12.2 Forge mod. Its current repository is `https://github.com/mahghuuuls/agent-test-toolkit`. The v1.0.0 release and older public material may call it **Agent Test Toolkit**, and artifact and mod identifiers may still use `agenttesttoolkit`. It prepares repeatable test environments from JSON command bundles and writes structured diagnostic records into the normal Minecraft log.

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
- Whether client defaults or operator join automation are enabled.
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

When the selected template supports a development-only runtime configuration, use that configuration and its required deobfuscation mechanism. A normal packaged Forge test instance may instead receive the pinned release JAR directly in its `mods` directory. Do not assume that the same obfuscated JAR can be dropped into a deobfuscated `runClient` or `runServer` environment; verify the selected template's local-file or remote dependency path. The exact Gradle notation is template-specific and must be verified against that build rather than copied from another project.

Do not clone the toolkit repository into every mod project. A source checkout is optional reference material under `workspace/dependencies/` when exact source inspection is needed, and it remains a separate repository. The released JAR is sufficient for normal use.

CurseForge availability affects only the preferred acquisition method. It does not block designing the integration or using another verified release artifact. Do not invent CurseMaven coordinates before the approved file is publicly available and its project and file identifiers have been inspected.

## Runtime Placement

Toolkit observation and commands execute on the logical server.

- For singleplayer, install the toolkit in the development client runtime, which also hosts the integrated server.
- For a dedicated-server check, install it in the dedicated server runtime.
- Install it on the physical client when client brightness or music defaults are required.
- Do not assume a client without the toolkit can connect to a toolkit-enabled server unless that topology is verified for the pinned version.

Start a toolkit-assisted session by confirming the live build and environment with its capability, environment, and mod-list commands. Exact commands and record shapes belong to the pinned toolkit version's `AGENTS.md`; read that file before authoring bundles. This workflow records how the toolkit is used, not a frozen duplicate of its entire command surface.

## Safe Baseline Environment

The recommended disposable-world baseline is:

- Creative mode for the test operator.
- `keepInventory` enabled.
- Natural mob spawning disabled.
- Client music volume set to 0 percent.
- Client brightness set to the brightest supported vanilla value.

The toolkit currently supports the world settings through ordinary bundled Minecraft commands and supports opt-in client brightness and music defaults. Master volume is not part of the inspected toolkit configuration. Do not claim that it will be set to 50 percent; record that as a toolkit feature request if the project needs it.

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

This bundle does not create or reset an arena, clear inventory, kill entities, or alter the day/weather cycle. Add those only to a scenario that needs them. Client brightness and music remain toolkit configuration because logical-server commands cannot change physical-client options.

Client settings and join automation are both opt-in because they mutate persistent application or world state. Enable them only when the owner selects them for the active development environment.

An operator join bundle must be:

- Restricted to a disposable development world or server.
- Idempotent.
- Limited to the approved baseline and other explicitly approved safe setup.
- Free of arena reset, arena clear, inventory clearing, entity killing, broad teleportation, or other destructive scenario-specific work.

Keep destructive or feature-specific setup in the named test bundle the owner deliberately runs. Never enable login automation in an external multiplayer server, normal play world, or modpack instance without explicit authorization for that exact environment.

## Bundle And Evidence Workflow

Use the toolkit to reduce setup transcription, not to hide the test from the owner:

1. The agent writes or updates the scenario bundle in the active runtime.
2. The owner normally runs only the toolkit reload command and one named bundle command.
3. The owner performs the small number of gameplay actions in the test card.
4. The agent reads the accessible current or rotated log and attributes the records to the issue and card.

If the owner is being asked to type a repeatable setup command sequence, move that sequence into the bundle. Keep physical gameplay actions, visual observations, audio observations, and subjective interaction quality in the test card.

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

## Test Asset Retention

Runtime bundle files may be ignored and temporary, but evidence must remain attributable.

- Record the runtime bundle path and hash in the owning issue before cleanup or replacement.
- Preserve the relevant log or rotated log when a restart could overwrite its identity.
- Keep reusable regression bundles under a clearly named project verification directory when the project benefits from version-controlled test assets.
- Do not copy toolkit source, binaries, or its own example bundles into the mod repository merely to preserve a scenario.

## Owner-Facing Test Cards

Toolkit-assisted cards still follow `guidelines/manual-validation.md`. The session map should state that the toolkit is active, the pinned version, the runtime that hosts it, any automatic baseline, and the bundle names that will be used.

Normally place only these toolkit commands under **Do this**:

```text
/devtool reload
/devtool run <bundle_name>
```

Then list the gameplay action. Put records, counters, log lines, bundle completion, and authoritative inspections under **I will verify**. Ask the owner to report only results the agent cannot obtain from the runtime files.

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
