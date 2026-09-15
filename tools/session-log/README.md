# Session Log Tool

This dependency-free PowerShell tool reads Minecraft 1.12.2 Forge logs (`latest.log` and the rotated `*.log.gz` files) so the agent can answer a validation question from the evidence instead of scrolling a whole log by eye. It finds every game launch in the files, parses the Agent Diagnostics Toolkit records (`[DevToolkit][TYPE] key=value ...`) into fields, and slices the log between two marks, around one bundle run, or between two times.

The tool does not judge whether a card passed, assign evidence labels, or change anything on disk. It only reads. The rules for what a session must show live in `guidelines/manual-validation.md` and `stages/7-implementation.md`.

## Commands

From the workflow repository root on Windows:

```bat
tools\session-log\session-log.cmd launches -LogDirectory workspace\project\examplemod\run\logs
tools\session-log\session-log.cmd records -LogDirectory workspace\project\examplemod\run\logs -Type MARK,BUNDLE_END
tools\session-log\session-log.cmd timeline -LogDirectory workspace\project\examplemod\run\logs -From CARD_START -To CARD_END
tools\session-log\session-log.cmd timeline -LogDirectory workspace\project\examplemod\run\logs -Bundle fa_drop -Occurrence last
tools\session-log\session-log.cmd errors -LogDirectory workspace\project\examplemod\run\logs -Logger flasksadditions
tools\session-log\session-log.cmd find -LogDirectory workspace\project\examplemod\run\logs -Text "Registry Item: Found a missing id"
```

- `launches` lists every launch found: its side (client or server), file and line, first and last time, Forge version, mod count, how it ended, and the counts of entries, toolkit records, warnings, and errors, plus the mark labels and bundle names it contains.
- `records` prints the toolkit records of the selected launch. `-Type` takes a comma-separated list (`MARK`, `BUNDLE_START`, `BUNDLE_END`, `PLAYER_INSPECT`, `ERROR`, ...). `-Fields health,maxHealth` prints only those fields, one record per line.
- `timeline` prints every log entry in a slice of one launch, with stack-trace continuation lines attached. `-RecordsOnly` keeps only toolkit records.
- `errors` prints WARN, ERROR, and FATAL entries plus toolkit `ERROR` records, with a count per logger first. `-Level ERROR` narrows the levels.
- `find` prints every entry whose message or continuation lines contain `-Text` (case-insensitive) or match `-Pattern` (a .NET regular expression).

The launcher applies `ExecutionPolicy Bypass` only to that child process; it does not change machine policy.

## Which files

- `-Log <file>` reads one file, plain or `.gz`.
- `-LogDirectory <directory>` reads the newest `-Rotated` files (default 2) plus `latest.log`, oldest first. `-AllRotated` reads every rotated file. Without either option the tool looks for `run\logs` and then `logs` under the current directory.
- Files are read with shared access, so `latest.log` can be read while the game is running.

## Which launch

Every file starts a launch, and a launch also starts where the log names the FML tweak class (`FMLTweaker` is the client, `FMLServerTweaker` the dedicated server) or prints the Forge version line. `-Launch` selects `last` (the default for `records`, `timeline`, and `errors`), `all` (the default for `launches` and `find`), `first`, `client`, `server`, or a number from the `launches` list.

A shared `run/` directory has one known trap: the second process to start rotates `latest.log`, so the first process's launch loses its stop line and the tool says so (`no stop line`). Start the dedicated server first and wait for `Done` before the client, as Stage 7 says; the tool cannot separate two processes that wrote the same file at the same time.

## Slices

One boundary kind per call:

- `-From <label> [-To <label>]` uses `MARK` records by their `label` field. The slice runs from the chosen `From` mark to the first `To` mark after it, or to the end of the launch when no `To` follows (the scope line says which).
- `-Bundle <name>` runs from the bundle's `BUNDLE_START` record to its `BUNDLE_END`.
- `-FromTime HH:mm:ss -ToTime HH:mm:ss` compares the log timestamps as text, so it works within one day.

`-Occurrence` chooses which `From` mark or bundle start when the same label or bundle ran more than once: `last` (default), `first`, or a number.

## Filters

`-Level WARN,ERROR`, `-Logger <substring>`, `-Thread <substring>`, `-Text <substring>`, and `-Pattern <regex>` narrow any list. `-Type` narrows `records` and `timeline` to record types. `-Limit N` stops printing after N entries and says how many were left. `-Json` prints the same selection as JSON for further processing; a JSON entry carries `launch`, `file`, `line`, `time`, `thread`, `level`, `logger`, `message`, `continuation`, and, for toolkit records, `record.type` and `record.fields`.

## Reading the output

Every printed entry starts with `[file:line]` so a finding can be cited exactly. A development client prints thousands of `ERROR` lines from FML at world load (missing registry ids from other saves, entity loading of removed mods); narrow with `-Logger`, `-Pattern`, or `-Text` before reading `errors` on such a log.

## Tests

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\session-log\tests\run-tests.ps1
```

The tests build a log directory with two rotated `.gz` files and a `latest.log`, then verify launch detection across files, client and server sides, Forge version and mod count, marks and bundles per launch, record field parsing (quoted values included), mark and bundle slices with first and last occurrences, time slices, error collection with stack-trace continuation lines, text and pattern search, level and logger filters, single-file input, JSON output, and the batch launcher with PowerShell module autoload disabled.
