# Cleanroom Runtime Tool Instructions

This tool stages and supervises local Minecraft 1.12.2 Cleanroom tests. [Isolated Cleanroom Validation](../../procedures/isolated-cleanroom-validation.md) owns workflow routing and owner authorization. Read it and this directory's README before use.

- Use only the current project's approved binaries, profiles and test steps. Profile flags record an owner decision; setting a flag is not obtaining that decision.
- Keep profiles, copied binaries, configurations, worlds and evidence in ignored workspace paths. Do not commit machine-specific paths or Minecraft/dependency binaries here.
- Include every owner reference pack in `protectedRoots`. Treat source caches and source instances as read-only. Never point the runtime at a normal game instance.
- Prepare a new named runtime for a different binary/configuration profile. Do not bypass an inventory or hash failure by refreshing the runtime manifest from its current contents.
- Inspect the dependency set before launch with `tools/mod-jar`. Read generated configurations back and compare them with the selected Toolkit version's game-written layout.
- Tell the owner before an authorized graphical launch. Toolkit file requests do not authorize desktop-control APIs.
- Use bounded session plans and keep the outer `host-run` timeout above the session plus shutdown allowance. Never stop arbitrary Java processes or identify an owned process by PID alone.
- A stale `active.lock` after supervisor interruption requires inspecting its evidence and confirming no owned runtime remains. Do not automatically steal the lock or delete evidence. The tool intentionally has no force-unlock or recursive cleanup command.
- Read `result.json`, console logs, Toolkit outcomes and requested screenshots. Exit zero proves only the checks in the plan. A menu request being accepted does not establish a gameplay assertion, and a screenshot file needs visual inspection.
- Preserve failed attempts. Expected failures need a specific reason, and should check the underlying Toolkit result when assessing the criterion.
- For changes to this tool, run the Python tests and the relevant real runtime scenario. Fake-child tests establish transport and lifecycle behavior; they are not Minecraft compatibility evidence.
