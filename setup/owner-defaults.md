# Owner Defaults

These defaults capture standing preferences for this workflow owner. They reduce repeated setup questions, but project-specific approved decisions still take precedence.

## Collaboration

- Commit messages are always repo-facing by default.
- Commit messages must not reference internal workflow stage IDs, issue IDs, process artifacts, or agent-only context unless the owner explicitly requests that style.
- After a clean committed checkpoint, end with a simple continuation cue such as `Ready to continue when you want.`
- When owner-assisted manual validation is useful, provide concise runnable validation recipes with config state, exact commands or setup steps, expected results, and important limitations.

## Release Ownership

Owner-managed by default:

- Icon
- Screenshots
- CurseForge upload
- Dedicated server testing
- Cleanroom testing
- External multiplayer testing

Ask only when the owner explicitly requests agent involvement or a one-time exception.

## Documentation

- Keep `README.md` repository-facing by default.
- Keep player/download-facing copy in a separate file such as `MOD-PAGE.md`.
- Assume repository README readers have basic source repository and Gradle/modding literacy.
- Shape mod page copy for download-page readers: concise, non-repetitive, clear about installation sides and meaningful limitations, and aligned with owner-provided introductory wording when supplied.

## Development Preferences

- For silent, event-driven, or hard-to-observe mods, consider a disabled-by-default debug option for development validation.
- Prefer `THIRD-PARTY-NOTICES.md` for retained template or upstream notices when the root `LICENSE` should identify the new project owner/license.
- Use dependency source checkouts only when they are necessary reference material or when the owner provides them.
