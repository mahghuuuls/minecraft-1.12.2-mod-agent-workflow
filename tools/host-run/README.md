# Host Run Tool

`host-run` starts one command outside the agent's own process tree, waits for it, prints what it wrote, and exits with the command's exit code. It exists so that an agent can run the mod's Gradle build and tests itself instead of asking the owner to run them and paste the output.

## Why

Inside some agent hosts, every child process inherits a restriction that breaks loopback networking for newer Java runtimes. Gradle then fails with `java.io.IOException: Unable to establish loopback connection`, and a plain `java.nio.channels.Pipe.open()` fails with `java.net.SocketException: Invalid argument: connect` on Java 21 and Java 25 (Java 8 is not affected). Turning the agent's sandbox off does not help, because the restriction belongs to the process tree, not to the sandbox.

A process started by the Windows Management Instrumentation service (`Win32_Process.Create`) or by the Task Scheduler is not a child of the agent host, so it does not inherit the restriction. The same Gradle build that fails from the agent shell succeeds there.

The tool is routed by `guidelines/coding-standards.md` (Running Builds And Tests) and by the environment inspection in `stages/0-project-setup.md`. Its presence does not require its use: when the build already works from the agent shell, run it there.

## Boundaries

- The tool writes only its own run folders under the operating-system temporary directory (or `MINECRAFT_MOD_AGENT_HOST_RUN_ROOT`). It never edits a repository, never runs Git, and never chooses the command for you.
- The command runs with the user's own account and the user's profile environment. It does not inherit the agent shell's variables; pass what the command needs with `-Set`.
- The command has no console to read from. Use it for commands that finish on their own, such as builds, tests, and checks.
- Every run has its own folder and, for the Task Scheduler launcher, its own task name. Several agents on the same computer can use the tool at the same time. Do not start two builds of the same repository at once; Gradle serializes them, and the second one waits.
- A timeout stops the whole command tree with `taskkill /T /F`. Choose `-TimeoutSeconds` above the longest expected build.

## Commands

From the workflow repository root on Windows:

```bat
tools\host-run\host-run.cmd probe
tools\host-run\host-run.cmd run -WorkingDirectory workspace\project\examplemod -Command "gradlew.bat clean build --console=plain" -TailLines 40
tools\host-run\host-run.cmd run -WorkingDirectory workspace\project\examplemod -Command "gradlew.bat test --console=plain" -TimeoutSeconds 900 -Label tests
tools\host-run\host-run.cmd run -WorkingDirectory workspace\project\examplemod -Command "gradlew.bat build --console=plain" -Set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot"
```

### probe

Starts `cmd.exe /d /c echo host-run probe ok` through the selected launcher and reports `probe OK` or `probe FAILED`. Use it once during Project Setup to learn whether the launcher works on the machine; it does not prove that the build works.

### run

| Option | Meaning |
| --- | --- |
| `-Command <text>` | The command line, run through `call` in a batch file. A batch file such as `gradlew.bat` needs no `cmd.exe /c` prefix. Required. |
| `-WorkingDirectory <path>` | Where the command runs. Default: the current directory. |
| `-TimeoutSeconds <n>` | Stop the command tree after this many seconds and exit 124. Default 1800. |
| `-Launcher wmi\|task` | `wmi` (default) uses `Win32_Process.Create`; `task` creates, runs, and removes a one-time scheduled task. Try `task` when `wmi` is refused. |
| `-Set NAME=value` | Environment variables for the command only. Repeat the option or give several values. |
| `-Label <text>` | A word for the run folder name, for example `release-build`. |
| `-TailLines <n>` | Print only the last `n` output lines. The output file keeps everything. |
| `-Quiet` | Print only the final exit line. |

The tool prints, prefixed with `host-run:`, the command, the working directory, the run folder, and the launcher with the process id, then the captured output, then one line `host-run: exit <code> after <n> s; output <path>`. Its own exit code is the command's exit code.

Exit codes of the tool itself: `124` timeout, `125` the launched process ended without writing an exit code, `2` the working directory could not be entered, `1` a usage error such as a malformed `-Set` value.

### Run folder

```text
%TEMP%\minecraft-1.12.2-mod-agent-host-run\<yyyyMMdd-HHmmss>-<label>-<6 hex>\
  command.cmd   the generated batch file (working directory, -Set lines, the call, the exit-code write)
  output.txt    stdout and stderr of the command, in the console code page
  exit.txt      the exit code
```

The folder stays after the run so that the output can be read again or copied into an evidence pack. Set `MINECRAFT_MOD_AGENT_HOST_RUN_ROOT` to keep run folders somewhere else.

## Quoting

The `.cmd` launcher passes its arguments through `cmd.exe`, which treats an unquoted `&`, `|`, `<`, or `>` as an operator. Commands with those characters, or with nested quotes, are safer through the script directly:

```powershell
powershell -NoLogo -NoProfile -ExecutionPolicy Bypass -File tools\host-run\host-run.ps1 run -WorkingDirectory workspace\project\examplemod -Command 'cmd.exe /d /c "gradlew.bat test & gradlew.bat jar"'
```

Or write the steps into a small batch file in the mod repository's ignored area and run that file.

## Recording the result

Project Setup records which launch path builds the project: direct from the agent shell, or through this tool. Every later build, test run, and release build uses the recorded path. When both paths fail, follow the environment-limitation rules in `guidelines/collaboration-guidelines.md` and record the owner's build responsibilities as before.

## Tests

```bat
powershell -NoProfile -ExecutionPolicy Bypass -File tools\host-run\tests\run-tests.ps1
```

The tests cover the probe, the run folder layout, exit-code and output pass-through from a batch file, `-Set`, `-TailLines`, the timeout kill, the Task Scheduler launcher and its cleanup, rejected input, and the batch launcher with module autoloading disabled.
