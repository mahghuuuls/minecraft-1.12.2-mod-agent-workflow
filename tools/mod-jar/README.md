# Mod Jar Tool

This dependency-free PowerShell tool reads Minecraft 1.12.2 Forge mod jars without starting the game. It answers the two questions that cost launches during the first workflow: "will this set of jars load together?" and "what is the real id of that other mod's item?"

It reads `mcmod.info`, the jar manifest, the `@Mod` annotation inside the class files (where most mods declare their dependencies), and the ids named by the jar's own recipes, advancements, blockstates, language keys, and item models. It writes nothing.

## Commands

From the workflow repository root on Windows:

```bat
tools\mod-jar\mod-jar.cmd info workspace\project\examplemod\build\libs\examplemod-1.0.0.jar
tools\mod-jar\mod-jar.cmd items workspace\project\examplemod\build\libs\examplemod-1.0.0.jar -Source recipe,lang
tools\mod-jar\mod-jar.cmd find -Text skyroot path\to\aether-1.12.2-v1.5.4.1.jar
tools\mod-jar\mod-jar.cmd check -Folder workspace\project\examplemod\run\mods -Provided mixinbooter,jawms
```

Jars are named after the action; `-Folder <directory>` adds every `*.jar` in a directory (`-JarFilter <substring>` narrows it by file name). The launcher applies `ExecutionPolicy Bypass` only to that child process; it does not change machine policy.

### info

Prints, per jar: size and SHA-256; every `mcmod.info` entry (both the plain list and the `modListVersion` 2 shape) with its `requiredMods`, `dependencies`, `dependants`, and `useDependencyInformation`; the manifest attributes that mark a coremod, tweaker, mixin, or access-transformer jar; every `@Mod` annotation with its class, id, name, version, and dependency string; the asset domains and resource counts.

Name, version, and dependencies are combined the way FML 1.12.2 combines them, and each value says where it came from:

- A mod exists where a class carries `@Mod`. An `mcmod.info` entry without such a class is listed with a note; FML does not load it.
- The version is the annotation's `version`, or the `mcmod.info` version when the annotation leaves it empty.
- The dependency list comes from `mcmod.info` only when the annotation sets `useMetadata` and the file sets `useDependencyInformation`; otherwise it is the annotation's `dependencies` string, which is what most mods use. `mcmod.info` alone is therefore not enough for a dependency check, which is why the tool reads the classes.

`-SkipClasses` skips the class scan for speed; the output then says that the `@Mod` data is unknown.

### items

Lists the ids the jar's own resources name, each labeled by source. The label says how much the id can be trusted:

| Source | Read from | Meaning |
| --- | --- | --- |
| `recipe` | an `item` field in a recipe JSON, with its `data` value | a registry name the game resolves when the recipe loads |
| `advancement` | an `item` field in an advancement JSON | a registry name |
| `recipe-ore` | an `ore` field in a recipe JSON | an ore-dictionary name |
| `blockstate` | a `blockstates/<name>.json` file name | usually the block registry name |
| `lang` | an `item.*.name`, `tile.*.name`, or `entity.*.name` key with its display text | an unlocalized name, often but not always the registry name |
| `model` | a `models/item/<name>.json` file name | an asset name only; a variant model is named after the variant, not the registry name |

`-Source recipe,lang` limits the sources. An id without a namespace in a recipe is reported under `minecraft:`.

### find

Searches the ids, display names, and resource paths of one or more jars for `-Text` (case-insensitive substring) and prints every hit with its source label and jar. This is the check `guidelines/coding-standards.md` asks for before a recipe names another mod's item: a `recipe` hit with a `data` value is the id and metadata the other mod itself uses; a `model` hit alone is a warning that the name is an asset name.

The Aether Legacy case that produced the Skyroot Gourd defect looks like this:

```text
find -Text skyroot_log ...   ->  lang: skyroot_log 'Skyroot Log'   model: aether_legacy:skyroot_log
find -Text aether_log ...    ->  recipe: aether_legacy:aether_log data 0   blockstate: aether_legacy:aether_log
```

Across a `-Folder`, `find` reads file names and language keys only, because parsing every recipe JSON in a large modpack is slow; add `-IncludeRecipes` to read recipe and advancement JSON across the folder, or name the one jar you need.

### check

Reads every jar in a mods folder and reports whether the set can load:

- `DUPLICATE`: one mod id provided by two jars, or by a jar and the environment (`-Provided`). FML refuses to start with a duplicate.
- `MISSING`: a `required-after`, `required-before`, or `mcmod.info requiredMods` target that no jar, built-in id (`minecraft`, `forge`, `fml`, `mcp`), or `-Provided` id supplies.
- `VERSION`: a present mod whose version is outside the required range. The comparison is basic (numeric segments as numbers, other segments as text, a trailing qualifier sorts before the plain version), so read the versions when a range is unusual.

Notes list jars without a mod id (libraries, coremod-only jars), coremod, tweaker, or mixin jars (a development runtime that already has the same mod on its Gradle classpath refuses the copy as a duplicate), unreadable `mcmod.info` files, unknown dependency instructions, and optional-dependency version mismatches.

`-Provided <ids>` names mods that the environment supplies without a jar in the folder, such as a mixin loader on the development classpath or the mods of the base instance. The result line says `OK` or the number of problems; `-Strict` turns problems into a failing exit code for scripts, and `-Json` prints the report as data.

A folder of a few hundred jars takes minutes because every class is scanned for `@Mod`; use `-JarFilter` or `-SkipClasses` when a full scan is not needed.

## Boundaries

- The tool reads declared metadata. It does not know about dependencies a mod checks at runtime in code, `@Optional` interfaces, or version constraints enforced only by a coremod.
- A `recipe` hit proves the other mod names that id in its own resources; it does not prove the item exists in a different version of that mod.
- `mcmod.info` files with trailing commas are repaired before parsing; other broken files are reported as unparseable and the `@Mod` data is used, as FML would.

## Tests

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\mod-jar\tests\run-tests.ps1
```

The tests build fixture jars with hand-assembled class files that carry `@Mod` annotations (including decoy annotations with enum, array, nested-annotation, class, and integer elements the parser must skip), both `mcmod.info` shapes, a coremod manifest, and an unparseable `mcmod.info`. They verify metadata combination, dependency-source selection, item listing by source with `data` values, folder and single-jar `find`, the duplicate, missing, and version checks with and without `-Provided`, `-Strict`, JSON output, and the batch launcher with PowerShell module autoload disabled.
