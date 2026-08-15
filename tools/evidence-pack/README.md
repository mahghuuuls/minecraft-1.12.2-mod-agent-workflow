# Evidence Pack Tool

This dependency-free PowerShell tool captures a mechanically consistent evidence checkpoint for a Minecraft 1.12.2 mod project. It ties explicitly selected files, JUnit totals, JAR inventory, and SHA-256 identities to one Git commit and tree.

The tool does not decide whether an acceptance criterion passed, assign `observed` / `inspected` / `inferred` labels, interpret logs, update issue status, or replace independent review. Those responsibilities remain in `stages/7-implementation.md`.

## Commands

From the workflow repository root on Windows:

```bat
tools\evidence-pack\evidence-pack.cmd capture -Spec workspace\validation\specs\IMP-014-final.json
tools\evidence-pack\evidence-pack.cmd verify -Manifest workspace\validation\implementation\IMP-014\final-abc123\manifest.json
tools\evidence-pack\evidence-pack.cmd inspect -Manifest workspace\validation\implementation\IMP-014\final-abc123\manifest.json
```

- `capture` creates a new immutable pack. It refuses to overwrite an existing destination.
- `verify` checks the manifest hash, every retained file identity, JUnit totals, JAR inventory, and unexpected files.
- `inspect` prints the checkpoint's source and aggregate identities without interpreting them.

The launcher applies `ExecutionPolicy Bypass` only to that child process; it does not change machine policy.

## Specification

```json
{
  "schemaVersion": 1,
  "checkpoint": "IMP-014-final",
  "baseDirectory": "../../..",
  "sourceRepository": "workspace/project/examplemod",
  "outputDirectory": "workspace/validation/implementation/IMP-014/final-abc123",
  "requireClean": true,
  "junit": [
    {
      "name": "unit",
      "sourceDirectory": "workspace/project/examplemod/build/test-results/test",
      "pattern": "*.xml"
    }
  ],
  "files": [
    {
      "path": "workspace/project/examplemod/build/libs/examplemod.jar",
      "destination": "artifacts/examplemod.jar",
      "role": "built-mod",
      "inspectJar": true,
      "forbiddenPrefixes": [
        "com/example/dependency/"
      ]
    },
    {
      "path": "workspace/project/examplemod/run/logs/latest.log",
      "destination": "runtime/dedicated-server.log",
      "role": "dedicated-server-log"
    }
  ]
}
```

`baseDirectory` is resolved relative to the specification file. Every other configured source and output path is resolved from that base. Retained `destination` values must be safe relative paths inside the new pack.

`requireClean` defaults to `true`. Set it to `false` only when the approved workflow intentionally captures a dirty pre-checkpoint boundary. The manifest records the full porcelain status either way; disabling the gate does not describe the source as clean.

JUnit groups copy every matching report and aggregate suites, tests, failures, errors, and skipped counts. Files are copied only when explicitly listed. Every retained `.jar` is inspected automatically; `forbiddenPrefixes` records matching archive entries without interpreting whether a match is acceptable.

## Output

```text
final-abc123/
|-- manifest.json
|-- manifest.sha256
|-- summary.md
|-- artifacts/
|   `-- examplemod.jar
|-- test-results/
|   `-- unit/
|       `-- TEST-example.xml
`-- runtime/
    `-- dedicated-server.log
```

Capture writes to a uniquely named temporary sibling and moves it into place only after every declared input has been retained and the manifest has been written. Failure removes only that verified temporary sibling. The final directory is never overwritten.

The output directory must be outside the source mod repository. This prevents retained logs, reports, or third-party fixtures from entering the shipping project accidentally.

## Evidence Boundaries

An evidence pack establishes mechanical provenance:

- Exact source commit, tree, branch, cleanliness, and dirty-path list.
- Exact retained file identities and modification times.
- Aggregate JUnit values derived from retained XML.
- JAR entry, class, resource, and configured forbidden-prefix counts.
- Whether the retained pack still matches its original manifest.

It does not establish:

- That a test reaches the requirement it claims to test.
- That a log line came from the intended gameplay action.
- That the runtime used the expected external environment.
- That an owner-visible result passed.
- That an issue is complete.

Issue evidence should reference one pack and record only the claim-specific interpretation with its Stage 7 evidence label. When a correction changes source or outputs, create a new pack and mark the older checkpoint superseded; do not rewrite it or copy its volatile identities into several current-state documents.

## Tests

```bat
powershell.exe -NoProfile -ExecutionPolicy Bypass -File tools\evidence-pack\tests\run-tests.ps1
```

The tests cover clean capture, Git provenance, JUnit aggregation, JAR inventory, manifest integrity, retained-file verification, tamper detection, unexpected-file detection, immutable destinations, and the clean-worktree gate.
