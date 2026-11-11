# Instance Reset Tool

This dependency-free PowerShell tool borrows and returns a shared Minecraft 1.12.2 test instance (the agent-managed test instance in `guidelines/project-defaults.md`). It takes the baseline snapshot, takes the lock, and later puts back what it compares (the `mods` jars, every `config` file and folder, `options.txt`, `knownkeys.txt`, the worlds, the files of the `screenshots` and `scripts` folders, and the top-level entries) from a plan that is printed and reviewed before anything is deleted. It replaces the hand-written comparisons and deletions that went wrong in earlier campaigns (a removal refused for a computed path, a file left behind).

The rules it carries out are owned by [Shared Test Instance Preparation](../../guidelines/project-defaults.md#shared-test-instance-preparation), [Test Instance](../../guidelines/project-defaults.md#test-instance) and [Shared Machine](../../guidelines/project-defaults.md#shared-machine). The tool does not decide what is staged into the instance or what the lock note says; the session writes the note.

## Commands

From the workflow repository root on Windows:

```bat
tools\instance-reset\instance-reset.cmd snapshot -Instance "C:\path\to\Instances\CleanroomTestBench" -Staging workspace\validation\staging\campaign-x -BaselineMods baseline-mods.txt
tools\instance-reset\instance-reset.cmd lock -Instance "C:\path\to\Instances\CleanroomTestBench" -Staging workspace\validation\staging\campaign-x -Note workspace\validation\staging\campaign-x\lock-note.txt
tools\instance-reset\instance-reset.cmd plan -Instance "C:\path\to\Instances\CleanroomTestBench" -Staging workspace\validation\staging\campaign-x -ScreenshotsCopiedTo workspace\validation\staging\campaign-x\screenshots
tools\instance-reset\instance-reset.cmd apply -Instance "C:\path\to\Instances\CleanroomTestBench" -Staging workspace\validation\staging\campaign-x -Plan workspace\validation\staging\campaign-x\reset-plan.json
```

Exit codes: 0 done; 1 the plan has problems, or PowerShell rejected an argument; 2 refused (a lock, a running game, a changed instance, a stale plan, a bad path).

### snapshot

Refuses when `mods\.agent-lock` exists (it prints the note) or a Java process of this instance runs (its command line names the instance folder; when the process list cannot be read, it refuses too). It needs `-BaselineMods <file>`, the expected `mods` list with one `file-name size` per line as the owner defaults record it, and refuses on any missing, extra, or resized jar; `-NoBaseline` skips that check on purpose and the snapshot says so. It then writes `<Staging>\instance-snapshot\`: a copy of `config`, `options.txt`, `knownkeys.txt` and the launcher files, and `snapshot.json` with the top-level listing, every world with the hash of its `level.dat`, every `mods` entry and every `config` file (hashed from the copy) and folder, and the files of the watched folders (`screenshots`, `scripts`) that exist. A staging folder takes one snapshot; a new session uses a new folder. The staging folder must be outside the instance.

### lock

Refuses when a lock note exists, no snapshot exists in the staging folder, or a game runs. Otherwise it creates `mods\.agent-lock` with an exclusive create, writes the given note into it, keeps a copy as `<Staging>\agent-lock.txt`, and then compares the instance with the snapshot; when anything differs (someone changed it before the lock was in place), or an error stops the comparison, it removes the lock again and refuses. `lock -Update -Note <file>` replaces this session's own note and its copy after the session adds files, as Shared Machine asks; it refuses when the note in the instance is not this session's.

### plan

Compares the instance with the snapshot and writes `<Staging>\reset-plan.json` (or `-Plan <file>`), printing one line per action. Each action records what it found at its target (a file's size and hash, a folder's file list), so a later change is seen.

- **delete**: a jar added to `mods`; a file new under `config`; a new world in `saves`; a new file in a watched folder that existed; a new top-level entry (a `screenshots` or `scripts` folder, `patchouli_data.json`, `patchouli_books`).
- **delete-empty-folder**: a folder new under `config`, removed only after its files and only when empty, never as a whole (another project's tools may write into `config\devtool`).
- **restore** from the snapshot: a `config` file that changed or was deleted (Cleanroom load timings, StellarCore caches the game renamed, `splash.properties`, the toolkit's `devtool.cfg` and inbox `status.json`); `options.txt`; `knownkeys.txt`. **make-folder**: a `config` folder the game removed.
- **note**: a launcher file that changed or appeared (`minecraftinstance.json`, `usercache.json` and the other report-only files), never deleted or restored, to be reported; a world that existed and was opened (not restored); a top-level entry that disappeared.
- **PROBLEM** (exit 1): the lock note is not this session's (another session may hold the instance) or is gone; a baseline jar missing or changed (the tool keeps no jars); a new folder in `mods`; a missing world; a changed or missing file in a watched folder; screenshots the plan deletes without a copy (by hash) in the `-ScreenshotsCopiedTo` folder, which must be outside the instance; any path outside what the tool may change.

`logs`, `crash-reports`, `mods\1.12.2` (the launcher's library folder) and the lock note are never in a plan. `-Keep <name,name>` leaves other new top-level entries in place. Read the plan against the lock note before `apply`: a deletion the note does not explain is a foreign file under Shared Machine.

### apply

Takes the reviewed plan. It recomputes the plan with the reviewed plan's own `-Keep` and `-ScreenshotsCopiedTo`, and refuses when the plan was made for another instance or staging folder, when anything differs from what was reviewed (an action, a file's content, a folder's files), when the plan has problems, when a game runs, or when the lock note changed. It then deletes and restores; when an action fails (a file in use), it stops, prints what it had done, keeps the lock, and exits 2. Afterwards it recomputes again and must find nothing left. It removes the lock note last when it still equals this session's copy (`-KeepLock` leaves it), renames the copy to `agent-lock-released.txt`, and writes `<Staging>\reset-check.txt`.

## Limits

- Jars are not copied into the snapshot; a baseline jar that was removed or replaced is reported for the owner or the agent to restore by hand. Worlds and the files of watched folders are not copied either; an empty subfolder a session leaves inside a watched folder is not seen. `resourcepacks` and `shaderpacks` are compared by name only, because hashing large packs on every step is slow.
- Reset exemptions in `owner-defaults.md` can keep top-level entries (`-Keep`); a `config` file cannot be exempted.
- The running-game check reads Java command lines through CIM. A game that does not name its folder on the command line, or one started elevated while the tool runs unelevated, is not seen; the session still checks by hand as Shared Machine says.
- Windows only (Windows PowerShell 5.1 or later).

## Tests

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File tools\instance-reset\tests\run-tests.ps1
```

The tests build a fake instance in a temporary folder and check: the baseline requirement and check, the snapshot with accented file names, a second snapshot, a staging folder inside the instance, and a snapshot under someone's lock being refused; a lock before the snapshot leaving no note, the lock, its copy, `-Update`, and a second lock being refused; a plan over a full session's changes (an added jar, new, changed and deleted config files and folders, `options.txt`, a new world, an opened old world, a new file in an existing `screenshots` folder, new top-level entries, a copy folder inside the instance refused, logs, crash reports, `-Keep` entries and launcher files left alone); apply refusing a planned file whose content changed, a planned folder that gained a file, and a foreign lock note; the apply, the state after it, the lock removed last, the reset check, and an empty plan afterwards; a missing or changed baseline jar, a lock over a changed instance released again, `-KeepLock`, a plan from another staging folder, an instance without `config`, a missing instance folder, and a drive root.
