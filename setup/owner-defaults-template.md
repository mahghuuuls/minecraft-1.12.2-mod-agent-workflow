# Owner Defaults

This template captures setup-stage preferences and owner-specific overrides for one workflow owner. Use the owner-designated local file when one already exists. To create workspace-specific defaults, copy this template to:

```text
workspace/documentation/owner-defaults.md
```

Keep the working file local and this template generic.

Do not duplicate general workflow rules here. If a preference should apply to every workflow user, put it in the appropriate committed guideline, stage, workflow, or setup default instead.

## Preferred Project Setup Defaults

Use these as starting recommendations during Project Setup unless the owner or project context points elsewhere:

- Loader:
- Runtime target: Cleanroom (the workflow's only runtime target; record a note here only if a template decision depends on it)
- Implementation language:
- Template candidate:
- Distribution platform:
- License:
- Default branch:
- Development Java preference:
- Release target Java version:
- Modern Java syntax:

Project-specific needs may override these defaults. Do not ask the owner to predict advanced technical needs during Project Setup for a new mod. Revisit Mixins, coremods, access transformers, shaded dependencies, unusual build automation, distribution exceptions, or runtime-exclusive behavior only after the concept or existing-project evidence makes them relevant.

## Setup Question Defaults

Use this section only for questions the owner repeatedly answers the same way during Project Setup.

- Repository owner or GitHub username:
- Default mod author metadata:
- Default Minecraft development username:
- Preferred repository naming pattern:
- Other setup answers:

## Stage Transition Preferences

Use [Stage Transition Preferences](../guidelines/process-control.md#stage-transition-preferences). Recommend All for first-time users. Save a choice here only when the owner authorizes reuse.

- Approval before entering stages: All | Selected | None
- Selected stage names, when applicable:
- Owner authorization date and scope of reuse:
- Offer Workflow Changes after workflow or cycle closure: No | Yes

## Implementation Review Cadence

- Reusable owner choice under [Implementation Review Cadence and AFK Mode](../guidelines/process-control.md#implementation-review-cadence-and-afk-mode):
- Preferred milestones when applicable:
- Owner authorization date and scope of reuse:

## Test Instance

Record reusable packaged-runtime preferences once. [Test Instance](../guidelines/project-defaults.md#test-instance) owns the choice between an isolated runtime and a shared launcher instance. The fields below describe the shared-instance option.

- Launcher:
- Instance name and path:
- Template and version (default: CleanroomTestBench from CurseForge):
- Baseline mod list location (captured after the first world join, before adding project mods):
- Version the runtime reports for `mixinbooter`, with the template and Cleanroom versions it was read from (from `Client attempting to join with ... mods` in a log that entered a world; read again when either changes):
- Game-written configuration files exempt from the reset, if any:
- Fallback instance on standard Forge, when the Cleanroom relauncher failed:
- OptiFine JAR directory (fill in when an [OptiFine compatibility check](../guidelines/project-defaults.md#optifine-compatibility-checks) requires it):

## Local Test Server EULA

- Owner acceptance and date:
- EULA link: https://www.minecraft.net/en-us/eula
- Scope and authorization to apply across future Minecraft 1.12.2 mod projects:

## Isolated Cleanroom Runtime Preferences

- Preferred packaged test route: Isolated Cleanroom runtime | Shared launcher instance | Ask
- Agent launch of local test servers and scope of reuse:
- Agent launch of graphical test clients, announcing first, and scope of reuse:
- Toolkit menu/player control in isolated test runtimes and scope of reuse:
- Approved runtime/cache locations and preferred version pins, if known:
- Resource and concurrency limits, if different from the workflow default:

## Modpack Reference

- Default [read-only modpack reference](../guidelines/project-defaults.md#read-only-modpack-references) authorized by the owner for use across projects (name and absolute instance directory):

## Agent Diagnostics Toolkit Preference

- Use for owner-assisted runtime testing: Prefer | Ask each project | Do not use
- Apply safe disposable-world baseline by default: Yes | Ask each project | No
- Allow operator join automation for that baseline by default: Yes | Ask each project | No
- Client defaults (toolkit 1.3.0 or later; default: brightness 1.0, music 0, master 0.5, weather 0, hostile 0, friendly 0, ambient 0, no pause on lost focus): Use the defaults | Use these values: | Do not set
- Command inbox in development runtimes and the test instance (toolkit 1.3.0 or later): Yes | Ask each project | No
- Who launches the development client: Agent, through `tools/host-run`, telling me first | Ask each project | Owner
- Client actions (respawn, reconnect, close a screen; from 1.5.0 also quit; from 1.7.0 also the player actions: select, click, hold, drop, inventory, tooltip) in development runtimes and the test instance (toolkit 1.4.0 or later): Yes | Ask each project | No
- Operator rights for your own join on the development dedicated server, taken back when you leave (toolkit 1.7.0 or later): Yes | Ask each project | No
- Menu steps from the title screen (create or open a world, connect, quit) and the inbox opening by itself at your own join, in development runtimes and the test instance (toolkit 1.5.0 or later): Yes | Ask each project | No
- Other recurring toolkit preferences:

## Owner-Specific Overrides

Record only overrides or additions that are specific to this owner and not already part of the general workflow defaults.

- Release ownership overrides:
- Mod page screenshots (Release Presentation, Screenshot paths): Agent captures | Owner provides | Agent helps prepare owner captures | Deferred | Ask each project
- Documentation style overrides:
- Validation ownership overrides:
- Communication preferences not covered by `guidelines/collaboration-guidelines.md`:
- Other recurring owner-specific preferences:

## Public Copy Preferences

- Player-facing copy length: Minimal | Expanded
- Punctuation or style restrictions:
- AI usage disclaimer wording:
- AI usage disclaimer link:
- Placement of unverified-validation notes: Internal only | Repository documentation | Player/download page when installation-relevant
- Other recurring public-copy preferences:

## Chat Format Preferences

How the owner wants the agent's messages shaped. These are about reading and copying, not about the project, so they apply to every mod and every stage.

- Actions as a bullet list or one action per line, never in a paragraph: yes or no
- Every command the owner must type (game chat commands and shell commands) in its own fenced code block, one command per block, repeated in the message that asks for them: yes or no
- Shell command form on this machine (for example `./gradlew.bat <task>` in PowerShell):
- Message length and tone (for example short replies, one thing at a time, two options at most with the agent's pick first):
- Other reading preferences:

## Git Workflow Preferences

- Routine mod-repository Git policy (see `guidelines/collaboration-guidelines.md`): Automatic | Ask
- Preferred push cadence: Each completed checkpoint | Stage completion | Release-ready handoff
- Explicit restrictions or deferrals:
- Other Git workflow preferences:

## Shared Documentation Backup

Use `Approved` in Automatic sync to authorize routine backups under `procedures/documentation-backup.md`. Enter the private destination's repository name, numeric GitHub ID, and branch in the format below.

- Automatic sync: Disabled.
- Destination: private GitHub repository `<owner>/<repo>`, repository ID `<id>`, branch `<branch>`.
- Artwork backup: Disabled.

Set Artwork backup to `Approved` separately to allow routine backup of artwork versions the owner approves and the workspace records under the [artwork backup procedure](../procedures/documentation-backup.md#optional-artwork-backup).

## Notes For Future Mods

-
