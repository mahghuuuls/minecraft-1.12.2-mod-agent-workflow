# CraftTweaker 4.1.20 (Minecraft 1.12.2) Integration Notes

Facts verified while building a ZenScript surface for a Forge 1.12.2 mod (Setworks, 2026-10), against the CraftTweaker 4.1.20.716 API jar, the 4.1.20 source, and runtime launches. They save a day of trial and error; verify again when the CraftTweaker version differs.

## Build

- Artifacts on `https://maven.blamejared.com`: `CraftTweaker2:CraftTweaker2-MC1120-Main:1.12-4.1.20.716` (the mod jar; its POM pulls `CraftTweaker2-API` and `ZenScript` of the same version). `compileOnly` on the Main artifact compiles against all three. For the development runtime use `runtimeOnly rfg.deobf(...)` on the Main artifact behind a Gradle property, so the shipped jar never carries it.
- ZenScript annotations live in the ZenScript jar: `stanhebben.zenscript.annotations.ZenClass`, `ZenMethod`, `ZenGetter`, `ZenExpansion`, `Optional`. `crafttweaker.annotations.ZenRegister` marks a class for CraftTweaker's ASM scan; no `@ModOnly` is needed for the mod's own classes when the mod loads them only behind `Loader.isModLoaded("crafttweaker")`.

## Loaders

- `CraftTweakerAPI.tweaker.getOrCreateLoader("name")` creates a loader; a script joins it with `#loader name` as its first line. CraftTweaker's own loaders run `preinit` at pre-initialization and `crafttweaker` (alias `recipeevent`) between pre-init and init. A file tagged for another loader is skipped by those runs (`Skipping file ... as we are currently loading with a different loader` in `crafttweaker.log`).
- Run a mod-owned loader at load complete with `CraftTweakerAPI.tweaker.loadScript(false, loader)` or, to learn about parse errors, with the concrete `CrTTweaker.loadScript(boolean isSyntaxCommand, List<SingleError> parseErrors, boolean isLinter, String... loaderNames)`; `SingleError` has public `fileName`, `line`, `offset`, `explanation`, `level`.
- A parse error in one file makes CraftTweaker refuse to compile the loader's later files, but it still publishes `CrTScriptLoadingEvent.Pre` and `Post` for every file, including the failed one and the refused ones. Do not infer the scope from missing events; use the parse-error list plus the visit order from the Pre events.
- A compile error (`No such member ...`) and a runtime exception are per file; the later files still run.
- `CrTLoaderLoadingEvent.Aborted` is never published in 4.1.20.
- `/ct syntax` re-runs the loaders with execution blocked; there is no `/ct reload` in 1.12. A mod that queues script calls must apply them once (load complete) and drop later calls.
- File names in the events come with the OS separator for nested folders (`sub\file.zs` on Windows); normalize before comparing.

## Calls from scripts into the mod

- `CraftTweakerAPI.getScriptFileAndLine()` walks the stack for the running script frame and returns `file.zs:line`, or `<?>` when no script frame is on the stack. Capture it in the static entry method to attribute a definition to its script line.
- Two overloads of the same arity where one takes a functional interface or an array make ZenScript drop the predicted type for the function literal or array literal (`JavaMethod.predict` nulls it when candidates disagree); the call still resolves for a fully typed function, with a `Can cast this function to java.util.Map?` note at compile time, and an array literal of ingredients may fail. Give the function and array forms their own names.
- A ZenScript function literal compiles to a class implementing any single-abstract-method Java interface; calling it from Java is a direct interface call. Annotate the interface with `@ZenRegister @ZenClass("mods.x.IName")` so scripts can name the type.
- Script maps arrive as `Map<String, ?>`; copy values to strings yourself. `@Optional` on a primitive parameter gives `false` or `0`.
- `IEventHandler<T>` with a `@ZenClass` event type works for custom events: an `EventList<T>` per event, published from the mod, with an `@ZenExpansion("crafttweaker.events.IEventManager")` static method so `events.onMyEvent(function(e as mods.x.MyEvent) {...})` reads like the built-in ones. `EventList.publish` catches a throwing handler itself and logs it.

## ZenScript syntax facts

- An `IEntity` that is a player is assigned to an `IPlayer` after an `instanceof` check: `val p as IPlayer = entity;` compiles; `entity as IPlayer` does not (`Cannot cast ZenTypeNative: crafttweaker.entity.IEntity to ... IPlayer`). `IEntity.asIPlayer()` is not CraftTweaker; it comes from Mah Zen Utils.
- `print(...)` writes to `crafttweaker.log` only, not to the game log.

## Item patterns

- `IItemStack.getDamage()` is the raw damage value and keeps the wildcard (`OreDictionary.WILDCARD_VALUE`); `getMetadata()` maps it through the item and returns 0 for items that do not override it.
- `IItemStack.getTag()` returns an empty `IData`, never null, for a stack without a tag; `CraftTweakerMC.getNBTCompound(data)` converts it.
- `IngredientOr` (`<a> | <b>`) exposes only `getItems()`, which expands ore entries to the items present when the script runs; `IngredientItem` carries conditions and transformers, `IngredientStack` an amount, `IngredientAny` is `<*>`.

## Development folder

- `runClient` and `runServer` of ForgeDevEnv share one `run` folder, so a client started after the server truncates `crafttweaker.log` and both write `logs/latest.log`. Server evidence comes from the console capture; a `print` line from a server-side script survives only if the client was started first.
