# Coding Standards

These standards apply to implementation work across all mod projects. Project-specific architecture and established repository conventions take precedence when they explicitly differ.

## General Design

- Optimize for correctness, readability, maintainability, Minecraft 1.12.2 compatibility, and the approved loader/runtime targets.
- Give classes and components clear, cohesive responsibilities.
- Keep dependencies intentional and minimize coupling between unrelated behavior.
- Prefer composition over inheritance when it produces a clearer design.
- Use constructor or explicit dependency injection when it meaningfully improves separation or verification.
- Apply design principles and patterns pragmatically rather than mechanically.
- Avoid premature abstractions, unnecessary layers, and speculative flexibility.
- Remove duplication when it represents genuinely shared behavior.
- Tolerate small duplication when the proposed abstraction would make the code harder to understand.
- Keep likely changes localized behind clear ownership boundaries.

## Existing Projects

- Preserve released gameplay behavior unless an approved requirement changes it.
- Preserve mod IDs, registry names, saved-data formats, dependency identifiers, and configuration keys when compatibility requires them.
- Avoid unrelated rewrites while migrating build systems or implementing features.
- Keep existing worlds and configuration files compatible whenever reasonably possible.
- Never remove or silently change a released feature.
- Follow the existing architecture unless an approved architectural decision replaces it.

## Java

- Write code that remains valid for the project's approved Java runtime target.
- Do not use APIs newer than the approved runtime target.
- Use modern syntax only when `use_modern_java_syntax` is explicitly enabled.
- Prefer explicit, readable types when inference would obscure domain meaning.
- Handle nullable Minecraft and mod integration values defensively where absence is valid.
- Use concise comments only when intent, constraints, or non-obvious behavior cannot be expressed clearly through code.

## Loader Integration and Sidedness

- Keep authoritative gameplay behavior on the logical server unless the requirement is explicitly client-side.
- Never load `net.minecraft.client.*` classes from common or dedicated-server paths.
- Use sided initialization mechanisms only when they serve actual client-only or server-only responsibilities.
- Respect cancelable events and choose event priority deliberately when the selected loader provides those mechanisms.
- Avoid global event handlers that accumulate unrelated responsibilities.
- Use the appropriate tracked or synchronized Minecraft APIs for state observed by clients.
- Consider fake players, missing registry entries, modded entities, absent worlds, and null damage or action sources where relevant.
- Avoid retaining player, entity, world, chunk, or server references longer than their lifecycle permits.
- Evaluate interactions between enabled modules rather than testing features only in isolation.

## Configuration

- Give every user-facing option a clear description of its gameplay consequences.
- Prefer independent settings when separate systems may need separate behavior.
- Preserve released configuration keys and defaults unless an approved requirement changes them.
- Validate values only where required for correctness, compatibility, or server safety.
- Make restart requirements explicit when runtime objects snapshot configuration.
- Define allow-list, deny-list, precedence, and conflict behavior consistently.
- Do not silently repair invalid configuration in ways that conceal user mistakes.
- For silent, event-driven, or hard-to-observe behavior, prefer an approved disabled-by-default debug option that helps development validation without affecting normal gameplay.

## Dependencies

- Prefer established libraries when Feasibility Research shows that they fit the requirement and constraints.
- Declare required dependencies in development configuration and mod metadata.
- Declare optional dependencies without making them mandatory at class-loading time.
- Use the dependency mechanisms supplied by the configured template.
- Never bundle another mod into the release JAR unless explicitly required and legally permitted.
- Preserve required dependency versions and loading order where compatibility depends on them.
- Review transitive dependencies and exclude unnecessary ones deliberately.

## Errors and Logging

- Fail clearly when continuing would corrupt state or produce misleading behavior.
- Handle recoverable integration failures without crashing unrelated gameplay.
- Use the project's logging framework rather than standard output.
- Log information that helps identify the failing feature, input, entity, world, or dependency.
- Avoid repetitive logging in tick loops or other high-frequency paths.

## Performance

- Optimize based on evidence and stated requirements.
- Keep high-frequency event, tick, rendering, and AI paths small and allocation-conscious.
- Avoid repeated registry scans, world scans, reflection, or configuration parsing in hot paths.
- Cache data only when ownership, invalidation, and lifecycle are clear.
- Do not trade substantial clarity for unmeasured micro-optimizations.

## Verification

- Treat compilation as necessary but insufficient evidence of correctness.
- Use automated tests for isolated logic when they provide useful feedback.
- Do not require strict TDD for behavior that depends on the Minecraft runtime.
- Verify the selected loader lifecycle, rendering, world state, entity AI, networking, transformations or Mixins, and compatibility in an appropriate Minecraft environment.
- Check dedicated-server safety whenever shared or client-related code changes.
- Verify default and unusual but valid configuration combinations.
- Include focused manual scenarios for gameplay behavior that cannot be meaningfully automated.
