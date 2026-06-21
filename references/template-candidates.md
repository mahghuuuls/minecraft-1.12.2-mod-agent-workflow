# Minecraft 1.12.2 Template Candidates

This file provides a maintained shortlist for Project Setup. It is not a substitute for inspecting the current repositories.

Before recommending a template, the agent must verify its current default branch, license, build files, Java requirements, output compatibility, maintenance state, and publication automation. Record the exact repository, requested ref, and resolved commit used by the project.

## Selection Summary

| Candidate | Recommended Use | Default Position |
| --- | --- | --- |
| [CleanroomMC/ForgeDevEnv](https://github.com/CleanroomMC/ForgeDevEnv) | General Forge development with broad Forge/Cleanroom compatibility | Recommended default |
| [CleanroomMC/CleanroomModTemplate](https://github.com/CleanroomMC/CleanroomModTemplate) | Cleanroom-exclusive mods using the Cleanroom toolchain or APIs | Specialized alternative |
| [GregTechCEu/Buildscripts](https://github.com/GregTechCEu/Buildscripts) | Advanced, highly automated Forge projects | Advanced alternative |
| [CleanroomMC/TemplateDevEnvKt](https://github.com/CleanroomMC/TemplateDevEnvKt) | Kotlin-oriented Forge projects | Language-specific alternative |
| Official Forge 1.12.2 MDK | Minimal legacy Forge baseline or migration reference | Legacy fallback |

Do not recommend a template solely because it appears in this file. Requirements and current evidence decide.

## ForgeDevEnv

Use as the provisional default when the mod should:

- Run on standard Forge
- Also remain compatible with Cleanroom where feasible
- Target Java 8 bytecode for broad compatibility
- Use a modern Java development environment
- Need optional Mixins, coremods, access transformers, tests, shadowing, or publishing configuration

Current characteristics to verify:

- Forge-oriented output
- RetroFuturaGradle build
- Modern Gradle/JDK development environment
- Java 8 output by default
- Optional modern syntax through Jabel while retaining the configured target
- Mixin, coremod, access-transformer, test, dependency, and publishing support
- MIT license

ForgeDevEnv is normally the most versatile choice because a conventional Forge mod has the broadest 1.12.2 runtime reach and Cleanroom is designed to run most Forge mods.

Initialization must disable or leave disabled any publishing automation.

## CleanroomModTemplate

Use when the mod intentionally:

- Requires Cleanroom Loader APIs or behavior
- Uses modern Java bytecode unavailable to standard Java 8 Forge users
- Is explicitly allowed to be Cleanroom-only
- Needs the template's Cleanroom-native Unimined workflow
- Benefits from its Mixin, Kotlin, or Scala branches

Current characteristics to verify:

- Cleanroom Loader configuration
- Custom Unimined fork and its documented warning
- Java 25 toolchain and bytecode target
- Cleanroom-specific manifest metadata
- Main, Mixin, Kotlin, and Scala branch choices
- Included build and release workflows
- MIT license

Do not recommend this template merely because the user wants Cleanroom compatibility. Use it when Cleanroom exclusivity or Cleanroom-native capabilities are an approved requirement.

## GregTechCEu Buildscripts

Consider for projects that explicitly want a feature-rich managed build system.

Current characteristics to verify:

- Starter and migration archives rather than a simple repository copy
- RetroFuturaGradle
- Jabel-based modern syntax with Java 8 targeting
- Mixins, coremods, access transformers, tests, Spotless, shadowing, Kotlin, and Scala support
- Automated buildscript updates
- CurseForge, Modrinth, Maven, changelog, and release automation
- MIT license

This option is powerful but more opinionated and operationally complex. Stage 0 should explain its update behavior and automation before recommending it. Initialization must disable automatic publication and must not enable self-updating behavior without approval.

## TemplateDevEnvKt

Consider only when Kotlin is an intentional project requirement.

Verify its current Gradle, RetroFuturaGradle, Forge, Kotlin, Java target, dependency-bundling, and maintenance state. Compare it with using Kotlin through another approved build system before selection.

## Legacy and Experimental Options

The official Forge MDK and older ForgeGradle 2.3 templates can be useful for migration or reproducing an existing environment. They are not preferred for new projects when maintained modern tooling satisfies the requirements.

Do not normally recommend:

- Archived templates
- Templates without a clear reuse license
- Small experimental templates without meaningful maintenance evidence
- MCreator generators as general source templates
- Multi-version or multi-project templates for a single 1.12.2 mod without a demonstrated need
- A claimed Fabric or multiloader option without evidence that it supports Minecraft 1.12.2 specifically

## Stage 0 Decision Rules

Ask in this order:

1. Must the artifact run on standard Forge?
2. Must it also run on Cleanroom?
3. May it be Cleanroom-exclusive?
4. Is Java, Kotlin, or Scala required?
5. Are Mixins, coremods, access transformers, shadowing, or advanced automation expected?
6. Is a minimal or feature-rich build preferred?

Then:

- Recommend ForgeDevEnv by default for standard Forge or Forge-plus-Cleanroom compatibility.
- Recommend CleanroomModTemplate only for an approved Cleanroom-exclusive requirement.
- Present GregTechCEu Buildscripts when advanced build automation justifies its complexity.
- Present TemplateDevEnvKt only for a deliberate Kotlin choice.
- Research other candidates when none of these satisfy the approved constraints.

The recommendation is provisional until Feasibility Research confirms it.
