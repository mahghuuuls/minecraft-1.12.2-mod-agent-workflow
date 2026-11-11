# Owner-Assisted Manual Validation

This file is the authoritative source for presenting owner-assisted runtime checks and dividing evidence collection between the owner and the agent.

Use it when an approved implementation issue requires the owner to interact with a Minecraft client, dedicated server, modpack, alternate runtime, or external multiplayer environment. Verification quality and evidence labels remain governed by `guidelines/coding-standards.md` and `stages/7-implementation.md`; this file governs the human execution interface.

## Goals

- Make each requested action difficult to misread or perform in the wrong state.
- Minimize restarts, configuration churn, repeated prose, and owner transcription.
- Tell the owner why a check exists without exposing internal planning detail they do not need to execute it.
- Collect logs and other agent-accessible evidence directly instead of making the owner relay it.
- Make a successful result easy to report and a failed result precise enough to investigate.

## Before The Session

Re-read this file and the Manual Observability section of every issue in the session before writing the session map, as they are on disk now and not as remembered. Re-read both again after any context loss (a compaction, a new session, a long break) before the next card. A card written from the memory of this file misses the rule added since; a card written from the memory of the issue misses the observable the contract named. An agent may use a reminder of its own, such as an installed skill, to trigger the re-read; the rule holds without one.

Use [Preparation for Approved Tests](process-control.md#preparation-for-approved-tests) for authority to prepare the session.

Before the owner starts a shared game, server, or modpack session, present the complete known validation matrix for that runtime. Keep it compact, but disclose:

- The runtime and environment tier.
- The ordered cards, each starting with an identifier in bold (`1. **G1 Create.** ...`) that the results file repeats on the card's line, and what each demonstrates.
- The path of the results file, on a line of its own: `Results file: workspace/validation/staging/<campaign>/<name>.md`, so `scripts/validate-workspace.ps1` can check that every card has a result line.
- Configuration groups and their exact values.
- Every required start, restart, reconnect, or shutdown point.
- Shared setup, safety preparation, and final cleanup.
- The exact source revision or validation checkpoint used by the runtime and confirmation that its mod worktree is clean.
- The exact development player name and casing when the session reuses an integrated-server world or player record, plus confirmation that the runtime logged in with that identity before any reconnect or persistence card.
- Which evidence the agent will inspect and which observations only the owner can supply.
- A table that maps every acceptance criterion and every verification bullet of the included issues to the card that checks it, or to a recorded waiver or owner-accepted limitation. A unit test counts only when it goes through the production path the criterion is about; a test that builds the result by hand leaves the criterion to a card. A criterion with neither is found here, before the launch, instead of at the campaign closure, where only another launch can fill it. Before presenting the map, check each row against the named card's bundle commands and expected records: the card must set up the state the criterion starts from (a refusal "with a screen open" needs a screen opened first; "after the stop" needs an orderly stop, not an ended process), cover every form the criterion names (each action, not one of them), and run in an environment tier that can show the result. Name in the row the record or file that proves it. A row that fails this check is a card to change now.
- Whether the Agent Diagnostics Toolkit is active, its pinned version and runtime placement, any approved automatic baseline, whether the agent runs the bundles through its command inbox, and the bundle names used during the session.
- When launch tasks synchronize toolkit files, the preserved prior evidence and deployed-input checks from [Bundle And Evidence Workflow](agent-diagnostics-toolkit.md#bundle-and-evidence-workflow).
- When the session loads jars copied from another instance, the result of a dependency check done before the owner launches: read each copied jar's `mcmod.info` (`requiredMods`, `dependencies`) and resolve the needs transitively against the run's mod set, and check the development classpath for a coremod or loader the copied jar would duplicate (the same mod ID already present, such as a mixin loader). A missing dependency or a duplicate costs the owner a launch, and the fix is a copy or a removal the agent can make in advance. `tools/mod-jar/mod-jar.cmd check -Folder <mods directory> -Provided <mod ids already on the development classpath>` performs this check mechanically, including the `@Mod` dependencies that `mcmod.info` does not list. The jar list for the launch is the output of this check, not the plan's list of mod names: run it over the candidate folder until it reports zero problems. Find each `MISSING` mod by running `check` over the source instance's folder, which prints the mod id every jar provides, so a jar whose file name differs from its mod id (a Baubles build named `Bubbles-x.y.z.jar`) is still found. A coremod that carries no `@Mod` class, such as MixinBooter, is reported as `no mod id found`; confirm its jar is in the folder and pass its id with `-Provided`.

- When the session uses a shared test instance, record the checks, baseline snapshot, lock ownership and deployed inputs from [Shared Test Instance Preparation](project-defaults.md#shared-test-instance-preparation).
- Every configuration value the launch depends on, confirmed by a fresh read of the file (its content and its write time) in a call separate from the one that wrote it. Write staging copies and configuration edits with absolute paths: a relative write after a working-directory change was lost once without any error, and the launch ran with the old value. Name each such value by its full path in the file as the game writes it (Forge nests categories, so a key can sit at `general { general { ... } }`), taken from a configuration file the game itself wrote (an as-run copy from an earlier launch, or one written by a launch with the default file), not from memory of the setting's name. A staged file that holds only some keys is compared against that game-written layout before the launch: a key at the wrong level is ignored without an error and the game writes the default beside it.
- When the development client and the development dedicated server run from the same `run` folder (ForgeDevEnv does this), they share `logs/latest.log` and any script log such as `crafttweaker.log`: a client started after the server truncates the script log. Take the server's evidence from the console capture of `tools/host-run`, and when a line reaches only a script log, start the client before the server or observe that line in a client launch. The client's own log is at risk too: a server started while the client runs cannot rotate the open `latest.log`, the two processes then write into the same file (runs of NUL bytes), and the default limit of seven rotated logs a day drops older files after several starts. Copy the client's `latest.log` and the rotated files to the staging folder before each server start and after each stop, and count the NUL bytes in every copy (and the line where they start) before citing it.

Group cards by configuration state and minimize restarts. Do not reveal previously known checks one at a time after the runtime is already open. This overview is a session map, not the detailed procedure for every card.

When the Implementation Plan defines an owner-assisted validation campaign spanning several issues, present one campaign session map and retain each card's issue attribution internally. Do not make the owner manage issue boundaries that do not change the actions, but do preserve enough diagnostic separation for the agent to assign every result correctly.

## Test Card Format

During execution, normally present only the next test card. A small batch is acceptable when the cards are independent, use exactly the same state, and cannot make one another ambiguous. Use this structure and omit fields that genuinely do not apply:

```markdown
### Test: <short player-facing name>

**Purpose:** <one sentence explaining the behavior this distinguishes>

**Starting state**

- <required runtime, screen, equipment, config, or prior card state>
- <exact reset command or setup action when state could carry over>

**Do this**

1. <exact command or physical action>
2. <next action>

**Owner checks**

- <only visual, audio, interaction-quality, or otherwise agent-inaccessible results>

**I will verify**

- <logs, counters, files, or authoritative values the agent will inspect directly>

**Report:** Reply `Done` after completing **Do this** if every listed **Owner checks** item passed. When **Owner checks** is omitted, `Done` confirms that the actions were completed without a visible anomaly. Otherwise report only the mismatch or unexpected behavior.

**After this test:** <keep the game open, close it, preserve state, or perform cleanup>
```

Keep headings and language stable across cards so the owner does not have to relearn the format.

## Card-Writing Rules

- Put commands in copyable code blocks and list them in execution order.
- Write launch steps in the form recorded in `project-setup.md` for the owner (their terminal, working folder, and exact command), not in the form the agent uses for its own builds, and in the copy-paste form of `guidelines/collaboration-guidelines.md` (Communication). When none is recorded yet, ask at the first owner launch and record it.
- When the selected Agent Diagnostics Toolkit supports the required operations, package every deterministic multi-command setup, reset, inspection, marker, and cleanup sequence as a project-owned bundle. The agent starts the bundle through the toolkit's command inbox when it is open, so the owner-facing card contains only genuinely interactive or judgment-dependent steps; without the inbox, the card contains the named run command and those steps. Keep the individual commands in bundle source and evidence documentation for auditability.
- Run the commands under test inside bundles too, unless typing them is itself the behavior under test (a permission refusal, chat feedback, tab completion). An issue's Manual Observability that names commands does not ask the owner to type them.
- When a deterministic sequence cannot be bundled because the selected toolkit lacks a required operation, state that limitation in the plan and present the commands together in one copyable block. Convenience alone is not a reason to make the owner enter a supported sequence manually.
- Distinguish commands from mouse, keyboard, inventory, combat, waiting, or observation steps.
- Do not write "hold" for an item: write "select <item> in the hotbar" for the item in hand, and "right-click once" or "keep right-click pressed for <n> seconds" for using it. Name an item by what the owner sees, with its hotbar slot when several look alike.
- When the selected toolkit has player actions, the agent makes a hotbar selection, a single right or left click, a held use or attack, a drop, the inventory opening and a tooltip reading itself (`guidelines/agent-diagnostics-toolkit.md`, Player Actions), and checks the result from the records; the owner's steps are what those cannot do: aiming, walking, other mods' screens, and what only a person can see.
- Write each owner step from what the owner sees and does, not from what the agent arms. When a step waits for something on screen, name the exact text or sight that will appear, say how long the owner has when there is a limit, and put the command to type in its own copy block. Start a card that needs the game window with clicking into it.
- State the complete starting state. Never rely on the owner remembering an earlier temporary config value, selected hotbar slot, equipped item, game mode, mana value, or diagnostic toggle.
- Reread every bundle a card runs before sending the card, and list as owner steps only what the bundles do not already do. Say on the card when a bundle removes or moves a fixture at its end, so a mob that disappears is expected.
- Name every bundle the card needs, in run order from the last reset, including one an earlier card already ran, or make the bundle set every slot and value its reading depends on. A card that names only the last bundle of a chain is run alone, and the check then runs on a different state than the card claims.
- State disconnect, reconnect and respawn actions as separate steps. When the selected toolkit has client actions, the agent takes them itself (`guidelines/agent-diagnostics-toolkit.md`, Client Actions), and a toolkit reconnect keeps the inbox open. Otherwise, or for a manual leave: leaving a world or stopping the game closes the toolkit inbox; after rejoining it opens again by itself when it opens at the owner's join, else have the owner reopen it. Normal respawn may leave it open: inspect inbox status and request reopening only when it is closed. Follow the selected toolkit version's observed behavior.
- In each launch group, including after a full process restart, bootstrap the toolkit session and bind its operator before any bundle uses operator placeholders. Opening the inbox alone does not restore session/operator binding. Put bootstrap commands in a reusable bundle that does not reset persisted gameplay state, and name it in each launch group's chain. Inspect the sender exit status and the bundle result before dispatching any dependent request; stop on failure.
- When the selected toolkit has the client request channel and the inbox opening at the owner's join, the agent creates or opens the test world, connects to the development server, and closes the game itself (`guidelines/agent-diagnostics-toolkit.md`, Client Request Channel); the owner's step is the launch only.
- When Project Setup records that the agent launches the development client, it starts `gradlew.bat runClient --no-daemon --console=plain` through `tools/host-run` in the background, with a timeout above the session's length, only after telling the owner in chat and only when no client or server of this repository runs. The game opens its own normal window. End the session with `client quit` or the request channel's `quit`; the run's timeout kills the game and is the fallback only. A launch card then holds no command: the owner only needs to be at the computer. The test instance stays the owner's launch through its launcher.
- When the agent starts a dedicated server for the owner to join, give the address with the port from `run/server.properties` (`localhost:<port>`), run the server with a window of several hours or none, and stop it explicitly once the owner has left. A window sized to the cards ends while the owner is still joining, and the run is repeated.
- For a restart card, stop the process. Save and Quit then reopening the world in the same game keeps every static field in memory, so state the mod or the toolkit holds outside the save survives and the restart path never runs. A criterion about a restart needs a real stop and a new launch, such as `/stop` on the development dedicated server and starting it again; check that the new launch's log starts with a fresh `STARTUP`.
- For a persistence card, identify what persistence is actually under test. When only item or capability data must survive, prefer a world-owned fixture such as a labeled chest or other block entity so player-record selection cannot create a false loss. Use player inventory only when player-inventory persistence itself is the subject, and then verify the exact player identity and casing before the first save boundary.
- When a shared setup applies to several consecutive cards, state it once in the session map and identify the exact state or delta each card requires.
- Include a reset step whenever state can leak from a prior card. A reset must be observable or independently checkable when an unapplied reset could produce a false pass.
- Give every fixture the owner must look at a visible identity. When a card asks a visual question about one of several similar objects, have the bundle place a name sign beside each one or give each a distinct look; never ask the owner to tell placeholder look-alikes apart by coordinates.
- Make each bundle set every game rule its own reading depends on and restore it afterwards. A bundle that waits for a tick-driven change sets its own random tick speed, so it records the same result when run alone or out of order as when it follows the bundle that happened to set the speed before.
- Read fixture positions from a record, not from where the owner stands. A bundle that inspects relative to the operator fails silently when the owner has moved; capture the fixture's absolute position when the fixture bundle runs and use it in every later bundle.
- Tie a bundle to its dimension. A bundle built for the Nether or the End records the operator's dimension before it builds anything, and its card names the dimension in the starting state, so a run in the wrong world shows in the record instead of producing a fixture nobody meant to test.
- Build fixtures from blocks that stay put. A gravity block such as sand or gravel in a sky fixture needs a block under it, or it falls and takes the plant, the record, and the card with it.
- Make a portal the bundle places findable. A portal block flush in a dark floor is missed; give it a sign or have the bundle teleport the operator onto it.
- Ask for one visual verdict at a time. A card whose **Owner checks** lists several looks gets `Done` back and the individual answers are lost; when the agent needs more than one verdict, ask one yes-or-no question per item in the report line.
- Define expected results before the action. Include the distinguishing condition that would look different if the feature were absent or broken.
- Derive each expected value by stepping through the mod's rules in the order they run, including every rule that can refuse or change the action before the step the card is about: the start rule, a debt floor, an exemption, a cost listener. A scenario that an earlier rule refuses never reaches the case it names, and the card then shows only the refusal.
- Space the commands of a bundle across ticks (`delayTicks`) when the mod limits how many diagnostic lines it writes in a short time. A bundle that runs several scenarios in one tick loses the lines the limiter drops, and the card then has no evidence for them. Read the limit in the mod's code.
- Prepare a test world before its first card, in the first bundle of the launch group: `gamerule doMobSpawning false`, then a moment of `difficulty peaceful` (it removes every hostile mob in the loaded chunks over the next ticks, including the small slimes that `kill` leaves when a big one splits; mobs saved in unloaded chunks come back with them, and a hardcore world stays hard), removal of dropped items and experience orbs, and a heal. Only then set the card's own difficulty. A world the agent creates or opens can fill with mobs while the owner waits.
- When a card summons a hostile mob, keep both sides alive for the card: give an undead mob an unbreakable helmet (`ArmorItems:[{},{},{},{id:"minecraft:leather_helmet",Count:1b,tag:{Unbreakable:1b}}]`; the sun wears a plain one out, a leather helmet in about two minutes) or `minecraft:fire_resistance` (it stops the damage, not the fire: the mob still burns visibly and a burning zombie can set the player alight) so it survives daylight, and give the player `minecraft:resistance` (for example `effect @s minecraft:resistance 300 4 true`: each level takes 20 percent off, so level 5 takes all of it) as well as instant health. A death in the middle of a card loses the state the card set up. To fill a fixture's health, use `instant_damage` on undead mobs (zombies, husks, skeletons, which `instant_health` hurts) and `instant_health` on other mobs and players.
- Freeze a starting state that changes by itself. When the expected result depends on a state that decays or advances on its own (regeneration, including the health recovery another installed mod adds, such as a food system's; a cooldown, a potion running out, a mob despawning), stop the mechanism for the card (turn it off in that launch's configuration, or, when the action itself can be a bundle command, set the state and act in the same bundle run), or give the owner a time window the agent has checked is long enough. Say which on the card. A card that asks the owner to act "right away" against a fast mechanism tests reaction time, not the mod.
- For a refusal or feedback card, pick a trigger the mod always refuses in that state, or have the bundle fix the view first (for example `tp @s ~ ~ ~ ~ -90` in the bundle looks straight up, so a left click swings at air when nothing is within reach overhead). Otherwise the owner can perform a neighboring action by accident, such as clicking a block within reach instead of swinging at air, and the card fails for the wrong reason.
- When a card checks a value from a lower-priority source (an addon's provider, a fallback, a built-in default), list every source that would win over it (configuration entries, override lists, other providers) and confirm the seed clears each one before the session.
- Copy every expected result on a card from the acceptance criterion it checks or from the authoritative data row (for a data-driven mod, the roster row of the item in play). Do not retype it from memory of the feature: a line that contradicts the criterion costs an owner question at best, and at worst reads as a defect. Check the kind of the item or fixture before naming a line it should show; an item of another kind shows other lines.
- Keep requirement IDs, architecture IDs, implementation history, and evidence theory out of the owner-facing card unless they are necessary to perform the check.
- Verify Minecraft 1.12.2 command syntax, selectors, registry identifiers, fixture behavior, and cleanup commands before presenting them.
- Find, clean up, and assert a fixture by the same selector (a tag, not a display name), so reruns start clean. A step whose selector matches no entity can do nothing and still count as executed, so `failed=0` does not show that each step worked: after every step a later reading relies on, have the bundle check its effect with a query and an assert, and at each card check that every expected entry or record is in the log.
- Check each card against the game facts that silently void a card, before the session:
  - A mob without AI (`NoAI:1b`) does no movement and no block collision: it never falls into a portal, onto a pressure plate, or through a trigger. Use a mob with AI, or move it with a command.
  - Single player has no `save-all`, `stop`, or `op`; save through the toolkit's `save` request.
  - A player's respawn or End exit creates a new player object that keeps the old entity id, so a log label of name and entity id cannot tell the old object from the new one. Read the object identity when the card is about which object answers.
  - The server's tick-start event fires before Minecraft increments its tick counter, so a line logged at the tick start carries the previous tick's number.
  - A warning or error the mod logs once per run appears only the first time in that server run; a card that expects it again needs a fresh start.
  - A canceled join of a player, or of an entity spawned by a dimension change, still adds it to the world.
  Name in the session map the fact each affected expected result depends on.
- State whether the owner should keep the game or server open. Do not leave the runtime lifecycle implicit.
- Do not ask the owner to repeat authoritative values, diagnostic output, log lines, or file content the agent can inspect directly.
- Do not advance from a toolkit-assisted card until the agent has checked bundle completion and readiness marks when later evidence depends on them.
- Keep **Owner checks** limited to visual, audio, interaction-quality, real-multiplayer, or external-environment observations unavailable to the agent. Numeric state, command output, configuration, dimensions, registry state, and retained diagnostic records belong under **I will verify** whenever accessible.
- Ask a specific owner-only question only when `Done` cannot capture a required inaccessible observation.
- When the owner raises an idea, a request, or a question in the middle of a card, finish the card's remaining steps first, or defer the card openly: mark it deferred in the session map with the reason, and bring it back before the session's last launch or record it as not run. A card that is neither finished nor deferred is silently lost, and its gap surfaces only at the campaign closure, when another launch is the only way to fill it.

## Fixture Patterns

These fixture shapes have held up across sessions. Use them before inventing a new one.

- **A sky platform at fixed coordinates.** A bundle teleports the operator to an absolute position high above any terrain (for example `201 151 201`), waits for the chunks, fills a stone platform under that position, teleports again, and builds the fixtures on the platform with name signs. Every later bundle then uses the same absolute coordinates, in any world, with no dependence on where the owner stands or what the terrain is. Build fixtures from blocks that do not fall. The development dedicated server has its own world, a different save from the client's: a scenario that runs there builds its platform there first, because fixtures built relative to the player break on ordinary terrain.
- **A carved room in the Nether.** The same idea below the bedrock roof: teleport to an absolute position around y 100, fill a box of air, lay a floor, and build on the floor. The room needs no portal search once the operator is in the dimension.
- **A platform far from the dragon in the End.** Around `301 151 301` there is only void: the dragon stays near the center and the outer islands start much farther out.
- **Portals from a bundle.** An obsidian frame with a fire block inside lights a Nether portal; an `end_portal` block set in a floor sends the operator to the End from any dimension. Give a floor portal a sign or teleport the operator onto it.
- **One pick per fixture, then the record.** A fixture bundle records its own blocks and the operator position at the end; a check bundle after the owner's hit records the same absolute slots, the tile entity tags, and the inventory. A separate kit bundle switches the owner to survival with an empty inventory just before the hit.
- **A config variant per launch,** kept as a copy in the staging folder with the file as the game rewrote it, and the original restored after the session.
- **A superflat world spawns slimes** in its slime chunks (about one chunk in ten) below y 40, at any light level, and `structures=false` does not stop it. Turn mob spawning off and pass through peaceful in the first bundle (Card-Writing Rules), or use a default world type.

## Evidence Handoff

The owner performs the interaction. The agent collects every accessible current and rotated log, generated file, command result, counter, artifact, or other planned evidence after the card. Copy each launch's current log into the staging folder as soon as the launch ends, with absolute paths, and confirm the copy exists before the next launch rotates the log; a rotated log can still be recovered from the `<date>-<n>.log.gz` files, but a staging copy that silently failed is found only at the campaign's closure. `tools/session-log/session-log.cmd` reads the current and rotated logs, finds each launch, and slices the toolkit records and log lines between two marks or around one bundle run.

When the toolkit can take a screenshot of the owner's client, a still visual result is accessible evidence: the agent requests the screenshot and reads the image itself. A screenshot shows the chat lines and toasts of the moment: bundle output and command feedback cover the lower left for about ten seconds (200 ticks), an open chat screen stays until closed, and a new world's tutorial toast covers the upper right. From toolkit `1.8.0` a screenshot with `hide=chat` leaves the chat lines out of that picture and one with `hide=hud` the whole HUD (`guidelines/agent-diagnostics-toolkit.md`, Other Capabilities To Plan Around), which replaces the wait below in the development client; read the picture anyway, since a HUD-caching mod in a pack can keep the chat in it (Test Instance in `guidelines/project-defaults.md`). Without `hide`, a bundle that takes a screenshot the agent will read turns command feedback off (`gamerule sendCommandFeedback false`, back on in the teardown), closes any open screen first (`devtool client close`), and waits at least 220 ticks after its last chat line before the shot; a card that reads a HUD corner also clears what covers that corner and names the position from the HUD's own anchor. A screenshot captures the screen when the request runs, so for a tooltip or another hover state send the request only after the owner reports the hover, or ask the owner to press F2 and read the image from the `screenshots` folder. Keep motion, sound, and feel as owner checks.

A file the game writes and later removes or rewrites (a pause note, an inbox `status.json`, a lock or secret file) is evidence only as a copy taken when it is read: by the close it is gone or changed, and a read that exists only in the agent's own output cannot be opened by a reviewer. Copy it into the staging folder, with the time in its name, in the same command that reads it. For an absence check, keep the exact command with the absolute path it read, next to an earlier read through the same path that found the file, so the check is seen to be one that could have found it.

Use **Owner checks** only for evidence the agent cannot reliably obtain, such as:

- Visual layout or animation.
- Audio.
- Perceived input or interaction behavior.
- Real multi-client privacy or isolation.
- Behavior in an external environment whose files the agent cannot access.

Use **I will verify** for accessible authoritative evidence. Do not ask the owner to transcribe it. A self-reported diagnostic still requires the independent corroboration defined by the issue's Manual Observability contract.

Before recording a card result, compare the bundles that started since the previous card (the toolkit's `BUNDLE_START` records, sliced with `tools/session-log`) with the bundles the card's steps name. A step with no start record means the card's claim was not exercised: say so and rerun the step instead of scoring the card from the owner's `Done`.

For stateful, failure-sensitive, or fixture-sensitive cards, inspect the planned evidence before sending the next card. For independent visual cards, a small batch may be completed before log inspection when the shared evidence remains attributable.

## Failure And Revision

When the owner reports a mismatch:

- Stop dependent cards.
- Preserve the current state when it may help diagnosis; otherwise give an explicit cleanup step.
- Inspect accessible evidence before asking the owner to repeat the check.
- Ask only for the missing observation needed to distinguish plausible causes.
- If the fixture, command, or expected result was wrong, correct the card and explain the material change.
- Do not count a check as passed merely because the owner completed the actions.
- A result that differs from the card's expected value is a deviation to record at once, never a pass with a new explanation.
- When a session ends from outside in the middle of a card (a crash, a stop by another project, the game closed early), write that card's running-notes lines at once, with what was and was not observed, before any rerun.
- When the owner changes owner-visible behavior during a card (a design change, not a defect), name at once the approved requirement text the change contradicts and record it in the session notes. Draft the bounded revision for the owner's approval at the campaign close, with the results; the change follows the backward-transition rules in `guidelines/process-control.md`.

## Completion And Cleanup

At the end of the session:

- State which cards passed, failed, were deferred, or were waived.
- Inspect the final accessible evidence and record it in the owning issue.
- Disable temporary diagnostics and restore temporary configuration or world state.
- Reset the test instance to its recorded baseline and remove this project's lock note (Test Instance and Shared Machine in `guidelines/project-defaults.md`): compare the `mods` folder with the template list rather than remembering what was copied, and restore changed configuration from the copy taken before the session.
- State whether the owner may close the client/server or whether another approved session remains.
- Do not make the owner restate successful observations already covered by `Done`.
- When the session ends a campaign, close the campaign through `procedures/close-campaign.md`; the instance reset is its last step, not the session's.
