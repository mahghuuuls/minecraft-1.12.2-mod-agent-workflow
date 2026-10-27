# Useful Links

These are curated candidates, not universal project requirements. Stage 0 and Feasibility Research select only the loader, runtime, libraries, and distribution references applicable to the project.

Curated references for Minecraft 1.12.2 mod development.

Prefer version-specific and primary sources. These links are starting points for research, not substitutes for verifying behavior against the actual project and dependency versions.

## Development Diagnostics

- [Agent Diagnostics Toolkit](https://github.com/mahghuuuls/agent-test-toolkit)
  Optional Minecraft 1.12.2 Forge development mod for repeatable command-bundle setup and structured log evidence during owner-assisted tests. Follow `guidelines/agent-diagnostics-toolkit.md`; do not treat it as a shipping dependency.
- [Flare](https://www.curseforge.com/minecraft/mc-mods/flare) ([source](https://github.com/CleanroomMC/Flare))
  Sampling profiler for Minecraft 1.12.2 on Forge and Cleanroom, derived from spark; CPU call graph, memory, and server health. GPLv3, development only, never shipped. It answers where the game spends time when a performance budget is missed; a mod's own timing summary stays the measure a requirement defines. Profiles open in an online viewer, so profile data leaves the machine; the owner runs its in-game commands and shares the result. The BareBones Template (Cleanroom) instance already carries it.

## CraftTweaker

- [CraftTweaker 4.1.20 (1.12.2) integration notes](crafttweaker-1-12-notes.md)
  Verified facts for a mod that exposes a ZenScript surface: artifacts, mod-owned loaders and their events, parse-error scope, calls from scripts into the mod, overload and cast rules, item patterns, the shared development folder.

## Template Candidates

See [Minecraft 1.12.2 Template Candidates](template-candidates.md) for selection guidance.

- [CleanroomMC ForgeDevEnv](https://github.com/CleanroomMC/ForgeDevEnv)  
  Recommended general Forge/Cleanroom-compatible candidate.
- [CleanroomMC CleanroomModTemplate](https://github.com/CleanroomMC/CleanroomModTemplate)  
  Cleanroom-exclusive template candidate.
- [GregTechCEu Buildscripts](https://github.com/GregTechCEu/Buildscripts)  
  Advanced Forge buildsystem and starter candidate.
- [CleanroomMC TemplateDevEnvKt](https://github.com/CleanroomMC/TemplateDevEnvKt)  
  Kotlin-oriented Forge template candidate.

## Cleanroom

- [CleanroomMC Website](https://cleanroommc.com/)  
  Main CleanroomMC project website.

- [CleanroomMC Wiki](https://cleanroommc.com/wiki/)  
  Documentation covering Cleanroom, Forge development, Mixins, rendering, sidedness, and related tools.

- [CleanroomMC GitHub Organization](https://github.com/CleanroomMC)  
  Source repositories for CleanroomMC projects and libraries.

## Forge 1.12.2

- [Forge 1.12.x Documentation](https://docs.minecraftforge.net/en/1.12.x/)  
  Version-specific Forge documentation.

- [MinecraftForge GitHub](https://github.com/MinecraftForge/MinecraftForge)  
  Forge source code and development history.

## Build Environment

- [RetroFuturaGradle](https://github.com/GTNewHorizons/RetroFuturaGradle)  
  Gradle plugin used by the template.

- [Jabel](https://github.com/bsideup/jabel)  
  Optional modern Java syntax support while targeting Java 8 bytecode.

## Mixins

- [MixinBooter](https://github.com/CleanroomMC/MixinBooter)  
  Mixin support for Minecraft 1.12.2.

- [SpongePowered Mixin Wiki](https://github.com/SpongePowered/Mixin/wiki)  
  General Mixin concepts and documentation.

- [CleanroomMC Mixin Documentation](https://cleanroommc.com/wiki/forge-mod-development/mixin/preface)  
  Cleanroom-specific guidance for using Mixins in Forge 1.12.2.

## Dependencies and Tools

- [CurseMaven](https://cursemaven.com/)  
  Access CurseForge-hosted mods as Gradle dependencies.

- [MinecraftDev for RetroFuturaGradle](https://github.com/eigenraven/MinecraftDev/releases)  
  IntelliJ plugin fork recommended by ForgeDevEnv.

## CurseForge Presentation and Assets

- [Project Submission Guide and Tips](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips)
  - Current project logo, description, and presentation guidance
- [Moderation Policies](https://support.curseforge.com/support/solutions/articles/9000197279)
  - Current avatar, originality, copyright, and content requirements
