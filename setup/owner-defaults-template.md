# Owner Defaults

This template captures setup-stage preferences and owner-specific overrides for one workflow owner. Copy it to:

```text
workspace/documentation/owner-defaults.md
```

The copied file is workspace-specific and should stay ignored by Git. Keep this template generic.

Do not duplicate general workflow rules here. If a preference should apply to every workflow user, put it in the appropriate committed guideline, stage, workflow, or setup default instead.

## Preferred Project Setup Defaults

Use these as starting recommendations during Project Setup unless the owner or project context points elsewhere:

- Loader:
- Runtime target:
- Implementation language:
- Template candidate:
- Distribution platform:
- License:
- Default branch:
- Development Java preference:
- Release target Java version:
- Modern Java syntax:

Project-specific needs may override these defaults. Revisit them when the concept needs Mixins, coremods, access transformers, shaded dependencies, unusual build automation, another distribution platform, or runtime-exclusive behavior.

## Setup Question Defaults

Use this section only for questions the owner repeatedly answers the same way during Project Setup.

- Repository owner or GitHub username:
- Default mod author metadata:
- Default Minecraft development username:
- Preferred repository naming pattern:
- Other setup answers:

## Owner-Specific Overrides

Record only overrides or additions that are specific to this owner and not already part of the general workflow defaults.

- Release ownership overrides:
- Documentation style overrides:
- Validation ownership overrides:
- Communication preferences not covered by `guidelines/collaboration-guidelines.md`:
- Other recurring owner-specific preferences:

## Notes For Future Mods

-
