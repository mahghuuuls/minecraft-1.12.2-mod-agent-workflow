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

## Complexity Management

Judge design by the amount of knowledge and coordination required to understand or change it, not by class count, pattern count, or whether the code currently works.

- Prefer deep modules: a small, clear interface should hide substantially more implementation detail than it exposes. Do not split behavior into many shallow classes or methods merely to make each unit shorter.
- Make common operations simple for callers. Rare options, lifecycle details, compatibility branches, and special cases should not burden the normal call path unless callers genuinely need to control them.
- Give each nontrivial design decision one authoritative owner. A formula, precedence rule, serialization shape, synchronization rule, registry mapping, or compatibility policy duplicated across modules is information leakage even when the duplicated code is short.
- Organize code around ownership of knowledge, not merely the order in which lifecycle steps happen. Contain required temporal ordering behind an interface instead of making distant callers remember sequences such as initialize, mutate, synchronize, and clean up.
- Require adjacent layers to provide different abstractions. A wrapper or method that mainly forwards the same arguments to another layer is a red flag unless it enforces a meaningful boundary such as sidedness, authorization, compatibility, lifecycle, or error translation.
- Pull unavoidable complexity into the module best able to hide it when doing so simplifies multiple callers. Do not use this principle to create a global manager, oversized class, or configuration surface that accumulates unrelated responsibilities.
- Keep general mechanisms separate from mod-specific policy when they change for different reasons. Keep behavior together when separating it would duplicate knowledge or force callers to coordinate the pieces.
- Define safe special cases out of existence when one consistent behavior is clearer, such as an idempotent no-op. Do not mask invalid configuration, corrupted state, security failures, or a condition the user must correct.
- For a new public API, persistent-state boundary, synchronization contract, cross-mod integration, or other complexity-bearing component, sketch at least two meaningfully different designs before selecting one. Compare interface size, knowledge exposed, common use, likely changes, failure behavior, and Minecraft lifecycle constraints. Trivial private implementation choices do not require this exercise.
- Use precise, consistent names. Difficulty naming or briefly describing a class, method, state value, or component is evidence that its responsibility or abstraction may be unclear; reconsider the design before compensating with a vague name and a long explanation.
- Comments should state contracts, invariants, ownership, reasons, and non-obvious constraints. Do not repeat the code or expose implementation details in an interface comment when callers do not need them.
- Make continual small design improvements within the touched scope. Do not patch around a newly exposed design defect merely to finish the issue; when the proper correction would materially expand scope or change approved architecture, stop and route that decision through the owning stage.

Use these as diagnostic principles, not a scoring system. A Forge or Minecraft constraint may justify a shallow adapter, temporal hook, or exposed option, but the implementation and review must name the constraint and show why the complexity is contained.

Common red flags include shallow modules, duplicated design knowledge, pass-through layers, temporal coupling across components, overexposed interfaces, repeated special-case handling, mixed general and special-purpose policy, methods that must be understood together, vague names, comments that repeat code, and behavior that is difficult to describe succinctly.

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
- Do not reference workflow issue IDs, internal issue names, stage documents, or process-only context in source comments, and do not cite them as the justification for a decision. Explain the reason itself instead. A comment must stand for a reader who has the repository but not the workflow artifacts, which is the same standard commit messages are held to in `guidelines/project-defaults.md`.

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
- Keep generated configuration comments focused on what a user needs to write a valid value: the purpose or format, one useful example, essential value bounds or safety constraints, and restart behavior when applicable. Put duplicate precedence, parser edge cases, diagnostic policy, and other detailed semantics in repository/player documentation or actionable warnings unless users need them at the edit point. Do not make the generated file duplicate the full configuration specification.

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
- Add detailed diagnostic logging only when it materially improves verification or support without disproportionate complexity, privacy risk, log volume, or performance cost.
- Keep optional detailed diagnostics disabled by default, bounded or rate-limited, and sanitized of credentials, private chat, or unrelated player data.
- Emit diagnostics at meaningful lifecycle or state-transition boundaries instead of tick, render-frame, or similarly high-frequency boundaries.
- Design diagnostic events so they can be corroborated with independent inputs, outputs, tests, or visible behavior; a component reporting its own computed result is not sufficient proof by itself.

## Performance

- Optimize based on evidence and stated requirements.
- Keep high-frequency event, tick, rendering, and AI paths small and allocation-conscious.
- Avoid repeated registry scans, world scans, reflection, or configuration parsing in hot paths.
- Cache data only when ownership, invalidation, and lifecycle are clear.
- Do not trade substantial clarity for unmeasured micro-optimizations.

## Verification

- Treat compilation as necessary but insufficient evidence of correctness.
- Use automated tests for isolated logic when they provide useful feedback.
- A test must be able to fail. Before claiming a test covers a behavior, name the specific change to the implementation that would make it fail. When no such change can be named, the test does not cover that behavior regardless of how it reads.
- Apply the same standard to manual checks. A check whose passing observation would look identical if the feature were absent proves nothing. Establish the distinguishing condition first, then observe.
- Treat a fixture too small to reach the rule under test as an unreached test, not a passing one. Verify that the data actually exercises the boundary the assertion describes.
- Cover shipped defaults explicitly. Values a user never edits are still values the mod depends on, and they are easy to leave untested because no test names them.
- When correcting a reproduced defect, add a durable regression check at the lowest stable level capable of detecting it. Prefer an automated unit or integration test when the behavior can be isolated meaningfully; otherwise retain a focused runtime scenario, diagnostic-toolkit bundle, or manual validation card.
- When practical and safe, demonstrate that the regression check fails before the correction and passes afterward. If the correction already exists when the check is written, demonstrate sensitivity through a controlled reversal or mutation of the relevant condition when practical. Otherwise explain why that demonstration would be unsafe or disproportionate and identify the independent evidence showing that the check reaches the original defect boundary.
- Do not require strict TDD for behavior that depends on the Minecraft runtime.
- Verify the selected loader lifecycle, rendering, world state, entity AI, networking, transformations or Mixins, and compatibility in an appropriate Minecraft environment.
- Check dedicated-server safety whenever shared or client-related code changes.
- Verify default and unusual but valid configuration combinations.
- Include focused manual scenarios for gameplay behavior that cannot be meaningfully automated.
