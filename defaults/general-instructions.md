# Standing Minecraft Mod Instructions

## Platform
- All mods target Minecraft Forge 1.12.2.
- CurseForge is the only release platform.
- Use `mah-mod-template` as the canonical structure for new mods and migrations.
- Follow the template README and build conventions.
- Use the template's modern Gradle and Java development environment.
- Released mods must remain compatible with Java 8 unless explicitly stated otherwise.

## Existing Mods
- Preserve existing gameplay behavior unless a change is requested.
- Preserve mod IDs, packages, registry names, dependencies, and config keys where practical.
- Migrate old build systems to the template without unrelated rewrites.
- Keep existing worlds and configuration files compatible whenever reasonably possible.
- Never remove or silently change a released feature without discussing it first.

## Code Design
- Follow the existing architecture when working on an established mod.
- Choose an architecture appropriate to the mod's size and behavior.
- Prefer cohesive classes with clear responsibilities and minimal coupling.
- Favor composition over inheritance when practical.
- Use dependency injection where it improves separation and testability.
- Apply design principles pragmatically rather than mechanically.
- Avoid premature abstractions, unnecessary layers, and speculative flexibility.
- Remove duplication when it represents genuinely shared behavior.
- Tolerate small duplication when an abstraction would make the code harder to understand.
- Optimize for correctness, readability, maintainability, and Forge 1.12.2 compatibility.

## Forge Development
- Run gameplay logic on the server unless client behavior is explicitly required.
- Avoid importing `net.minecraft.client.*` from common or server code.
- Do not add proxies unless the mod has client-only initialization.
- Respect canceled Forge events and use suitable event priorities.
- Handle players, fake players, missing registry IDs, modded entities, and null sources safely.
- Use synchronized Minecraft APIs when changing potion effects or other tracked state.
- Consider interactions between all enabled modules, not only isolated behavior.
- Avoid retaining player, entity, or world references longer than necessary.

## Configuration
- Give every option a clear comment describing its gameplay consequences.
- Prefer independent settings where different systems may need different behavior.
- Preserve existing config keys and defaults unless changes are explicitly requested.
- Avoid arbitrary limits or validation unless required for correctness or server safety.
- Mark settings as restart-required when runtime objects snapshot their values.
- Keep allow-list, exclude-list, and precedence behavior explicit and consistent.

## Dependencies
- Declare required dependencies in both development configuration and mod metadata.
- Use CurseMaven for CurseForge dependencies when appropriate.
- Never bundle another mod into the release JAR unless explicitly required and legally permitted.
- Preserve required dependency versions and loading order where compatibility requires them.

## Verification
- Run `gradlew build` after implementation.
- Run `gradlew clean build` before a release.
- Review dedicated-server safety, event cancellation, client synchronization, entity IDs, state cleanup, and cross-module interactions.
- Check behavior with both default and unusual but valid configuration combinations.
- Automated tests are not required unless explicitly requested.
- Provide focused manual test scenarios for gameplay changes.
- Treat a successful build as necessary but not sufficient evidence that runtime behavior is correct.

## Git
- Work on the branch already checked out.
- Never create a pull request unless explicitly requested.
- Never commit or push unless explicitly requested.
- Preserve unrelated user changes and never revert them.
- Keep changes scoped to the requested mod and feature.
- Inspect the working tree before and after making changes.

## Documentation
- README files should explain player behavior, features, defaults, and configuration.
- Do not add development or build instructions unless requested.
- Keep documentation concise and free of unnecessary implementation details.
- Ensure documented defaults match the source configuration exactly.

## Releases
- Use semantic versions such as `1.1.0`.
- Update the version and changelog only when release preparation is requested.
- Changelogs are written for mod users, not as engineering histories.
- Include gameplay additions, relevant behavior changes, and meaningful configuration changes.
- Exclude internal refactors, README edits, and fixes to features that were never publicly released.
- Verify release metadata, dependencies, documentation, and license attribution.
- Build and identify the normal release JAR, never the development or sources JAR.

## Attribution
- Use `Mahghuuuls` as the author and copyright name.
- Preserve required upstream license notices.
- Retain CleanroomMC attribution when code or build infrastructure derived from ForgeDevEnv is used.