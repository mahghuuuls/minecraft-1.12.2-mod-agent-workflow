# Devtool Inbox Tool

This dependency-free PowerShell tool sends requests to the command inbox of the Agent Diagnostics Toolkit (`1.3.0` or later) and waits for the answers, so the agent can start its own bundles during a validation session without the owner typing them. It follows the toolkit's file protocol: it checks `status.json`, writes `<id>.tmp`, renames it to `<id>.req`, waits for `<id>.result.json`, and never reuses an id.

The tool does not open the inbox, judge whether a card passed, or change anything but the request files it writes. Only a person can open the inbox, by typing `/devtool inbox open` in game. When and how the workflow uses the inbox is owned by `guidelines/agent-diagnostics-toolkit.md` (Command Inbox); the request lines, result fields and refusal reasons are owned by the pinned toolkit's `AGENTS.md`.

## Commands

From the workflow repository root on Windows:

```bat
tools\devtool-inbox\devtool-inbox.cmd status -Inbox workspace\project\examplemod\run\config\devtool\inbox
tools\devtool-inbox\devtool-inbox.cmd send -Inbox workspace\project\examplemod\run\config\devtool\inbox -Request "run card3_setup" -Prefix c3
tools\devtool-inbox\devtool-inbox.cmd batch -Inbox workspace\project\examplemod\run\config\devtool\inbox -File workspace\validation\staging\campaign-a\regression.txt -Prefix ra
tools\devtool-inbox\devtool-inbox.cmd results -Inbox workspace\project\examplemod\run\config\devtool\inbox -Prefix ra
```

- `status` prints `open operator=<name> world=<save> openedWorldTick=<tick>`, or `closed` when there is no `status.json`.
- `send` sends one request line (`-Request`) and prints the answer on one line: the id, the request, and the result's `outcome`, `reason`, `bundle`, counters, `senderLost`, `firstFailure` and `detail` when present. `-Id` sets the id; otherwise one is generated from `-Prefix` (default `req`), the time and a counter, skipping any id that already has a file in the folder. `-NoWait` writes the request and returns at once, for a run that waits on the owner, such as a checkpoint.
- `batch` sends the lines of `-File` one at a time, each with a new id, and compares every answer with its expectation. A line may end with `=> key=value ...` naming fields of the result file, for example `run v9_suite_fast => outcome=failed executed=21 failed=1`; a line without one expects `outcome=done`. Blank lines and lines starting with `#` are skipped. The batch stops at the first answer that differs, unless `-ContinueOnMismatch`, and ends with `batch: <sent> of <lines> sent, <n> as expected`.
- `results` prints every result file in the folder in the same one-line form, sorted by id; `-Prefix` narrows it.

`-Json` prints the same answers as JSON, one object per request: `id`, `request`, `state` (`answered`, `sent`, `closed` or `timeout`) and the toolkit's `result`.

Without `-Inbox` the tool looks for `run\config\devtool\inbox` and then `config\devtool\inbox` under the current directory. The launcher applies `ExecutionPolicy Bypass` only to that child process; it does not change machine policy.

## Exit codes

| Code | Meaning |
| --- | --- |
| 0 | `done`, or every batch line as expected, or the request was written with `-NoWait` |
| 1 | `failed`, such as `bundleFailed`, `senderLost`, `serverStopped` or `commandFailed` |
| 2 | `refused`, such as `verbNotAllowed` or `badArguments` |
| 3 | The inbox is closed: no `status.json` before sending, or it disappeared before the request was claimed |
| 4 | No result file within `-TimeoutSeconds` (default 120) |
| 5 | A usage or input problem: no inbox folder, an invalid or used id, a request that is not one line of printable ASCII up to 512 characters |
| 6 | A batch line's answer differs from its expectation |

## Waiting

A `run` is answered when its bundle ends, so set `-TimeoutSeconds` above the bundle's longest wait. A request still unclaimed when `status.json` disappears is never read, so the wait ends after `-ClosedGraceSeconds` (default 5) with exit 3: ask the owner to open the inbox again and send it with a new id. A request already claimed is still answered when the operator leaves or the server stops (`senderLost`, `serverStopped`), so that wait continues. In single player a paused game reads nothing; a timeout there usually means a menu is open.

`-SkipStatusCheck` sends without checking `status.json`. Use it only to exercise the toolkit's own handling of a request placed before the inbox opened: the toolkit refuses every such request with `placedBeforeOpen` when the inbox opens, and answers each.

## Tests

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\devtool-inbox\tests\run-tests.ps1
```

The tests run the tool against a fake toolkit that claims and answers requests the way the toolkit does. They verify `status` open and closed, that nothing is written to a closed inbox, the `done`, `failed` and `refused` answers with their exit codes and fields, JSON output, that no `.tmp` or `.req` file is left behind, unique generated ids and the refusal of a used or invalid id, the refusal of over-long and non-ASCII requests, the timeout, an inbox closing before the claim, a claimed run still answered after the operator leaves, batch expectations with a stop at the first mismatch and with `-ContinueOnMismatch`, `results` by prefix, the default folder, and the batch launcher.
